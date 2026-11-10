import 'dart:io';
import 'package:flutter/foundation.dart';
import 'platform_adapter.dart';

/// Centralized file and memory diagnostic logger for Open Android DeX.
/// Logs are persisted to disk (%LOCALAPPDATA%\OpenAndroidDeX\logs\opendex.log on Windows)
/// and retained in an in-memory ring buffer for the UI diagnostics viewer.
class AppLogger {
  static final List<String> _recentLogs = [];
  static const int _maxInMemoryLogs = 300;
  static File? _logFile;
  static bool _initialized = false;

  /// Initializes the log file and writes the startup header.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    try {
      final dir = Directory(PlatformAdapter.logDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _logFile = File(PlatformAdapter.logFilePath);
      if (!_logFile!.existsSync()) {
        _logFile!.createSync(recursive: true);
      }
      info(
          '=== Open Android DeX Started [OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}] ===');
      info('App Directory: ${PlatformAdapter.appDirectory}');
      info('Log File: ${PlatformAdapter.logFilePath}');
    } catch (e) {
      debugPrint('[AppLogger] Initialization warning: $e');
    }
  }

  /// Logs informational events.
  static void info(String message) => _write('INFO', message);

  /// Logs warnings.
  static void warning(String message) => _write('WARN', message);

  /// Logs error events with optional error object and stack trace.
  static void error(String message, [Object? err, StackTrace? stack]) {
    final extra = err != null ? ' | $err' : '';
    _write('ERROR', '$message$extra');
    if (stack != null) {
      _write('STACK', stack.toString().trim());
    }
  }

  static void _write(String level, String message) {
    final now = DateTime.now().toIso8601String();
    final entry = '[$now] [$level] $message';
    debugPrint(entry);

    _recentLogs.add(entry);
    if (_recentLogs.length > _maxInMemoryLogs) {
      _recentLogs.removeAt(0);
    }

    try {
      _logFile?.writeAsStringSync('$entry\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// Returns recent in-memory log entries.
  static List<String> get recentLogs => List.unmodifiable(_recentLogs);

  /// Path to the current log file.
  static String get logFilePath => PlatformAdapter.logFilePath;

  /// Attempts to reveal the log file in the platform's file manager.
  static Future<void> openLogFolder() async {
    final dir = PlatformAdapter.logDirectory;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir]);
      }
    } catch (e) {
      error('Failed to open log directory: $dir', e);
    }
  }
}
