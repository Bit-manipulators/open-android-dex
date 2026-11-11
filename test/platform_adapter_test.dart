import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/services/platform_adapter.dart';

void main() {
  group('PlatformAdapter Tests', () {
    test('detects platform correctly', () {
      expect(PlatformAdapter.isLinux, Platform.isLinux);
      expect(PlatformAdapter.isWindows, Platform.isWindows);
      expect(PlatformAdapter.isMacOS, Platform.isMacOS);
    });

    test('configDirectory returns valid, existing path', () {
      final configDir = PlatformAdapter.configDirectory;
      expect(configDir, isNotEmpty);
      expect(Directory(configDir).existsSync(), isTrue);
    });

    test('cacheDirectory returns valid, existing path', () {
      final cacheDir = PlatformAdapter.cacheDirectory;
      expect(cacheDir, isNotEmpty);
      expect(Directory(cacheDir).existsSync(), isTrue);
    });

    test('runtimeDirectory returns valid, existing path', () {
      final runtimeDir = PlatformAdapter.runtimeDirectory;
      expect(runtimeDir, isNotEmpty);
      expect(Directory(runtimeDir).existsSync(), isTrue);
    });

    test('getStreamPipePath formats correctly for current platform', () {
      final pipe = PlatformAdapter.getStreamPipePath('test_win_1');
      if (Platform.isWindows) {
        expect(pipe, startsWith(r'\\.\pipe\opendex_stream_'));
      } else {
        expect(pipe, contains('stream_test_win_1.mkv'));
      }
    });

    test('createStreamPipe and cleanupStreamPipes handle pipes gracefully',
        () async {
      final pipePath = PlatformAdapter.getStreamPipePath('unit_test_pipe');
      final created = await PlatformAdapter.createStreamPipe(pipePath);
      expect(created, isTrue);

      // Clean up should not throw
      PlatformAdapter.cleanupStreamPipes('unit_test_pipe', pipePath);
    });

    test('resolves adb and scrcpy executables', () {
      final adb = PlatformAdapter.adbExecutable;
      final scrcpy = PlatformAdapter.scrcpyExecutable;

      expect(adb, isNotEmpty);
      expect(scrcpy, isNotEmpty);
      if (Platform.isWindows) {
        expect(adb, endsWith('.exe'));
        expect(scrcpy, endsWith('.exe'));
      } else {
        expect(adb, anyOf(equals('adb'), endsWith('/adb')));
        expect(scrcpy, anyOf(equals('scrcpy'), endsWith('/scrcpy')));
      }
    });

    test('provides scrcpyEnvironment with ADB and server paths', () {
      final env = PlatformAdapter.scrcpyEnvironment;
      expect(env, isNotNull);
      final adb = PlatformAdapter.adbExecutable;
      if (adb != 'adb' && adb != 'adb.exe') {
        expect(env['ADB'], equals(adb));
      }
      final server = PlatformAdapter.scrcpyServerPath;
      if (server != null) {
        expect(env['SCRCPY_SERVER_PATH'], equals(server));
      }
    });
  });
}
