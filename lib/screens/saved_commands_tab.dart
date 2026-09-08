import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';

class SavedCommand {
  final String title;
  final String command;

  SavedCommand({required this.title, required this.command});

  Map<String, dynamic> toJson() => {
        'title': title,
        'command': command,
      };

  factory SavedCommand.fromJson(Map<String, dynamic> json) => SavedCommand(
        title: json['title'],
        command: json['command'],
      );
}

class SavedCommandsTab extends StatefulWidget {
  final bool isConnected;
  final Function(String) onExecuteCommand;

  const SavedCommandsTab({super.key, required this.isConnected, required this.onExecuteCommand});

  @override
  State<SavedCommandsTab> createState() => _SavedCommandsTabState();
}

class _SavedCommandsTabState extends State<SavedCommandsTab> {
  List<SavedCommand> _commands = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    final box = Hive.box('adshell');
    final String? commandsJson = box.get('saved_commands');
    
    if (commandsJson != null) {
      final List<dynamic> decoded = jsonDecode(commandsJson);
      setState(() {
        _commands = decoded.map((e) => SavedCommand.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      // Default sample commands
      setState(() {
        _commands = [
          SavedCommand(title: 'List Packages', command: 'pm list packages -3'),
          SavedCommand(title: 'Device Properties', command: 'getprop'),
          SavedCommand(title: 'Reboot to Bootloader', command: 'reboot bootloader'),
          SavedCommand(title: 'Battery Info', command: 'dumpsys battery'),
        ];
        _isLoading = false;
      });
      _saveCommands();
    }
  }

  Future<void> _saveCommands() async {
    final box = Hive.box('adshell');
    final String encoded = jsonEncode(_commands.map((e) => e.toJson()).toList());
    await box.put('saved_commands', encoded);
  }

  void _showCommandDialog({SavedCommand? commandToEdit, int? index}) {
    final titleController = TextEditingController(text: commandToEdit?.title ?? '');
    final commandController = TextEditingController(text: commandToEdit?.command ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.neutral900 : AppColors.neutral50,
          title: Text(commandToEdit == null ? 'New Command' : 'Edit Command'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g. Reboot Device)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commandController,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Command (e.g. adb reboot)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final cmd = commandController.text.trim();
                if (title.isNotEmpty && cmd.isNotEmpty) {
                  setState(() {
                    if (commandToEdit == null) {
                      _commands.add(SavedCommand(title: title, command: cmd));
                    } else {
                      _commands[index!] = SavedCommand(title: title, command: cmd);
                    }
                  });
                  _saveCommands();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCommand(int index) {
    setState(() {
      _commands.removeAt(index);
    });
    _saveCommands();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _commands.isEmpty && widget.isConnected
          ? Center(
              child: Text(
                'No saved commands.',
                style: TextStyle(color: isDark ? AppColors.neutral400 : AppColors.neutral500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: _commands.length + (widget.isConnected ? 0 : 1), // Add 1 for the banner if disconnected
              itemBuilder: (context, index) {
                // If disconnected, render the banner at index 0
                if (!widget.isConnected) {
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                              'Connect a device to execute commands.',
                              style: TextStyle(color: isDark ? Colors.redAccent[100] : Colors.red[900]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Shift the index by 1 to render the actual commands
                  index -= 1;
                }

                if (index < 0 || index >= _commands.length) return const SizedBox.shrink();
                
                final cmd = _commands[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral900 : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      cmd.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.isConnected 
                            ? (isDark ? AppColors.neutral50 : AppColors.neutral900)
                            : AppColors.neutral500,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        cmd.command,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: widget.isConnected 
                              ? (isDark ? AppColors.primary : AppColors.primary.withValues(alpha: 0.8))
                              : AppColors.neutral500,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 20, color: isDark ? AppColors.neutral400 : AppColors.neutral600),
                          onPressed: () => _showCommandDialog(commandToEdit: cmd, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                          onPressed: () => _deleteCommand(index),
                        ),
                      ],
                    ),
                    enabled: widget.isConnected,
                    onTap: widget.isConnected ? () {
                      widget.onExecuteCommand(cmd.command);
                    } : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCommandDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
