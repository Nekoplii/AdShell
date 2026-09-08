import 'package:flutter/material.dart';

import '../core/adb_client.dart';
import '../core/fastboot_client.dart';
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
  final FastbootClient _fastbootClient = FastbootClient();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  
  bool _isShellReady = false;
  int _activeProtocol = 0; // 0=None, 1=ADB, 3=Fastboot
  final List<String> _terminalLines = [];
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();

    _adbClient.shellOutput.listen((data) {
      if (mounted) {
        setState(() {
          final cleanData = data.replaceAll('\r', '');
          final parts = cleanData.split('\n');
          if (_terminalLines.isEmpty) {
            _terminalLines.addAll(parts);
          } else {
            _terminalLines[_terminalLines.length - 1] += parts.first;
            if (parts.length > 1) {
              _terminalLines.addAll(parts.sublist(1));
            }
          }
          if (_terminalLines.length > 1000) {
            _terminalLines.removeRange(0, _terminalLines.length - 1000);
          }
        });
        _scrollToBottom();
      }
    });

    _adbClient.shellState.listen((isReady) {
      if (mounted) {
        setState(() {
          _isShellReady = isReady;
          if (!isReady) _activeProtocol = 0;
        });
        if (isReady) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _inputFocusNode.requestFocus();
          });
        }
      }
    });

    _fastbootClient.shellOutput.listen((data) {
      if (mounted) {
        setState(() {
          final cleanData = data.replaceAll('\r', '');
          final parts = cleanData.split('\n');
          if (_terminalLines.isEmpty) {
            _terminalLines.addAll(parts);
          } else {
            _terminalLines[_terminalLines.length - 1] += parts.first;
            if (parts.length > 1) {
              _terminalLines.addAll(parts.sublist(1));
            }
          }
          if (_terminalLines.length > 1000) {
            _terminalLines.removeRange(0, _terminalLines.length - 1000);
          }
        });
        _scrollToBottom();
      }
    });

    _fastbootClient.shellState.listen((isReady) {
      if (mounted) {
        setState(() {
          _isShellReady = isReady;
          if (!isReady) _activeProtocol = 0;
        });
        if (isReady) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _inputFocusNode.requestFocus();
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDevices();
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
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
        final protocol = await UsbManager.connect(device.deviceName);
        setState(() {
          _activeProtocol = protocol;
        });

        if (protocol == 1) {
          _terminalLines.add('Device is in ADB Mode.');
          await _adbClient.connect(device.deviceName);
        } else if (protocol == 3) {
          _terminalLines.add('Device is in Fastboot Mode.');
          _fastbootClient.connect();
        } else {
          setState(() {
            _terminalLines.add('Failed to establish ADB or Fastboot connection.');
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _terminalLines.add('Connection error: $e');
      });
    }
    _scrollToBottom();
  }

  void _submitCommand() {
    String cmd = _commandController.text.trim();
    if (cmd.isNotEmpty && _isShellReady) {
      _commandHistory.add(cmd);
      _historyIndex = _commandHistory.length;

      if (cmd == 'clear') {
        setState(() {
          _terminalLines.clear();
          _terminalLines.add('');
        });
        _commandController.clear();
        _scrollToBottom();
        return;
      }

      if (_activeProtocol == 3) {
        // Fastboot mode
        if (cmd.startsWith('fastboot ')) {
          cmd = cmd.substring(9);
        } else if (cmd == 'fastboot') {
          setState(() {
            _terminalLines.addAll([
              '',
              '[AdShell] You are connected in Fastboot mode.',
              '[AdShell] Type commands directly (e.g. getvar all, reboot).',
              ''
            ]);
          });
          _commandController.clear();
          _scrollToBottom();
          return;
        } else if (cmd.startsWith('adb')) {
          setState(() {
            _terminalLines.add('[AdShell] Error: Cannot run ADB commands while in Fastboot mode.');
          });
          _commandController.clear();
          _scrollToBottom();
          return;
        }

        _fastbootClient.executeCommand(cmd);

      } else if (_activeProtocol == 1) {
        // ADB mode
        if (cmd == 'fastboot' || cmd.startsWith('fastboot ')) {
          setState(() {
            _terminalLines.addAll([
              '',
              '[AdShell] Device is currently in ADB mode.',
              '[AdShell] Reboot to bootloader to use Fastboot commands.',
              ''
            ]);
          });
          _commandController.clear();
          _scrollToBottom();
          return;
        }

        if (cmd == 'adb' || cmd == 'adb help') {
          setState(() {
            _terminalLines.addAll([
              '',
              '[AdShell] Commands are executed directly on the target device.',
              '[AdShell] Type commands directly (e.g. ls, pm list packages, reboot).',
              ''
            ]);
          });
          _commandController.clear();
          _scrollToBottom();
          return;
        }

        if (cmd.startsWith('adb shell ')) {
          cmd = cmd.substring(10);
        } else if (cmd.startsWith('adb ')) {
          cmd = cmd.substring(4);
        }

        _adbClient.executeCommand(cmd);
      }

      _commandController.clear();
      _inputFocusNode.requestFocus();
    }
  }

  void _historyUp() {
    if (_commandHistory.isNotEmpty && _historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _commandController.text = _commandHistory[_historyIndex];
      });
    }
  }

  void _historyDown() {
    if (_commandHistory.isNotEmpty && _historyIndex < _commandHistory.length - 1) {
      setState(() {
        _historyIndex++;
        _commandController.text = _commandHistory[_historyIndex];
      });
    } else {
      setState(() {
        _historyIndex = _commandHistory.length;
        _commandController.text = '';
      });
    }
  }

  Widget _buildDeviceSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
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
                            const Icon(Icons.usb_rounded, size: 18, color: AppColors.primary),
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
                      setState(() => _selectedDevice = device);
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
    );
  }

  Widget _buildShellTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.neutral800 : AppColors.neutral200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                  child: SelectableText(
                    _terminalLines[index],
                    style: const TextStyle(
                      color: Color(0xFF10B981),
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
        if (_isShellReady)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    focusNode: _inputFocusNode,
                    enabled: _isShellReady,
                    onSubmitted: (_) => _submitCommand(),
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '> Type command (e.g. ls, dumpsys)',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                        fontFamily: 'sans-serif',
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.neutral900 : AppColors.neutral100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _isShellReady ? _historyUp : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Icon(Icons.keyboard_arrow_up, size: 20),
                      ),
                    ),
                    InkWell(
                      onTap: _isShellReady ? _historyDown : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Icon(Icons.keyboard_arrow_down, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: _isShellReady ? AppColors.primary : AppColors.neutral400.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _isShellReady ? _submitCommand : null,
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
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

  Widget _buildNavItem(BuildContext context, {required IconData icon, required int index}) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.15)
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

  Widget _buildBottomNav(BuildContext context, bool isKeyboardOpen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackgroundColor = isDark ? AppColors.neutral900 : AppColors.neutral50;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final fullHeight = 72.0 + bottomPadding;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      height: isKeyboardOpen ? 0 : fullHeight,
      child: ClipRect(
        child: OverflowBox(
          minHeight: fullHeight,
          maxHeight: fullHeight,
          alignment: Alignment.topCenter,
          child: Container(
            color: navBackgroundColor,
            padding: EdgeInsets.only(bottom: bottomPadding),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 50;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('AdShell', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildDeviceSelector(),
          Expanded(child: _buildCurrentPage()),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, isKeyboardOpen),
    );
  }
}
