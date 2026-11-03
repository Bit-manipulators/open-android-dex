import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum ScrcpyDisplayMode {
  /// Uses scrcpy 3+ / 5+ new-display to create an isolated Android virtual display.
  /// The phone's primary screen is not woken or disturbed.
  virtualDisplay,

  /// Standard display mirroring targeting Display 0, turning the phone screen off.
  mirrorPrimary,
}

class ScrcpyStreamSession {
  final String id;
  final String packageName;
  final String serial;
  final ScrcpyDisplayMode mode;
  final String pipePath;
  Process? process;
  bool isRunning;
  int targetWidth;
  int targetHeight;
  int dpi;

  ScrcpyStreamSession({
    required this.id,
    required this.packageName,
    required this.serial,
    required this.pipePath,
    this.mode = ScrcpyDisplayMode.virtualDisplay,
    this.process,
    this.isRunning = false,
    this.targetWidth = 720,
    this.targetHeight = 1280,
    this.dpi = 240,
  });
}

class ScrcpyStreamService {
  static final ScrcpyStreamService _instance = ScrcpyStreamService._internal();
  factory ScrcpyStreamService() => _instance;
  ScrcpyStreamService._internal();

  final Map<String, ScrcpyStreamSession> _activeSessions = {};
  final Map<String, Future<ScrcpyStreamSession?>> _inFlightStarts = {};
  static int _nextPort = 27183;

  final _sessionStateController = StreamController<ScrcpyStreamSession>.broadcast();
  Stream<ScrcpyStreamSession> get onSessionStateChanged => _sessionStateController.stream;

  ScrcpyStreamSession? getSession(String windowId) => _activeSessions[windowId];

  /// Starts or restarts a streaming session for a window.
  Future<ScrcpyStreamSession?> startSession({
    required String windowId,
    required String packageName,
    required String serial,
    ScrcpyDisplayMode mode = ScrcpyDisplayMode.virtualDisplay,
    int width = 720,
    int height = 1280,
    int dpi = 240,
  }) async {
    // Wait for any existing in-flight start for this window to finish
    while (_inFlightStarts.containsKey(windowId)) {
      await _inFlightStarts[windowId];
    }

    final future = _doStartSession(
      windowId: windowId,
      packageName: packageName,
      serial: serial,
      mode: mode,
      width: width,
      height: height,
      dpi: dpi,
    );
    _inFlightStarts[windowId] = future;
    try {
      return await future;
    } finally {
      _inFlightStarts.remove(windowId);
    }
  }

