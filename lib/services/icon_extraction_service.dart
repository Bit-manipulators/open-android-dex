import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'platform_adapter.dart';

/// Event payload emitted whenever a single real-time icon has been extracted
/// and pulled from a connected Android device.
class SingleIconUpdate {
  final String serial;
  final String packageName;
  final String iconPath;

  const SingleIconUpdate({
    required this.serial,
    required this.packageName,
    required this.iconPath,
  });
}

class IconExtractionService {
  static final IconExtractionService _instance =
      IconExtractionService._internal();
  factory IconExtractionService() => _instance;
  IconExtractionService._internal();

  /// Track actively extracting serials independently to allow multi-device extraction.
  final Set<String> _extractingSerials = {};

  final _singleIconController = StreamController<SingleIconUpdate>.broadcast();
  Stream<SingleIconUpdate> get onSingleIconExtracted =>
      _singleIconController.stream;

  final _iconUpdatesController = StreamController<String>.broadcast();
  Stream<String> get onIconExtracted => _iconUpdatesController.stream;

  bool isExtracting([String? serial]) => serial == null
      ? _extractingSerials.isNotEmpty
      : _extractingSerials.contains(serial);

  /// Cleans serial numbers for safe filesystem and directory usage.
  static String sanitizeSerial(String serial) =>
      serial.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  /// Resolves the host system cache directory for app icons.
  String get iconCacheDirectory {
    final dir = Directory('${PlatformAdapter.cacheDirectory}/icons');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir.path;
  }

  /// Resolves device-specific host cache directory to avoid icon collision across connected devices.
  String getDeviceIconCacheDirectory(String serial) {
    final safe = sanitizeSerial(serial);
    final dir = Directory('$iconCacheDirectory/$safe');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir.path;
  }

  /// Returns the cached icon path on the host filesystem if available.
  /// Checks device-specific cache first, then falls back to global cache.
  String? getCachedIconPath(String packageName, {String? serial}) {
    if (serial != null && serial.isNotEmpty) {
      final safe = sanitizeSerial(serial);
      final devFile = File('$iconCacheDirectory/$safe/$packageName.png');
      if (devFile.existsSync() && devFile.lengthSync() > 100) {
        return devFile.path;
      }
    }
    final file = File('$iconCacheDirectory/$packageName.png');
    if (file.existsSync() && file.lengthSync() > 100) {
      return file.path;
    }
    return null;
  }

