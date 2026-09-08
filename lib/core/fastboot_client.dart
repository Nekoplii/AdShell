import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'usb_manager.dart';

class FastbootClient {
  static final FastbootClient _instance = FastbootClient._internal();
  factory FastbootClient() => _instance;
  FastbootClient._internal();

  bool _isRunning = false;
  
  final StreamController<String> _shellOutput = StreamController<String>.broadcast();
  Stream<String> get shellOutput => _shellOutput.stream;

  final StreamController<bool> _shellState = StreamController<bool>.broadcast();
  Stream<bool> get shellState => _shellState.stream;

  void connect() {
    _isRunning = true;
    _shellState.add(true);
    _shellOutput.add('Fastboot Connected! Target device is in bootloader mode.\r\n');
  }

  void disconnect() {
    _isRunning = false;
    _shellState.add(false);
    _shellOutput.add('Disconnected.\r\n');
    UsbManager.disconnect();
  }

  Future<void> executeCommand(String command) async {
    if (!_isRunning) return;

    _shellOutput.add('\r\n\$ fastboot $command\r\n');

    try {
      final payload = Uint8List.fromList(utf8.encode(command));
      await UsbManager.write(payload);

      // Fastboot response loop
      while (_isRunning) {
        final response = await UsbManager.read(length: 64, timeout: 5000);
        if (response.isEmpty) {
          _shellOutput.add('Timeout waiting for device response.\r\n');
          break;
        }

        final text = utf8.decode(response, allowMalformed: true);
        
        if (text.startsWith('INFO')) {
          _shellOutput.add('${text.substring(4)}\r\n');
        } else if (text.startsWith('OKAY')) {
          if (text.length > 4) {
            _shellOutput.add('${text.substring(4)}\r\n');
          }
          _shellOutput.add('Finished.\r\n');
          break;
        } else if (text.startsWith('FAIL')) {
          _shellOutput.add('FAILED (${text.substring(4)})\r\n');
          break;
        } else if (text.startsWith('DATA')) {
          // Complex data phase not yet implemented for file flashing
          _shellOutput.add('Data phase requested. Flashing not fully implemented yet.\r\n');
          break;
        } else {
          _shellOutput.add('$text\r\n');
        }
      }
    } catch (e) {
      _shellOutput.add('Error executing command: $e\r\n');
    }
  }
}
