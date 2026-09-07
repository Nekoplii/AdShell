import 'dart:convert';
import 'dart:typed_data';

class AdbProtocol {
  // ADB Command Constants
  static const int A_SYNC = 0x434e5953;
  static const int A_CNXN = 0x4e584e43;
  static const int A_OPEN = 0x4e45504f;
  static const int A_OKAY = 0x59414b4f;
  static const int A_CLSE = 0x45534c43;
  static const int A_WRTE = 0x45545257;
  static const int A_AUTH = 0x48545541;

  static const int ADB_VERSION = 0x01000000; // 1.0.0
  static const int MAX_PAYLOAD = 4096;

  static Uint8List createMessage(
    int command,
    int arg0,
    int arg1,
    Uint8List payload,
  ) {
    final dataLength = payload.length;
    var dataCrc32 = 0;

    // Simple sum CRC for ADB
    for (int i = 0; i < dataLength; i++) {
      dataCrc32 = (dataCrc32 + payload[i]) & 0xFFFFFFFF;
    }

    final magic = (command ^ 0xFFFFFFFF) & 0xFFFFFFFF;

    final header = ByteData(24);
    header.setUint32(0, command, Endian.little);
    header.setUint32(4, arg0, Endian.little);
    header.setUint32(8, arg1, Endian.little);
    header.setUint32(12, dataLength, Endian.little);
    header.setUint32(16, dataCrc32, Endian.little);
    header.setUint32(20, magic, Endian.little);

    final builder = BytesBuilder();
    builder.add(header.buffer.asUint8List());
    builder.add(payload);

    return builder.toBytes();
  }

  static Uint8List generateConnectPayload() {
    final identity = "host::AdShell\x00";
    return Uint8List.fromList(utf8.encode(identity));
  }
}
