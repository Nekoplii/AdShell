import 'package:flutter/services.dart';

class UsbDeviceInfo {
  final String deviceName;
  final int vendorId;
  final int productId;
  final String? manufacturerName;
  final String? productName;
  final int protocol; // 1 = ADB, 3 = Fastboot

  UsbDeviceInfo({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    this.manufacturerName,
    this.productName,
    required this.protocol,
  });

  factory UsbDeviceInfo.fromMap(Map<Object?, Object?> map) {
    return UsbDeviceInfo(
      deviceName: map['deviceName'] as String,
      vendorId: map['vendorId'] as int,
      productId: map['productId'] as int,
      manufacturerName: map['manufacturerName'] as String?,
      productName: map['productName'] as String?,
      protocol: map['protocol'] as int? ?? 1,
    );
  }
}

class UsbManager {
  static const MethodChannel _channel = MethodChannel(
    'com.adshell.usb/manager',
  );

  static Future<List<UsbDeviceInfo>> getDevices() async {
    final List<dynamic>? result = await _channel.invokeMethod('getDevices');
    if (result == null) return [];

    return result
        .map((e) => UsbDeviceInfo.fromMap(e as Map<Object?, Object?>))
        .toList();
  }

  static Future<bool> requestPermission(String deviceName) async {
    final bool? granted = await _channel.invokeMethod('requestPermission', {
      'deviceName': deviceName,
    });
    return granted ?? false;
  }

  static Future<int> connect(String deviceName) async {
    final int? protocol = await _channel.invokeMethod('connect', {
      'deviceName': deviceName,
    });
    return protocol ?? 0;
  }

  static Future<bool> disconnect() async {
    final bool? success = await _channel.invokeMethod('disconnect');
    return success ?? false;
  }

  static Future<int> write(Uint8List data, {int timeout = 1000}) async {
    final int? written = await _channel.invokeMethod('write', {
      'data': data,
      'timeout': timeout,
    });
    return written ?? -1;
  }

  static Future<Uint8List> read({int length = 4096, int timeout = 1000}) async {
    final Uint8List? data = await _channel.invokeMethod('read', {
      'length': length,
      'timeout': timeout,
    });
    return data ?? Uint8List(0);
  }

  static Future<Uint8List> signToken(Uint8List token) async {
    final Uint8List? signed = await _channel.invokeMethod('signToken', {
      'token': token,
    });
    return signed ?? Uint8List(0);
  }

  static Future<Uint8List> getPublicKey() async {
    final Uint8List? key = await _channel.invokeMethod('getPublicKey');
    return key ?? Uint8List(0);
  }
}
