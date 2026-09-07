import 'package:flutter/services.dart';

class UsbDeviceInfo {
  final String deviceName;
  final int vendorId;
  final int productId;
  final String? manufacturerName;
  final String? productName;

  UsbDeviceInfo({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    this.manufacturerName,
    this.productName,
  });

  factory UsbDeviceInfo.fromMap(Map<Object?, Object?> map) {
    return UsbDeviceInfo(
      deviceName: map['deviceName'] as String,
      vendorId: map['vendorId'] as int,
      productId: map['productId'] as int,
      manufacturerName: map['manufacturerName'] as String?,
      productName: map['productName'] as String?,
    );
  }
}

class UsbManager {
  static const MethodChannel _channel = MethodChannel('com.adshell.usb/manager');

  static Future<List<UsbDeviceInfo>> getDevices() async {
    final List<dynamic>? result = await _channel.invokeMethod('getDevices');
    if (result == null) return [];
    
    return result.map((e) => UsbDeviceInfo.fromMap(e as Map<Object?, Object?>)).toList();
  }

  static Future<bool> requestPermission(String deviceName) async {
    final bool? granted = await _channel.invokeMethod('requestPermission', {'deviceName': deviceName});
    return granted ?? false;
  }
}