  Future<ScrcpyStreamSession?> _doStartSession({
    required String windowId,
    required String packageName,
    required String serial,
    required ScrcpyDisplayMode mode,
    required int width,
    required int height,
    required int dpi,
  }) async {
    // 1. Gracefully stop any existing session for this window and wait for port cooldown
    await stopSession(windowId);

    // Ensure dimensions are strictly even (H.264 MediaCodec requires multiples of 2)
    final evenW = (width & ~1).clamp(360, 3840);
    final evenH = (height & ~1).clamp(360, 3840);

    final safeId = windowId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final pipePath = _getStreamPipePath(safeId);

    // 2. Ensure a clean, fresh FIFO pipe
    final pipeFile = File(pipePath);
    if (pipeFile.existsSync()) {
      try {
        pipeFile.deleteSync();
      } catch (_) {}
    }
    try {
      await Process.run('mkfifo', [pipePath]);
    } catch (e) {
      debugPrint('[ScrcpyStreamService] mkfifo error: $e');
    }

    final session = ScrcpyStreamSession(
      id: windowId,
      packageName: packageName,
      serial: serial,
      pipePath: pipePath,
      mode: mode,
      targetWidth: evenW,
      targetHeight: evenH,
      dpi: dpi,
    );

    final portBase = _nextPort;
    _nextPort += 4;
    if (_nextPort > 28000) _nextPort = 27183;

    // Run scrcpy with --no-window so no separate SDL window is opened on Hyprland!
    final args = <String>[
      '-s', serial,
      '-p', '$portBase:${portBase + 3}',
      '--no-window',
      '--record=$pipePath',
      '--record-format=mkv',
      '-b', '8M',
      '--max-fps=60',
      '--stay-awake',
      '--no-audio',
      '--video-codec-options=i-frame-interval=1',
      '--start-app=$packageName',
    ];

    if (mode == ScrcpyDisplayMode.virtualDisplay) {
      args.add('--new-display=${evenW}x$evenH/$dpi');
    } else {
      args.add('--turn-screen-off');
    }

    // Wake up device and dismiss keyguard so Android WindowManager allows the app to render on virtual display
    try {
      await Process.run('adb', ['-s', serial, 'shell', 'input', 'keyevent', 'KEYCODE_WAKEUP']);
      await Process.run('adb', ['-s', serial, 'shell', 'wm', 'dismiss-keyguard']);
    } catch (_) {}

    try {
      debugPrint('[ScrcpyStreamService] Starting headless scrcpy pipe stream (${width}x$height) to $pipePath');
      final proc = await Process.start('scrcpy', args);

      proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        debugPrint('[scrcpy stdout] $line');
      });
      proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        debugPrint('[scrcpy stderr] $line');
      });

      session.process = proc;
      session.isRunning = true;
      _activeSessions[windowId] = session;
      _sessionStateController.add(session);

      proc.exitCode.then((code) {
        debugPrint('[ScrcpyStreamService] scrcpy exited with code $code for $windowId');
        session.isRunning = false;
        _activeSessions.remove(windowId);
        _sessionStateController.add(session);
      });

      // Brief delay to allow scrcpy to open the FIFO pipe for writing
      await Future.delayed(const Duration(milliseconds: 300));

      return session;
    } catch (e) {
      debugPrint('[ScrcpyStreamService] Failed to start scrcpy: $e');
      session.isRunning = false;
      return null;
    }
  }

  /// Stops an active session with graceful SIGTERM and ADB port cooldown.
  Future<void> stopSession(String windowId) async {
    final session = _activeSessions.remove(windowId);
    if (session != null) {
      final proc = session.process;
      if (proc != null) {
        try {
          // Gracefully request scrcpy shutdown so phone scrcpy-server releases sockets
          proc.kill(ProcessSignal.sigterm);
          await proc.exitCode.timeout(
            const Duration(milliseconds: 600),
            onTimeout: () {
              proc.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        } catch (e) {
          debugPrint('[ScrcpyStreamService] Exception during process shutdown: $e');
        }
      }

      session.isRunning = false;
      _sessionStateController.add(session);

      // Cooldown delay so ADB daemon and Android 16 stack release port bindings
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Resolves a secure path for the named FIFO pipe, preferring user-specific runtime dir ($XDG_RUNTIME_DIR).
  String _getStreamPipePath(String safeId) {
    final xdgRuntime = Platform.environment['XDG_RUNTIME_DIR'];
    if (xdgRuntime != null && Directory(xdgRuntime).existsSync()) {
      final dir = Directory('$xdgRuntime/opendex');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      if (dir.existsSync()) {
        return '$xdgRuntime/opendex/stream_$safeId.mkv';
      }
    }
    return '/tmp/opendex_stream_$safeId.mkv';
  }

  /// Permanently removes the FIFO pipe file when window is destroyed.
  void cleanupPipe(String windowId) {
    try {
      final safeId = windowId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final pipeFile = File(_getStreamPipePath(safeId));
      if (pipeFile.existsSync()) {
        pipeFile.deleteSync();
      }
    } catch (_) {}
  }

  /// Stops all active sessions (e.g. when app closes).
  Future<void> stopAll() async {
    for (final id in _activeSessions.keys.toList()) {
      await stopSession(id);
      cleanupPipe(id);
    }
  }
}
