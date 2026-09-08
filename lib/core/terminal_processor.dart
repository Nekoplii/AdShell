/// Lightweight ANSI/VT100 terminal processor.
/// Handles common escape sequences and strips unrecognized ones.
class TerminalProcessor {
  final List<String> lines = [''];
  int _cursorRow = 0;

  // Regex to match all ANSI escape sequences
  static final RegExp _ansiEscape = RegExp(
    r'\x1B'        // ESC character
    r'('
    r'\[[0-9;]*[A-Za-z]'  // CSI sequences: ESC [ ... letter
    r'|'
    r'\][^\x07]*\x07'     // OSC sequences: ESC ] ... BEL
    r'|'
    r'\[[\?]?[0-9;]*[hl]' // Private mode set/reset
    r'|'
    r'[()][AB012]'        // Character set selection
    r'|'
    r'[78DMHc=>]'         // Single character commands
    r')',
  );

  // Match specific CSI sequences we want to handle
  static final RegExp _csiClear = RegExp(r'\x1B\[([012]?)J');
  static final RegExp _csiCursorHome = RegExp(r'\x1B\[([0-9]*);?([0-9]*)H');
  static final RegExp _csiEraseLine = RegExp(r'\x1B\[([012]?)K');

  /// Process raw output from ADB shell and return cleaned lines.
  void processOutput(String rawData) {
    // First handle actionable ANSI sequences
    var data = rawData;

    // Handle clear screen
    if (_csiClear.hasMatch(data)) {
      final match = _csiClear.firstMatch(data)!;
      final mode = match.group(1) ?? '';
      if (mode == '2' || mode == '') {
        // Clear entire screen
        lines.clear();
        lines.add('');
        _cursorRow = 0;
      }
      data = data.replaceAll(_csiClear, '');
    }

    // Handle cursor home
    if (_csiCursorHome.hasMatch(data)) {
      _cursorRow = 0;
      data = data.replaceAll(_csiCursorHome, '');
    }

    // Handle erase line
    if (_csiEraseLine.hasMatch(data)) {
      if (_cursorRow < lines.length) {
        lines[_cursorRow] = '';
      }
      data = data.replaceAll(_csiEraseLine, '');
    }

    // Strip all remaining ANSI escape sequences
    data = data.replaceAll(_ansiEscape, '');

    // Strip standalone ESC character followed by unknown
    data = data.replaceAll(RegExp(r'\x1B'), '');

    // Handle BEL (bell) character - just remove it
    data = data.replaceAll('\x07', '');

    // Handle backspace
    data = data.replaceAll('\x08', '');

    // Now process the cleaned text character by character
    _appendText(data);
  }

  void _appendText(String text) {
    // Ensure cursor row exists
    while (_cursorRow >= lines.length) {
      lines.add('');
    }

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '\n') {
        _cursorRow++;
        if (_cursorRow >= lines.length) {
          lines.add('');
        }
      } else if (char == '\r') {
        // Carriage return: move cursor to beginning of current line
        // Next characters will overwrite the line
        // Don't add a new line, just reset position
        continue;
      } else {
        lines[_cursorRow] += char;
      }
    }
  }

  /// Get a copy of current terminal lines.
  List<String> getLines() => List<String>.from(lines);

  /// Clear terminal.
  void clear() {
    lines.clear();
    lines.add('');
    _cursorRow = 0;
  }
}
