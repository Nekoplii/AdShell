import 'package:flutter/material.dart';

import '../core/adb_client.dart';
import '../core/usb_manager.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<UsbDeviceInfo> _devices = [];
  UsbDeviceInfo? _selectedDevice;
  final AdbClient _adbClient = AdbClient();
  final ScrollController _scrollController = ScrollController();
  final List<String> _terminalLines = [];

  @override
  void initState() {
    super.initState();
    _adbClient.shellOutput.listen((data) {
      if (mounted) {
        setState(() {
          _terminalLines.add(data);
        });
        _scrollToBottom();
      }
    });

    // Auto-scan on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDevices();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadDevices() async {
    setState(() {
      _terminalLines.add('Scanning for USB devices...');
    });
    _scrollToBottom();

    try {
      final devices = await UsbManager.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _selectedDevice = null;
        if (devices.isEmpty) {
          _terminalLines.add('No USB devices found.');
          _terminalLines.add('Make sure OTG is enabled and cable is connected.');
        } else {
          _terminalLines.add('Found ${devices.length} USB device(s):');
          for (var d in devices) {
            _terminalLines.add('  - ${d.productName ?? "Unknown"} (VID:${d.vendorId} PID:${d.productId})');
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _terminalLines.add('Error scanning: $e');
      });
    }
    _scrollToBottom();
  }

  Future<void> _connectDevice(UsbDeviceInfo device) async {
    setState(() {
      _terminalLines.add('');
      _terminalLines.add('--- Connecting to ${device.productName ?? "Unknown"} ---');
      _terminalLines.add('Requesting USB permission...');
    });
    _scrollToBottom();

    try {
      final granted = await UsbManager.requestPermission(device.deviceName);
      if (!mounted) return;

      setState(() {
        _terminalLines.add(granted ? 'Permission GRANTED.' : 'Permission DENIED.');
      });

      if (granted) {
        await _adbClient.connect(device.deviceName);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _terminalLines.add('Connection error: $e');
      });
    }
    _scrollToBottom();
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildShellTab();
      case 1:
        return const Center(child: Text('Saved Commands'));
      case 2:
        return const Center(child: Text('App Manager'));
      case 3:
        return const Center(child: Text('Device Info'));
      default:
        return const Center(child: Text('Unknown'));
    }
  }

  Widget _buildShellTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral900 : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UsbDeviceInfo>(
                      isExpanded: true,
                      value: _selectedDevice,
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                        ),
                      ),
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _devices.isEmpty ? 'No USB Devices Found' : 'Select Target Device',
                          style: TextStyle(
                            color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                          ),
                        ),
                      ),
                      items: _devices.map((device) {
                        return DropdownMenuItem<UsbDeviceInfo>(
                          value: device,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.usb_rounded, 
                                  size: 18, 
                                  color: AppColors.primary
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    device.productName ?? 'Device ${device.vendorId}:${device.productId}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.neutral50 : AppColors.neutral900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (device) {
                        if (device != null) {
                          setState(() {
                            _selectedDevice = device;
                          });
                          _connectDevice(device);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _loadDevices,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.primary,
                  tooltip: 'Rescan USB',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121A), // Pure terminal dark
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.neutral800 : AppColors.neutral200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _terminalLines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    _terminalLines[index],
                    style: const TextStyle(
                      color: Color(0xFF10B981), // Emerald green
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

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
      body: _buildCurrentPage(),
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
