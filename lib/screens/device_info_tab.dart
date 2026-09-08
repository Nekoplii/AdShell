import 'package:flutter/material.dart';
import '../core/adb_client.dart';
import '../theme/app_theme.dart';

class DeviceInfoTab extends StatefulWidget {
  final bool isConnected;

  const DeviceInfoTab({super.key, required this.isConnected});

  @override
  State<DeviceInfoTab> createState() => _DeviceInfoTabState();
}

class _DeviceInfoTabState extends State<DeviceInfoTab> {
  final AdbClient _adbClient = AdbClient();
  bool _isLoading = false;

  Map<String, String> _info = {
    'Model': 'Unknown',
    'Manufacturer': 'Unknown',
    'Android Version': 'Unknown',
    'SDK Level': 'Unknown',
    'CPU Architecture': 'Unknown',
    'Battery Level': 'Unknown',
    'Serial Number': 'Unknown',
    'Resolution': 'Unknown',
    'Density': 'Unknown',
  };

  @override
  void initState() {
    super.initState();
    if (widget.isConnected) {
      _fetchDeviceInfo();
    }
  }

  @override
  void didUpdateWidget(DeviceInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !oldWidget.isConnected) {
      _fetchDeviceInfo();
    } else if (!widget.isConnected && oldWidget.isConnected) {
      setState(() {
        _info.updateAll((key, value) => 'Unknown');
      });
    }
  }

  Future<void> _fetchDeviceInfo() async {
    setState(() => _isLoading = true);

    try {
      final model = await _adbClient.executeCommandWithResult('getprop ro.product.model');
      final manufacturer = await _adbClient.executeCommandWithResult('getprop ro.product.manufacturer');
      final version = await _adbClient.executeCommandWithResult('getprop ro.build.version.release');
      final sdk = await _adbClient.executeCommandWithResult('getprop ro.build.version.sdk');
      final cpu = await _adbClient.executeCommandWithResult('getprop ro.product.cpu.abi');
      final serial = await _adbClient.executeCommandWithResult('getprop ro.serialno');
      
      final wmSize = await _adbClient.executeCommandWithResult('wm size');
      final resolutionMatch = RegExp(r'Physical size: (.*)').firstMatch(wmSize);
      final resolution = resolutionMatch?.group(1) ?? 'Unknown';

      final wmDensity = await _adbClient.executeCommandWithResult('wm density');
      final densityMatch = RegExp(r'Physical density: (.*)').firstMatch(wmDensity);
      final density = densityMatch?.group(1) ?? 'Unknown';

      final batteryOut = await _adbClient.executeCommandWithResult('dumpsys battery');
      final batteryMatch = RegExp(r'level: (\d+)').firstMatch(batteryOut);
      final battery = batteryMatch != null ? '${batteryMatch.group(1)}%' : 'Unknown';

      if (mounted) {
        setState(() {
          _info = {
            'Model': model.trim(),
            'Manufacturer': manufacturer.trim(),
            'Android Version': version.trim(),
            'SDK Level': sdk.trim(),
            'CPU Architecture': cpu.trim(),
            'Battery Level': battery.trim(),
            'Serial Number': serial.trim(),
            'Resolution': resolution.trim(),
            'Density': density.trim(),
          };
        });
      }
    } catch (e) {
      // Ignore errors
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.isConnected) {
      return Center(
        child: Text(
          'Connect a device to view info.',
          style: TextStyle(color: isDark ? AppColors.neutral400 : AppColors.neutral500),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hardware & OS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchDeviceInfo,
              tooltip: 'Refresh Info',
            )
          ],
        ),
        const SizedBox(height: 8),
        ..._info.entries.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral900 : AppColors.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(e.key, style: TextStyle(color: isDark ? AppColors.neutral400 : AppColors.neutral500, fontSize: 13)),
              subtitle: Text(
                e.value.isEmpty ? 'N/A' : e.value,
                style: TextStyle(
                  color: isDark ? AppColors.neutral50 : AppColors.neutral900,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
