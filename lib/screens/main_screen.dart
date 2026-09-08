import 'package:flutter/material.dart';

import '../core/adb_client.dart';
import '../core/usb_manager.dart';
import '../core/terminal_processor.dart';
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
  final TextEditingController _commandController = TextEditingController();
  final TerminalProcessor _terminal = TerminalProcessor();
  bool _isShellReady = false;

  // Command History
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  // Termux-style Modifiers
  bool _isCtrlActive = false;
  bool _isAltActive = false;

  @override
  void initState() {
    super.initState();
    _adbClient.shellOutput.listen((data) {
      if (mounted) {
        setState(() {
          if (data.contains('Interactive shell ready')) {
            _isShellReady = true;
          } else if (data.contains('Disconnected') || data.contains('closed by remote')) {
            _isShellReady = false;
          }
          _terminal.processOutput(data);
        });
        _scrollToBottom();
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
    _terminal.processOutput('Scanning for USB devices...\n');
    setState(() {});
    _scrollToBottom();

    try {
      final devices = await UsbManager.getDevices();
      if (!mounted) return;
      _devices = devices;
      _selectedDevice = null;
      if (devices.isEmpty) {
        _terminal.processOutput('No USB devices found.\n');
        _terminal.processOutput('Make sure OTG is enabled and cable is connected.\n');
      } else {
        _terminal.processOutput('Found ${devices.length} USB device(s):\n');
        for (var d in devices) {
          _terminal.processOutput('  - ${d.productName ?? "Unknown"} (VID:${d.vendorId} PID:${d.productId})\n');
        }
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _terminal.processOutput('Error scanning: $e\n');
      setState(() {});
    }
    _scrollToBottom();
  }

  Future<void> _connectDevice(UsbDeviceInfo device) async {
    _terminal.processOutput('\n--- Connecting to ${device.productName ?? "Unknown"} ---\n');
    _terminal.processOutput('Requesting USB permission...\n');
    setState(() {});
    _scrollToBottom();

    try {
      final granted = await UsbManager.requestPermission(device.deviceName);
      if (!mounted) return;

      _terminal.processOutput(granted ? 'Permission GRANTED.\n' : 'Permission DENIED.\n');
      setState(() {});

      if (granted) {
        await _adbClient.connect(device.deviceName);
      }
    } catch (e) {
      if (!mounted) return;
      _terminal.processOutput('Connection error: $e\n');
      setState(() {});
    }
    _scrollToBottom();
  }

  void _submitCommand() {
    String cmd = _commandController.text.trim();
    if (cmd.isNotEmpty && _isShellReady) {
      _commandHistory.add(cmd);
      _historyIndex = _commandHistory.length;

      if (cmd == 'fastboot' || cmd.startsWith('fastboot ')) {
        _terminal.processOutput('\n[AdShell] Fastboot protocol over USB is not yet implemented.\n');
        _terminal.processOutput('[AdShell] Target must be in bootloader mode. Coming soon!\n');
        setState(() {});
        _commandController.clear();
        _scrollToBottom();
        return;
      }

      if (cmd == 'adb' || cmd == 'adb help') {
        _terminal.processOutput('\n[AdShell] You are already inside an ADB shell session.\n');
        _terminal.processOutput('[AdShell] Type commands directly (e.g. ls, pm list packages, reboot).\n');
        _terminal.processOutput('[AdShell] Use "adb shell <cmd>" prefix if you prefer.\n');
        setState(() {});
        _commandController.clear();
        _scrollToBottom();
        return;
      }

      if (cmd.startsWith('adb shell ')) {
        cmd = cmd.substring(10);
      } else if (cmd.startsWith('adb ')) {
        cmd = cmd.substring(4);
      }

      if (cmd == 'clear') {
        _terminal.clear();
        setState(() {});
        _commandController.clear();
        _scrollToBottom();
        return;
      }

      _adbClient.writeShellCommand(cmd);
      _commandController.clear();
    }
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) return;

    if (_isCtrlActive || _isAltActive) {
      final char = text.substring(text.length - 1);
      
      _commandController.text = text.substring(0, text.length - 1);
      if (_commandController.text.isNotEmpty) {
        _commandController.selection = TextSelection.collapsed(offset: _commandController.text.length);
      }

      if (_isCtrlActive) {
        final code = char.toLowerCase().codeUnitAt(0);
        if (code >= 97 && code <= 122) { // a-z
          final ctrlChar = String.fromCharCode(code - 96);
          _adbClient.writeShellCommand(ctrlChar, addNewline: false);
        }
        setState(() => _isCtrlActive = false);
      } else if (_isAltActive) {
        _adbClient.writeShellCommand('\x1B$char', addNewline: false);
        setState(() => _isAltActive = false);
      }
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

  void _moveCursor(int offset) {
    final currentOffset = _commandController.selection.baseOffset;
    if (currentOffset == -1) return;
    final newOffset = (currentOffset + offset).clamp(0, _commandController.text.length);
    _commandController.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _insertChar(String char) {
    final text = _commandController.text;
    final selection = _commandController.selection;
    if (selection.baseOffset == -1) {
      _commandController.text = text + char;
    } else {
      final newText = text.replaceRange(selection.start, selection.end, char);
      _commandController.text = newText;
      _commandController.selection = TextSelection.collapsed(offset: selection.start + 1);
    }
  }

  Widget _buildExtraKey(String label, VoidCallback onTap, {bool isActive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Material(
        color: isActive 
            ? AppColors.primary 
            : (isDark ? AppColors.neutral800 : AppColors.neutral200),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive 
                    ? Colors.white 
                    : (isDark ? AppColors.neutral100 : AppColors.neutral900),
              ),
            ),
          ),
        ),
      ),
    );
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
                            const Icon(
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
              itemCount: _terminal.lines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                  child: Text(
                    _terminal.lines[index],
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
        // Extra Keys Row (Termux Style)
        if (_isShellReady)
          Container(
            height: 40,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildExtraKey('ESC', () => _adbClient.writeShellCommand('\x1B', addNewline: false)),
                _buildExtraKey('TAB', () => _adbClient.writeShellCommand('\t', addNewline: false)),
                _buildExtraKey('CTRL', () => setState(() => _isCtrlActive = !_isCtrlActive), isActive: _isCtrlActive),
                _buildExtraKey('ALT', () => setState(() => _isAltActive = !_isAltActive), isActive: _isAltActive),
                _buildExtraKey('-', () => _insertChar('-')),
                _buildExtraKey('/', () => _insertChar('/')),
                _buildExtraKey('|', () => _insertChar('|')),
                _buildExtraKey('UP', _historyUp),
                _buildExtraKey('DOWN', _historyDown),
                _buildExtraKey('<', () => _moveCursor(-1)),
                _buildExtraKey('>', () => _moveCursor(1)),
              ],
            ),
          ),
        // Terminal Input Field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  enabled: _isShellReady,
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _submitCommand(),
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: _isShellReady ? '> Type command (e.g. adb shell ls)' : 'Waiting for connection...',
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
              // Send Button
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: _isShellReady ? AppColors.primary : AppColors.neutral400.withOpacity(0.5),
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
      body: Column(
        children: [
          _buildDeviceSelector(),
          Expanded(child: _buildCurrentPage()),
        ],
      ),
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
