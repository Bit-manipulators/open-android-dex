import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class IconExtractionService {
  static final IconExtractionService _instance = IconExtractionService._internal();
  factory IconExtractionService() => _instance;
  IconExtractionService._internal();

  bool _isExtracting = false;
  final _iconUpdatesController = StreamController<String>.broadcast();
  Stream<String> get onIconExtracted => _iconUpdatesController.stream;

  /// Resolves the host system cache directory for app icons.
  String get iconCacheDirectory {
    final xdgCache = Platform.environment['XDG_CACHE_HOME'];
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
    final base = (xdgCache != null && xdgCache.isNotEmpty) ? xdgCache : '$home/.cache';
    final dir = Directory('$base/open_android_dex/icons');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir.path;
  }

  /// Returns the cached icon path on the host filesystem if available.
  String? getCachedIconPath(String packageName) {
    final file = File('$iconCacheDirectory/$packageName.png');
    if (file.existsSync() && file.lengthSync() > 100) {
      return file.path;
    }
    return null;
  }

  /// Finds the local dex helper binary file on the host machine.
  String? _resolveLocalDexPath() {
    final candidates = [
      'assets/bin/dex_icon_dumper.dex',
      '${Directory.current.path}/assets/bin/dex_icon_dumper.dex',
      '${Platform.resolvedExecutable.replaceAll(RegExp(r'[^/\\]+$'), '')}data/flutter_assets/assets/bin/dex_icon_dumper.dex',
      '/tmp/build_dex/classes.dex',
    ];
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 500) {
        return f.path;
      }
    }
    return null;
  }

  /// Extracts real icons from the connected Android device in the background.
  Future<void> extractIconsForDevice(String serial, List<String> packageNames) async {
    if (_isExtracting) return;

    // Check which packages actually need extraction
    final missingPackages = packageNames.where((pkg) => getCachedIconPath(pkg) == null).toList();
    if (missingPackages.isEmpty) {
      return;
    }

    final localDex = _resolveLocalDexPath();
    if (localDex == null) {
      debugPrint('[IconExtractionService] Could not locate local dex_icon_dumper.dex');
      return;
    }

    _isExtracting = true;
    try {
      const remoteDex = '/data/local/tmp/opendex_dumper.dex';
      const remoteOutputDir = '/data/local/tmp/opendex_icons';

      // 1. Push DEX helper to device
      final pushRes = await Process.run('adb', ['-s', serial, 'push', localDex, remoteDex]);
      if (pushRes.exitCode != 0) {
        debugPrint('[IconExtractionService] Failed to push helper dex: ${pushRes.stderr}');
        _isExtracting = false;
        return;
      }

      // 2. Prepare remote output directory
      await Process.run('adb', ['-s', serial, 'shell', 'mkdir', '-p', remoteOutputDir]);

      // 3. Run the dumper on the device via app_process
      final runArgs = [
        '-s', serial,
        'shell',
        'CLASSPATH=$remoteDex',
        '/system/bin/app_process',
        '/data/local/tmp',
        'com.opendex.tools.DexIconDumper',
        remoteOutputDir,
      ];

      final runRes = await Process.run('adb', runArgs);
      debugPrint('[IconExtractionService] app_process output: ${runRes.stdout}');

      // 4. Pull all extracted icons from device into host cache
      final hostDir = iconCacheDirectory;
      final pullRes = await Process.run('adb', [
        '-s', serial,
        'pull',
        '$remoteOutputDir/.',
        hostDir,
      ]);
      debugPrint('[IconExtractionService] Pulled icons to host: ${pullRes.stdout}');

      // 5. Cleanup temporary device files in the background
      Process.run('adb', [
        '-s', serial,
        'shell',
        'rm -rf $remoteOutputDir $remoteDex',
      ]);

      // 6. Notify that new icons are ready
      _iconUpdatesController.add(serial);
    } catch (e) {
      debugPrint('[IconExtractionService] Exception during extraction: $e');
    } finally {
      _isExtracting = false;
    }
  }
}
