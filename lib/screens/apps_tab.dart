import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/adb_client.dart';
import '../core/fastboot_client.dart';

class AppsTab extends StatelessWidget {
  final bool isAdbConnected;
  final bool isFastbootConnected;
  final AdbClient adbClient;
  final FastbootClient fastbootClient;

  const AppsTab({
    super.key,
    required this.isAdbConnected,
    required this.isFastbootConnected,
    required this.adbClient,
    required this.fastbootClient,
  });

  void _showPowerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PowerMenuSheet(
        isAdbConnected: isAdbConnected,
        isFastbootConnected: isFastbootConnected,
        adbClient: adbClient,
        fastbootClient: fastbootClient,
      ),
    );
  }

  Widget _buildUtilityCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? AppColors.neutral900 : AppColors.neutral100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.neutral800 : AppColors.neutral200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.neutral50 : AppColors.neutral900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16.0),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildUtilityCard(
          context,
          title: 'Power Options',
          icon: Icons.power_settings_new_rounded,
          color: Colors.redAccent,
          onTap: () => _showPowerMenu(context),
        ),
        _buildUtilityCard(
          context,
          title: 'App Manager',
          icon: Icons.android_rounded,
          color: Colors.greenAccent,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('App Manager coming soon!')),
            );
          },
        ),
        _buildUtilityCard(
          context,
          title: 'File Explorer',
          icon: Icons.folder_rounded,
          color: Colors.blueAccent,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File Explorer coming soon!')),
            );
          },
        ),
        _buildUtilityCard(
          context,
          title: 'Logcat',
          icon: Icons.receipt_long_rounded,
          color: Colors.orangeAccent,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logcat viewer coming soon!')),
            );
          },
        ),
      ],
    );
  }
}

class _PowerMenuSheet extends StatelessWidget {
  final bool isAdbConnected;
  final bool isFastbootConnected;
  final AdbClient adbClient;
  final FastbootClient fastbootClient;

  const _PowerMenuSheet({
    required this.isAdbConnected,
    required this.isFastbootConnected,
    required this.adbClient,
    required this.fastbootClient,
  });

  void _executeReboot(BuildContext context, String mode) {
    if (isAdbConnected) {
      if (mode == 'system') {
        adbClient.executeCommand('reboot');
      } else if (mode == 'poweroff') {
        adbClient.executeCommand('reboot -p');
      } else if (mode == 'soft') {
        adbClient.executeCommand('setprop ctl.restart zygote');
      } else {
        adbClient.executeCommand('reboot $mode');
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Executing power command: $mode...')),
      );
    } else if (isFastbootConnected) {
      if (mode == 'system') {
        fastbootClient.executeCommand('reboot');
      } else if (mode == 'bootloader') {
        fastbootClient.executeCommand('reboot bootloader');
      } else if (mode == 'recovery') {
        fastbootClient.executeCommand('reboot recovery');
      } else if (mode == 'fastboot') {
        fastbootClient.executeCommand('reboot fastboot');
      } else if (mode == 'edl') {
        fastbootClient.executeCommand('oem edl');
      } else if (mode == 'poweroff') {
        fastbootClient.executeCommand('powerdown'); // Fastboot command for off
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Executing fastboot power command: $mode...')),
      );
    }
  }

  Widget _buildPowerRow(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String mode,
    required bool isConnected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isConnected ? color.withValues(alpha: 0.1) : AppColors.neutral500.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isConnected ? color : AppColors.neutral500),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isConnected ? (isDark ? Colors.white : Colors.black) : AppColors.neutral500,
        ),
      ),
      enabled: isConnected,
      onTap: isConnected ? () => _executeReboot(context, mode) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = isAdbConnected || isFastbootConnected;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral950 : AppColors.neutral50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral700 : AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Power Options',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!isConnected)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connect a device to use power options.',
                      style: TextStyle(color: isDark ? Colors.redAccent[100] : Colors.red[900]),
                    ),
                  ),
                ],
              ),
            ),
          _buildPowerRow(context, title: 'Reboot System', icon: Icons.power_settings_new_rounded, color: Colors.blueAccent, mode: 'system', isConnected: isConnected),
          _buildPowerRow(context, title: 'Soft Reboot', icon: Icons.refresh_rounded, color: Colors.cyan, mode: 'soft', isConnected: isAdbConnected), // Soft reboot only works in ADB
          _buildPowerRow(context, title: 'Reboot Recovery', icon: Icons.health_and_safety_rounded, color: Colors.orangeAccent, mode: 'recovery', isConnected: isConnected),
          _buildPowerRow(context, title: 'Reboot Bootloader', icon: Icons.android_rounded, color: Colors.greenAccent, mode: 'bootloader', isConnected: isConnected),
          _buildPowerRow(context, title: 'Reboot Fastbootd', icon: Icons.memory_rounded, color: Colors.purpleAccent, mode: 'fastboot', isConnected: isConnected),
          _buildPowerRow(context, title: 'Reboot EDL', icon: Icons.cable_rounded, color: Colors.redAccent, mode: 'edl', isConnected: isConnected),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(),
          ),
          _buildPowerRow(context, title: 'Power Off', icon: Icons.power_off_rounded, color: Colors.grey, mode: 'poweroff', isConnected: isConnected),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
