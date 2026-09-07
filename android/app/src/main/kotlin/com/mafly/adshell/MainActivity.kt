package com.mafly.adshell

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.PKCS8EncodedKeySpec
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.adshell.usb/manager"
    private val ACTION_USB_PERMISSION = "com.mafly.adshell.USB_PERMISSION"

    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var endpointIn: UsbEndpoint? = null
    private var endpointOut: UsbEndpoint? = null

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun getOrCreateKeyPair(): Pair<ByteArray, ByteArray> {
        val privFile = File(filesDir, "adb_key")
        val pubFile = File(filesDir, "adb_key.pub")

        if (privFile.exists() && pubFile.exists()) {
            return Pair(privFile.readBytes(), pubFile.readBytes())
        }

        Log.d("AdShell", "Generating new RSA 2048 key pair...")
        val keyGen = KeyPairGenerator.getInstance("RSA")
        keyGen.initialize(2048)
        val keyPair = keyGen.generateKeyPair()

        val privBytes = keyPair.private.encoded  // PKCS#8
        val pubBytes = keyPair.public.encoded     // X.509

        privFile.writeBytes(privBytes)

        // ADB public key format: base64(DER public key) + " adshell@AdShell\n"
        val pubB64 = Base64.encodeToString(pubBytes, Base64.NO_WRAP)
        val adbPubKey = "$pubB64 adshell@AdShell\n"
        pubFile.writeBytes(adbPubKey.toByteArray())

        Log.d("AdShell", "RSA key pair generated and saved.")
        return Pair(privBytes, adbPubKey.toByteArray())
    }

    private fun signToken(token: ByteArray): ByteArray {
        val privFile = File(filesDir, "adb_key")
        val privBytes = privFile.readBytes()
        val keySpec = PKCS8EncodedKeySpec(privBytes)
        val keyFactory = KeyFactory.getInstance("RSA")
        val privateKey = keyFactory.generatePrivate(keySpec)

        val sig = Signature.getInstance("SHA1withRSA")
        sig.initSign(privateKey)
        sig.update(token)
        return sig.sign()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure keys exist on startup
        executor.execute {
            try { getOrCreateKeyPair() } catch (e: Exception) {
                Log.e("AdShell", "Key generation failed: ${e.message}")
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

            when (call.method) {
                "getDevices" -> {
                    executor.execute {
                        try {
                            val deviceList = usbManager.deviceList
                            Log.d("AdShell", "USB device count: ${deviceList.size}")
                            val devices = deviceList.values.map {
                                mapOf(
                                    "deviceName" to it.deviceName,
                                    "vendorId" to it.vendorId,
                                    "productId" to it.productId,
                                    "manufacturerName" to (it.manufacturerName ?: "Unknown"),
                                    "productName" to (it.productName ?: "Device ${it.deviceId}")
                                )
                            }
                            mainHandler.post { result.success(devices) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SCAN_ERROR", e.message ?: "Unknown error", null) }
                        }
                    }
                }
                "requestPermission" -> {
                    val deviceName = call.argument<String>("deviceName")
                    val device = usbManager.deviceList[deviceName]
                    if (device == null) {
                        result.error("DEVICE_NOT_FOUND", "Device '$deviceName' not found", null)
                        return@setMethodCallHandler
                    }

                    if (usbManager.hasPermission(device)) {
                        result.success(true)
                    } else {
                        val receiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context, intent: Intent) {
                                if (ACTION_USB_PERMISSION == intent.action) {
                                    context.unregisterReceiver(this)
                                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                                    result.success(granted)
                                }
                            }
                        }
                        val filter = IntentFilter(ACTION_USB_PERMISSION)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                        } else {
                            registerReceiver(receiver, filter)
                        }
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                        val permissionIntent = PendingIntent.getBroadcast(this, 0, Intent(ACTION_USB_PERMISSION), flags)
                        usbManager.requestPermission(device, permissionIntent)
                    }
                }
                "connect" -> {
                    executor.execute {
                        try {
                            val deviceName = call.argument<String>("deviceName")
                            val device = usbManager.deviceList[deviceName]
                            if (device == null || !usbManager.hasPermission(device)) {
                                mainHandler.post { result.error("NO_ACCESS", "Device not found or no permission", null) }
                                return@execute
                            }

                            var targetInterface: UsbInterface? = null
                            var epIn: UsbEndpoint? = null
                            var epOut: UsbEndpoint? = null

                            for (i in 0 until device.interfaceCount) {
                                val intf = device.getInterface(i)
                                if (intf.interfaceClass == 255 && intf.interfaceSubclass == 66 && intf.interfaceProtocol == 1) {
                                    targetInterface = intf
                                    for (j in 0 until intf.endpointCount) {
                                        val ep = intf.getEndpoint(j)
                                        if (ep.direction == UsbConstants.USB_DIR_IN) epIn = ep
                                        if (ep.direction == UsbConstants.USB_DIR_OUT) epOut = ep
                                    }
                                    break
                                }
                            }

                            if (targetInterface != null && epIn != null && epOut != null) {
                                val conn = usbManager.openDevice(device)
                                if (conn?.claimInterface(targetInterface, true) == true) {
                                    usbConnection = conn
                                    usbInterface = targetInterface
                                    endpointIn = epIn
                                    endpointOut = epOut
                                    mainHandler.post { result.success(true) }
                                } else {
                                    conn?.close()
                                    mainHandler.post { result.error("CLAIM_FAILED", "Failed to claim ADB interface", null) }
                                }
                            } else {
                                val interfaceInfo = (0 until device.interfaceCount).joinToString(", ") { i ->
                                    val intf = device.getInterface(i)
                                    "IF${i}[cls=${intf.interfaceClass},sub=${intf.interfaceSubclass},prot=${intf.interfaceProtocol}]"
                                }
                                mainHandler.post { result.error("NO_ADB", "ADB interface not found. Interfaces: $interfaceInfo", null) }
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("CONNECT_ERROR", e.message ?: "Unknown error", null) }
                        }
                    }
                }
                "disconnect" -> {
                    executor.execute {
                        usbInterface?.let { usbConnection?.releaseInterface(it) }
                        usbConnection?.close()
                        usbConnection = null
                        usbInterface = null
                        endpointIn = null
                        endpointOut = null
                        mainHandler.post { result.success(true) }
                    }
                }
                "signToken" -> {
                    val token = call.argument<ByteArray>("token")
                    if (token == null) {
                        result.error("INVALID_ARG", "Token is null", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val signed = signToken(token)
                            mainHandler.post { result.success(signed) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("SIGN_ERROR", e.message ?: "Unknown error", null) }
                        }
                    }
                }
                "getPublicKey" -> {
                    executor.execute {
                        try {
                            val (_, pubKey) = getOrCreateKeyPair()
                            mainHandler.post { result.success(pubKey) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("KEY_ERROR", e.message ?: "Unknown error", null) }
                        }
                    }
                }
                "write" -> {
                    val data = call.argument<ByteArray>("data") ?: return@setMethodCallHandler
                    val timeout = call.argument<Int>("timeout") ?: 1000
                    executor.execute {
                        if (usbConnection != null && endpointOut != null) {
                            val written = usbConnection!!.bulkTransfer(endpointOut, data, data.size, timeout)
                            mainHandler.post { result.success(written) }
                        } else {
                            mainHandler.post { result.error("DISCONNECTED", "Device not connected", null) }
                        }
                    }
                }
                "read" -> {
                    val length = call.argument<Int>("length") ?: 4096
                    val timeout = call.argument<Int>("timeout") ?: 1000
                    executor.execute {
                        if (usbConnection != null && endpointIn != null) {
                            val buffer = ByteArray(length)
                            val read = usbConnection!!.bulkTransfer(endpointIn, buffer, length, timeout)
                            mainHandler.post {
                                if (read >= 0) {
                                    result.success(buffer.copyOfRange(0, read))
                                } else {
                                    result.success(ByteArray(0))
                                }
                            }
                        } else {
                            mainHandler.post { result.error("DISCONNECTED", "Device not connected", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
