import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'adb_protocol.dart';
import 'usb_manager.dart';

class AdbPacket {
  final int command;
  final int arg0;
  final int arg1;
  final Uint8List payload;

  AdbPacket(this.command, this.arg0, this.arg1, this.payload);
}

class AdbClient {
  static final AdbClient _instance = AdbClient._internal();
  factory AdbClient() => _instance;
  AdbClient._internal();

  // ADB AUTH types
  static const int ADB_AUTH_TOKEN = 1;
  static const int ADB_AUTH_SIGNATURE = 2;
  static const int ADB_AUTH_RSAPUBLICKEY = 3;

  bool _isRunning = false;
  String? _connectedDevice;
  bool _authSigned = false;
  
  int _nextLocalId = 1;
  final Map<int, String> _activeStreams = {};

  final StreamController<String> _shellOutput = StreamController<String>.broadcast();
  Stream<String> get shellOutput => _shellOutput.stream;

  final StreamController<bool> _shellState = StreamController<bool>.broadcast();
  Stream<bool> get shellState => _shellState.stream;

  Future<bool> connect(String deviceName) async {
    final protocol = await UsbManager.connect(deviceName);
    if (protocol != 1) { // 1 = ADB
      _shellOutput.add('Error: Failed to claim ADB interface.\n');
      return false;
    }

    _connectedDevice = deviceName;
    _isRunning = true;
    _authSigned = false;
    _startReadLoop();

    _shellOutput.add('USB Interface claimed. Sending CNXN...');

    final payload = AdbProtocol.generateConnectPayload();
    final packet = AdbProtocol.createMessage(
      AdbProtocol.A_CNXN,
      AdbProtocol.ADB_VERSION,
      AdbProtocol.MAX_PAYLOAD,
      payload,
    );

    await UsbManager.write(packet);
    return true;
  }

  void disconnect() {
    _isRunning = false;
    UsbManager.disconnect();
    _connectedDevice = null;
    _authSigned = false;
    _activeStreams.clear();
    _shellState.add(false);
    _shellOutput.add('Disconnected.\n');
  }

  void executeCommand(String command) {
    if (_connectedDevice == null) return;
    
    _shellOutput.add('\n\$ $command\n');

    final localId = _nextLocalId++;
    _activeStreams[localId] = command;

    final openPayload = Uint8List.fromList(utf8.encode('shell:$command\x00'));
    final openPacket = AdbProtocol.createMessage(
      AdbProtocol.A_OPEN,
      localId,
      0,
      openPayload,
    );
    
    UsbManager.write(openPacket);
  }

  void _startReadLoop() async {
    while (_isRunning) {
      try {
        final header = await UsbManager.read(length: 24, timeout: 500);
        if (header.isEmpty) continue;

        if (header.length < 24) continue;

        final byteData = ByteData.sublistView(header);
        final command = byteData.getUint32(0, Endian.little);
        final arg0 = byteData.getUint32(4, Endian.little);
        final arg1 = byteData.getUint32(8, Endian.little);
        final payloadLength = byteData.getUint32(12, Endian.little);

        Uint8List payload = Uint8List(0);
        if (payloadLength > 0) {
          payload = await UsbManager.read(length: payloadLength, timeout: 2000);
        }

        await _handlePacket(AdbPacket(command, arg0, arg1, payload));
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _handlePacket(AdbPacket packet) async {
    if (packet.command == AdbProtocol.A_AUTH) {
      if (packet.arg0 == ADB_AUTH_TOKEN) {
        if (!_authSigned) {
          // Step 1: Sign the token with our private key
          _shellOutput.add('AUTH token received. Signing...');
          _authSigned = true;

          final signed = await UsbManager.signToken(packet.payload);
          final signPacket = AdbProtocol.createMessage(
            AdbProtocol.A_AUTH,
            ADB_AUTH_SIGNATURE,
            0,
            signed,
          );
          await UsbManager.write(signPacket);
          _shellOutput.add('Signed AUTH sent.');
        } else {
          // Step 2: Signature rejected, send public key
          // This triggers "Allow USB debugging?" dialog on target
          _shellOutput.add('Sending public key to target...');

          final pubKey = await UsbManager.getPublicKey();
          final pubKeyPacket = AdbProtocol.createMessage(
            AdbProtocol.A_AUTH,
            ADB_AUTH_RSAPUBLICKEY,
            0,
            pubKey,
          );
          await UsbManager.write(pubKeyPacket);
          _shellOutput.add('Public key sent. Check target device for USB debugging prompt.');
        }
      }
    } else if (packet.command == AdbProtocol.A_CNXN) {
      final info = utf8.decode(packet.payload, allowMalformed: true);
      _shellOutput.add('ADB Connected! Target: $info\n');
      _shellState.add(true);
    } else if (packet.command == AdbProtocol.A_OKAY) {
      // Stream opened successfully
    } else if (packet.command == AdbProtocol.A_WRTE) {
      final content = utf8.decode(packet.payload, allowMalformed: true);
      _shellOutput.add(content);

      // Acknowledge the write back to the remote stream
      final okay = AdbProtocol.createMessage(
        AdbProtocol.A_OKAY,
        packet.arg1,
        packet.arg0,
        Uint8List(0),
      );
      await UsbManager.write(okay);
    } else if (packet.command == AdbProtocol.A_CLSE) {
      _activeStreams.remove(packet.arg1);
      final okay = AdbProtocol.createMessage(
        AdbProtocol.A_OKAY,
        packet.arg1,
        packet.arg0,
        Uint8List(0),
      );
      await UsbManager.write(okay);
    } else {
      _shellOutput.add('Unknown packet: 0x${packet.command.toRadixString(16)}\n');
    }
  }
}
