import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform-specific abstraction layer providing cross-platform paths,
/// process management, binary resolution, and IPC primitives across
/// Linux and Windows 11.
class PlatformAdapter {
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;

  /// Cached executable paths once resolved
  static String? _cachedAdbPath;
  static String? _cachedScrcpyPath;

  /// Base directory of the running application
  static String get appDirectory {
    return File(Platform.resolvedExecutable).parent.path;
  }

  /// User configuration directory:
  /// - Linux: $XDG_CONFIG_HOME/open_android_dex or ~/.config/open_android_dex
  /// - Windows: %APPDATA%/OpenAndroidDeX
  static String get configDirectory {
    if (isWindows) {
      final appData = Platform.environment['APPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          'C:\\ProgramData';
      final dir = Directory('$appData\\OpenAndroidDeX');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return dir.path;
    } else {
      final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
      final home = Platform.environment['HOME'] ?? '/tmp';
      final base = (xdgConfig != null && xdgConfig.isNotEmpty)
          ? xdgConfig
          : '$home/.config';
      final dir = Directory('$base/open_android_dex');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return dir.path;
    }
  }

  /// User cache directory:
  /// - Linux: $XDG_CACHE_HOME/open_android_dex or ~/.cache/open_android_dex
  /// - Windows: %LOCALAPPDATA%/OpenAndroidDeX/cache
  static String get cacheDirectory {
    if (isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          'C:\\Temp';
      final dir = Directory('$localAppData\\OpenAndroidDeX\\cache');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return dir.path;
    } else {
      final xdgCache = Platform.environment['XDG_CACHE_HOME'];
      final home = Platform.environment['HOME'] ?? '/tmp';
      final base =
          (xdgCache != null && xdgCache.isNotEmpty) ? xdgCache : '$home/.cache';
      final dir = Directory('$base/open_android_dex');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return dir.path;
    }
  }

  /// Secure runtime / IPC directory for pipe or streaming files:
  /// - Linux: $XDG_RUNTIME_DIR/opendex or /tmp/opendex
  /// - Windows: %LOCALAPPDATA%/OpenAndroidDeX/pipes or %TEMP%/opendex
  static String get runtimeDirectory {
    if (isWindows) {
      final temp = Platform.environment['TEMP'] ??
          Platform.environment['TMP'] ??
          'C:\\Temp';
      final dir = Directory('$temp\\opendex');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return dir.path;
    } else {
      final xdgRuntime = Platform.environment['XDG_RUNTIME_DIR'];
      if (xdgRuntime != null && Directory(xdgRuntime).existsSync()) {
        final dir = Directory('$xdgRuntime/opendex');
        if (!dir.existsSync()) {
          try {
            dir.createSync(recursive: true);
          } catch (_) {}
        }
        return dir.path;
      }
      final tmpDir = Directory('/tmp/opendex');
      if (!tmpDir.existsSync()) {
        try {
          tmpDir.createSync(recursive: true);
        } catch (_) {}
      }
      return tmpDir.path;
    }
  }

  /// Resolves the streaming pipe / socket identifier for scrcpy and texture decoder.
  /// On Linux: POSIX FIFO file path ($XDG_RUNTIME_DIR/opendex/stream_<id>.mkv)
  /// On Windows: Win32 Named Pipe (\\\\.\\pipe\\opendex_stream_<id>) or temporary container file
  static String getStreamPipePath(String safeId) {
    if (isWindows) {
      // Use named pipe format recognized by Windows C++ and scrcpy/FFmpeg
      return '\\\\.\\pipe\\opendex_stream_$safeId';
    } else {
      return '$runtimeDirectory/stream_$safeId.mkv';
    }
  }

  /// Creates a streaming pipe if required by the operating system.
  /// - Linux: runs mkfifo
  /// - Windows: handled automatically when opened by Win32 Named Pipe server or temporary container
  static Future<bool> createStreamPipe(String pipePath) async {
    if (isWindows) {
      // Windows Named Pipes are initialized by the Win32 Named Pipe server in C++
      return true;
    }

    final pipeFile = File(pipePath);
    if (pipeFile.existsSync()) {
      try {
        pipeFile.deleteSync();
      } catch (_) {}
    }

    try {
      final res = await Process.run('mkfifo', [pipePath]);
      return res.exitCode == 0;
    } catch (e) {
      debugPrint('[PlatformAdapter] mkfifo error: $e');
      return false;
    }
  }

  /// Removes stream pipe or temporary files associated with a window ID.
  static void cleanupStreamPipes(String safeId, [String? specificPipe]) {
    try {
      if (specificPipe != null && !specificPipe.startsWith('\\\\.\\pipe\\')) {
        final f = File(specificPipe);
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }

      if (isWindows) {
        // Cleanup any temporary files created in runtimeDirectory
        final dir = Directory(runtimeDirectory);
        if (dir.existsSync()) {
          for (final entity in dir.listSync()) {
            if (entity is File && entity.path.contains('stream_$safeId')) {
              try {
                entity.deleteSync();
              } catch (_) {}
            }
          }
        }
      } else {
        final dirs = [
          Directory(runtimeDirectory),
          Directory('/tmp'),
        ];
        for (final dir in dirs) {
          if (dir.existsSync()) {
            for (final entity in dir.listSync()) {
              if (entity is File && entity.path.contains('stream_$safeId')) {
                try {
                  entity.deleteSync();
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Resolves the path to the adb executable, checking bundled assets,
  /// standard system locations, and PATH.
  static String get adbExecutable {
    if (_cachedAdbPath != null) return _cachedAdbPath!;

    final binaryName = isWindows ? 'adb.exe' : 'adb';
    final candidates = <String>[];

    // 1. App-bundled platform tools (portable distribution)
    candidates.add('$appDirectory\\$binaryName');
    candidates.add('$appDirectory\\platform-tools\\$binaryName');
    candidates
        .add('$appDirectory\\data\\flutter_assets\\assets\\bin\\$binaryName');

    if (isWindows) {
      // 2. Android SDK standard install locations on Windows
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        candidates
            .add('$localAppData\\Android\\Sdk\\platform-tools\\$binaryName');
      }
      final programFiles = Platform.environment['ProgramFiles'];
      if (programFiles != null) {
        candidates.add(
            '$programFiles\\Android\\android-sdk\\platform-tools\\$binaryName');
      }
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        _cachedAdbPath = path;
        return path;
      }
    }

    // Default to PATH lookup
    _cachedAdbPath = binaryName;
    return binaryName;
  }

  /// Resolves the path to the scrcpy executable, checking bundled assets,
  /// portable distribution paths, and PATH.
  static String get scrcpyExecutable {
    if (_cachedScrcpyPath != null) return _cachedScrcpyPath!;

    final binaryName = isWindows ? 'scrcpy.exe' : 'scrcpy';
    final candidates = <String>[];

    // 1. App-bundled scrcpy (portable distribution)
    candidates.add('$appDirectory\\$binaryName');
    candidates.add('$appDirectory\\scrcpy\\$binaryName');
    candidates
        .add('$appDirectory\\data\\flutter_assets\\assets\\bin\\$binaryName');

    if (isWindows) {
      final programFiles = Platform.environment['ProgramFiles'];
      if (programFiles != null) {
        candidates.add('$programFiles\\scrcpy\\$binaryName');
      }
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        candidates.add('$localAppData\\Programs\\scrcpy\\$binaryName');
      }
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        _cachedScrcpyPath = path;
        return path;
      }
    }

    // Default to PATH lookup
    _cachedScrcpyPath = binaryName;
    return binaryName;
  }

  /// Cleanly kills a process tree across Linux and Windows.
  static Future<void> killProcess(Process process) async {
    try {
      if (isWindows) {
        // On Windows, taskkill /F /T /PID terminates child processes spawned by scrcpy/adb
        try {
          await Process.run(
              'taskkill', ['/F', '/T', '/PID', process.pid.toString()]);
        } catch (_) {
          process.kill(ProcessSignal.sigkill);
        }
      } else {
        process.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 150));
        process.kill(ProcessSignal.sigkill);
      }
    } catch (_) {}
  }
}