  /// Finds the local dex helper binary file on the host machine.
  String? _resolveLocalDexPath() {
    final appDir = PlatformAdapter.appDirectory;
    final candidates = [
      'assets/bin/dex_icon_dumper.dex',
      '${Directory.current.path}/assets/bin/dex_icon_dumper.dex',
      '$appDir/data/flutter_assets/assets/bin/dex_icon_dumper.dex',
      '$appDir\\data\\flutter_assets\\assets\\bin\\dex_icon_dumper.dex',
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

  /// Extracts real icons from the connected Android device in real time,
  /// streaming newly pulled icons as they are dumped without blocking other devices.
  Future<void> extractIconsForDevice(
      String serial, List<String> packageNames) async {
    if (_extractingSerials.contains(serial)) return;

    // Check which packages actually need extraction for this device
    final missingPackages = packageNames
        .where((pkg) => getCachedIconPath(pkg, serial: serial) == null)
        .toList();
    if (missingPackages.isEmpty) {
      return;
    }

    final localDex = _resolveLocalDexPath();
    if (localDex == null) {
      debugPrint(
          '[IconExtractionService] Could not locate local dex_icon_dumper.dex');
      return;
    }

    _extractingSerials.add(serial);
    try {
      final safeSerial = sanitizeSerial(serial);
      final remoteDex = '/data/local/tmp/opendex_dumper_$safeSerial.dex';
      final remoteOutputDir = '/data/local/tmp/opendex_icons_$safeSerial';
      final hostDeviceDir = getDeviceIconCacheDirectory(serial);
      final hostGlobalDir = iconCacheDirectory;

      // 1. Push DEX helper to the specific device (-s serial)
      final pushRes = await Process.run(PlatformAdapter.adbExecutable,
          ['-s', serial, 'push', localDex, remoteDex]);
      if (pushRes.exitCode != 0) {
        debugPrint(
            '[IconExtractionService] Failed to push helper dex to $serial: ${pushRes.stderr}');
        return;
      }

      // 2. Prepare remote output directory for this device
      await Process.run(PlatformAdapter.adbExecutable,
          ['-s', serial, 'shell', 'mkdir', '-p', remoteOutputDir]);

      // 3. Launch the dumper via Process.start to stream icon creation in real time
      final runArgs = [
        '-s',
        serial,
        'shell',
        'CLASSPATH=$remoteDex',
        '/system/bin/app_process',
        '/data/local/tmp',
        'com.opendex.tools.DexIconDumper',
        remoteOutputDir,
      ];

      final process =
          await Process.start(PlatformAdapter.adbExecutable, runArgs);

      // Listen for ICON:<pkg>:<path> lines as they are dumped on device
      final lineStream = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final rawLine in lineStream) {
        final line = rawLine.trim();
        if (line.startsWith('ICON:')) {
          final parts = line.split(':');
          if (parts.length >= 3) {
            final pkg = parts[1].trim();
            final remoteIconPath = parts.sublist(2).join(':').trim();

            if (pkg.isNotEmpty && remoteIconPath.isNotEmpty) {
              final targetDevPath = '$hostDeviceDir/$pkg.png';

              // Pull this newly generated icon immediately to host in real time
              final pullRes = await Process.run(PlatformAdapter.adbExecutable, [
                '-s',
                serial,
                'pull',
                remoteIconPath,
                targetDevPath,
              ]);

              if (pullRes.exitCode == 0 && File(targetDevPath).existsSync()) {
                // Also mirror to global cache for fast fallback
                try {
                  final globalPath = '$hostGlobalDir/$pkg.png';
                  if (!File(globalPath).existsSync()) {
                    File(targetDevPath).copySync(globalPath);
                  }
                } catch (_) {}

                // Emit real-time single icon extraction event
                _singleIconController.add(SingleIconUpdate(
                  serial: serial,
                  packageName: pkg,
                  iconPath: targetDevPath,
                ));
              }
            }
          }
        }
      }

      // Wait for app_process to finish
      await process.exitCode;

      // 4. Final safety pull of any remaining icons in the directory
      await Process.run(PlatformAdapter.adbExecutable, [
        '-s',
        serial,
        'pull',
        '$remoteOutputDir/.',
        hostDeviceDir,
      ]);

      // 5. Cleanup temporary device files in the background
      Process.run(PlatformAdapter.adbExecutable, [
        '-s',
        serial,
        'shell',
        'rm -rf $remoteOutputDir $remoteDex',
      ]);

      // 6. Direct APK fallback for any packages that could not be dumped
      final remainingMissing = packageNames
          .where((pkg) => getCachedIconPath(pkg, serial: serial) == null)
          .toList();
      if (remainingMissing.isNotEmpty) {
        await _extractIconsViaApkFallback(
            serial, remainingMissing, hostDeviceDir, hostGlobalDir);
      }

      // 7. Notify that extraction for this device is complete
      _iconUpdatesController.add(serial);
    } catch (e) {
      debugPrint(
          '[IconExtractionService] Exception during extraction for $serial: $e');
    } finally {
      _extractingSerials.remove(serial);
    }
  }

  /// Extracts launcher icon directly from installed APK as fallback when
  /// system_server context is restricted by the Android OS.
  Future<void> _extractIconsViaApkFallback(
    String serial,
    List<String> packages,
    String hostDeviceDir,
    String hostGlobalDir,
  ) async {
    for (final pkg in packages) {
      if (getCachedIconPath(pkg, serial: serial) != null) continue;
      try {
        final pathRes = await Process.run(
          PlatformAdapter.adbExecutable,
          ['-s', serial, 'shell', 'pm', 'path', pkg],
        );
        if (pathRes.exitCode != 0) continue;
        final lines = (pathRes.stdout as String).split('\n');
        String? apkPath;
        for (var line in lines) {
          line = line.trim();
          if (line.startsWith('package:')) {
            apkPath = line.replaceFirst('package:', '').trim();
            break;
          }
        }
        if (apkPath == null || apkPath.isEmpty) continue;

        final targetDevPath = '$hostDeviceDir/$pkg.png';
        final remoteIconTmp = '/data/local/tmp/icon_${pkg}.png';

        const iconCandidates = [
          'res/mipmap-xxxhdpi-v4/ic_launcher.png',
          'res/mipmap-xxhdpi-v4/ic_launcher.png',
          'res/mipmap-xhdpi-v4/ic_launcher.png',
          'res/mipmap-hdpi-v4/ic_launcher.png',
          'res/mipmap-xxxhdpi/ic_launcher.png',
          'res/mipmap-xxhdpi/ic_launcher.png',
          'res/mipmap-xhdpi/ic_launcher.png',
          'res/mipmap-hdpi/ic_launcher.png',
          'res/drawable-xxxhdpi-v4/ic_launcher.png',
          'res/drawable-xxhdpi-v4/ic_launcher.png',
          'res/drawable-xhdpi-v4/ic_launcher.png',
          'res/drawable-hdpi-v4/ic_launcher.png',
          'res/drawable-xxxhdpi/ic_launcher.png',
          'res/drawable-xxhdpi/ic_launcher.png',
          'res/drawable-xhdpi/ic_launcher.png',
          'res/drawable-hdpi/ic_launcher.png',
          'res/mipmap-mdpi/ic_launcher.png',
          'res/drawable/ic_launcher.png',
        ];

        for (final iconRes in iconCandidates) {
          final extractRes = await Process.run(
            PlatformAdapter.adbExecutable,
            [
              '-s',
              serial,
              'shell',
              'unzip',
              '-p',
              apkPath,
              iconRes,
              '>',
              remoteIconTmp
            ],
          );
          if (extractRes.exitCode == 0) {
            final pullRes = await Process.run(
              PlatformAdapter.adbExecutable,
              ['-s', serial, 'pull', remoteIconTmp, targetDevPath],
            );
            await Process.run(
              PlatformAdapter.adbExecutable,
              ['-s', serial, 'shell', 'rm', '-f', remoteIconTmp],
            );
            final f = File(targetDevPath);
            if (pullRes.exitCode == 0 &&
                f.existsSync() &&
                f.lengthSync() > 100) {
              try {
                final globalPath = '$hostGlobalDir/$pkg.png';
                if (!File(globalPath).existsSync()) {
                  f.copySync(globalPath);
                }
              } catch (_) {}

              _singleIconController.add(SingleIconUpdate(
                serial: serial,
                packageName: pkg,
                iconPath: targetDevPath,
              ));
              break;
            }
          }
        }
      } catch (_) {}
    }
  }
}
