import 'dart:async';
import 'dart:io';
import 'app_logger.dart';
import 'platform_adapter.dart';

/// Service responsible for verifying, diagnosing, and automatically installing
/// ADB and scrcpy prerequisites to provide a beginner-friendly 1-click setup experience.
class DependencyManagerService {
  static final DependencyManagerService _instance =
      DependencyManagerService._internal();
  factory DependencyManagerService() => _instance;
  DependencyManagerService._internal();

  bool _isChecking = false;
  bool _isInstalling = false;
  bool _adbAvailable = false;
  bool _scrcpyAvailable = false;
  String _adbVersion = '';
  String _scrcpyVersion = '';

  bool get isChecking => _isChecking;
  bool get isInstalling => _isInstalling;
  bool get isAdbAvailable => _adbAvailable;
  bool get isScrcpyAvailable => _scrcpyAvailable;
  bool get isFullyReady => _adbAvailable && _scrcpyAvailable;
  String get adbVersion => _adbVersion;
  String get scrcpyVersion => _scrcpyVersion;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChanged => _statusController.stream;

  /// Performs environment discovery to check if ADB and scrcpy are runnable.
  Future<bool> checkDependencies() async {
    if (_isChecking) return isFullyReady;
    _isChecking = true;

    try {
      // 1. Check ADB
      try {
        final adbRes = await Process.run(
            PlatformAdapter.adbExecutable, ['version'],
            runInShell: Platform.isWindows);
        if (adbRes.exitCode == 0) {
          _adbAvailable = true;
          final firstLine = (adbRes.stdout as String).split('\n').first.trim();
          _adbVersion = firstLine;
        } else {
          _adbAvailable = false;
          _adbVersion = '';
        }
      } catch (e) {
        _adbAvailable = false;
        _adbVersion = '';
      }

      // 2. Check scrcpy
      try {
        final scrcpyRes = await Process.run(
            PlatformAdapter.scrcpyExecutable, ['--version'],
            runInShell: Platform.isWindows);
        if (scrcpyRes.exitCode == 0) {
          _scrcpyAvailable = true;
          final firstLine =
              (scrcpyRes.stdout as String).split('\n').first.trim();
          _scrcpyVersion = firstLine;
        } else {
          _scrcpyAvailable = false;
          _scrcpyVersion = '';
        }
      } catch (e) {
        _scrcpyAvailable = false;
        _scrcpyVersion = '';
      }

      AppLogger.info(
          '[DependencyManager] ADB: ${_adbAvailable ? 'Ready ($_adbVersion)' : 'Missing'}, scrcpy: ${_scrcpyAvailable ? 'Ready ($_scrcpyVersion)' : 'Missing'}');
      _statusController.add(isFullyReady);
      return isFullyReady;
    } finally {
      _isChecking = false;
    }
  }

  /// Downloads and extracts Android Platform-Tools and scrcpy for Windows
  /// directly into the user's LocalAppData folder (%LOCALAPPDATA%\OpenAndroidDeX\tools\),
  /// with zero administrative privileges or system PATH adjustments required.
  Future<bool> autoInstallWindowsDependencies({
    void Function(String status, double progress)? onProgress,
  }) async {
    if (!Platform.isWindows) return false;
    if (_isInstalling) return false;
    _isInstalling = true;

    final toolsDir = PlatformAdapter.toolsDirectory;
    final tempDir = Directory.systemTemp.createTempSync('opendex_dep_');

    try {
      onProgress?.call('Starting automatic tool setup...', 0.05);
      AppLogger.info(
          '[DependencyManager] Auto-installing Windows tools into $toolsDir');

      // 1. Download & extract Google Android Platform-Tools
      if (!_adbAvailable) {
        onProgress?.call('Downloading Android Platform-Tools (ADB)...', 0.20);
        final adbZip = File('${tempDir.path}\\platform-tools.zip');
        await _downloadFile(
          'https://dl.google.com/android/repository/platform-tools-latest-windows.zip',
          adbZip,
          (pct) => onProgress?.call(
              'Downloading Android Platform-Tools: ${(pct * 100).toInt()}%',
              0.20 + (pct * 0.30)),
        );

        onProgress?.call('Extracting Platform-Tools...', 0.50);
        await _extractZip(adbZip.path, toolsDir);
      }

      // 2. Download & extract scrcpy
      if (!_scrcpyAvailable) {
        onProgress?.call('Downloading scrcpy streaming engine...', 0.60);
        final scrcpyZip = File('${tempDir.path}\\scrcpy.zip');
        await _downloadFile(
          'https://github.com/Genymobile/scrcpy/releases/download/v2.7/scrcpy-win64-v2.7.zip',
          scrcpyZip,
          (pct) => onProgress?.call(
              'Downloading scrcpy engine: ${(pct * 100).toInt()}%',
              0.60 + (pct * 0.30)),
        );

        onProgress?.call('Extracting scrcpy engine...', 0.90);
        final scrcpyExtract = '${tempDir.path}\\scrcpy_extract';
        await _extractZip(scrcpyZip.path, scrcpyExtract);

        // Move the extracted scrcpy folder to toolsDir\scrcpy
        final extractedDirs =
            Directory(scrcpyExtract).listSync().whereType<Directory>().toList();
        if (extractedDirs.isNotEmpty) {
          final targetScrcpyDir = Directory('$toolsDir\\scrcpy');
          if (targetScrcpyDir.existsSync()) {
            try {
              targetScrcpyDir.deleteSync(recursive: true);
            } catch (_) {}
          }
          await _copyDirectory(extractedDirs.first, targetScrcpyDir);
        }
      }

      onProgress?.call('Verifying installed tools...', 0.95);
      PlatformAdapter.resetCachedBinaryPaths();
      final success = await checkDependencies();

      onProgress?.call(
          success
              ? 'Setup completed successfully!'
              : 'Setup completed with warnings.',
          1.0);
      AppLogger.info(
          '[DependencyManager] Auto-install completed. Status: $success');
      return success;
    } catch (e, stack) {
      AppLogger.error('[DependencyManager] Tool installation failed', e, stack);
      onProgress?.call('Installation failed: $e', 1.0);
      return false;
    } finally {
      _isInstalling = false;
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _downloadFile(
    String url,
    File destination,
    void Function(double progress)? onProgress,
  ) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    final total = response.contentLength;
    int received = 0;

    final sink = destination.openWrite();
    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }
    await sink.flush();
    await sink.close();
    client.close();
  }

  Future<void> _extractZip(String zipPath, String destPath) async {
    final dir = Directory(destPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    if (Platform.isWindows) {
      // Windows 10/11 built-in tar utility extracts zip files without external dependencies
      final tarRes =
          await Process.run('tar.exe', ['-xf', zipPath, '-C', destPath]);
      if (tarRes.exitCode == 0) return;

      // Fallback: PowerShell Expand-Archive
      await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        "Expand-Archive -Path '$zipPath' -DestinationPath '$destPath' -Force"
      ]);
    } else {
      await Process.run('unzip', ['-o', zipPath, '-d', destPath]);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    for (final entity in source.listSync(recursive: false)) {
      if (entity is Directory) {
        final newDir = Directory(
            '${destination.path}${Platform.pathSeparator}${entity.uri.pathSegments.reversed.elementAt(1)}');
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        final newFile = File(
            '${destination.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}');
        entity.copySync(newFile.path);
      }
    }
  }
}
