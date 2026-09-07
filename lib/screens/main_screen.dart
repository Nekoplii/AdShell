import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/usb_manager.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<UsbDeviceInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await UsbManager.getDevices();
    setState(() {
      _devices = devices;
    });
  }

  Widget _buildShellTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _loadDevices,
          child: const Text('Scan USB Devices'),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return ListTile(
                leading: const Icon(Icons.usb),
                title: Text(device.productName ?? 'Unknown Device'),
                subtitle: Text(device.manufacturerName ?? 'Unknown Manufacturer'),
                trailing: IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () async {
                    final granted = await UsbManager.requestPermission(device.deviceName);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(granted ? 'Permission Granted' : 'Permission Denied')),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  late final List<Widget> _pages = [
    _buildShellTab(),
    const Center(child: Text('Saved Commands')),
    const Center(child: Text('App Manager')),
    const Center(child: Text('Device Info')),
  ];

  Widget _buildNavItem(BuildContext context, {required IconData icon, required int index}) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.15) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected 
                  ? AppColors.primary 
                  : (isDark ? AppColors.neutral400 : AppColors.neutral500),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackgroundColor = isDark ? AppColors.neutral900 : AppColors.neutral50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AdShell', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        height: 72 + MediaQuery.of(context).padding.bottom,
        color: navBackgroundColor,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, icon: _selectedIndex == 0 ? Icons.terminal : Icons.terminal_outlined, index: 0),
            _buildNavItem(context, icon: _selectedIndex == 1 ? Icons.bookmark : Icons.bookmark_border, index: 1),
            _buildNavItem(context, icon: _selectedIndex == 2 ? Icons.grid_view_rounded : Icons.grid_view, index: 2),
            _buildNavItem(context, icon: _selectedIndex == 3 ? Icons.info : Icons.info_outline, index: 3),
          ],
        ),
      ),
    );
  }
}
