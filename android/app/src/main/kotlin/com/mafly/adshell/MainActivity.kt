package com.mafly.adshell

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.adshell.usb/manager"
    private val ACTION_USB_PERMISSION = "com.mafly.adshell.USB_PERMISSION"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

            when (call.method) {
                "getDevices" -> {
                    val devices = usbManager.deviceList.values.map { 
                        mapOf(
                            "deviceName" to it.deviceName,
                            "vendorId" to it.vendorId,
                            "productId" to it.productId,
                            "manufacturerName" to it.manufacturerName,
                            "productName" to it.productName
                        )
                    }
                    result.success(devices)
                }
                "requestPermission" -> {
                    val deviceName = call.argument<String>("deviceName")
                    val device = usbManager.deviceList[deviceName]
                    if (device == null) {
                        result.error("DEVICE_NOT_FOUND", "Device not found", null)
                        return@setMethodCallHandler
                    }

                    if (usbManager.hasPermission(device)) {
                        result.success(true)
                    } else {
                        val receiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context, intent: Intent) {
                                if (ACTION_USB_PERMISSION == intent.action) {
                                    context.unregisterReceiver(this)
                                    synchronized(this) {
                                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                                        result.success(granted)
                                    }
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
                else -> result.notImplemented()
            }
        }
    }
}
