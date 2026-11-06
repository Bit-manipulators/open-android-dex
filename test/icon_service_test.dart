import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/models/app_info.dart';
import 'package:open_android_dex/services/icon_extraction_service.dart';

void main() {
  group('AppInfo Icon Tests', () {
    test('fromPackage and copyWith correctly handle iconPath', () {
      final app = AppInfo.fromPackage('com.android.chrome');
      expect(app.iconPath, isNull);

      final updated = app.copyWith(iconPath: '/tmp/test_chrome.png');
      expect(updated.iconPath, equals('/tmp/test_chrome.png'));
      expect(updated.name, equals('Chrome'));
      expect(updated.packageName, equals('com.android.chrome'));
    });
  });

  group('IconExtractionService Tests', () {
    final service = IconExtractionService();

    test('iconCacheDirectory is resolved and created', () {
      final dirPath = service.iconCacheDirectory;
      expect(dirPath, isNotEmpty);
      expect(Directory(dirPath).existsSync(), isTrue);
    });

    test('getCachedIconPath returns null for non-existent icon', () {
      final path = service.getCachedIconPath('com.nonexistent.app.123456');
      expect(path, isNull);
    });

    test('getCachedIconPath returns path when file exists with content', () {
      final testFile =
          File('${service.iconCacheDirectory}/com.test.dummyapp.png');
      testFile.writeAsBytesSync(List.filled(200, 1));
      try {
        final path = service.getCachedIconPath('com.test.dummyapp');
        expect(path, equals(testFile.path));
      } finally {
        if (testFile.existsSync()) {
          testFile.deleteSync();
        }
      }
    });

    test('getCachedIconPath isolates per-device serial cache', () {
      const serialA = 'device_A_123';
      const serialB = 'device_B_456';
      final devDirA = service.getDeviceIconCacheDirectory(serialA);
      service.getDeviceIconCacheDirectory(serialB);

      final iconA = File('$devDirA/com.test.multi.png');
      iconA.writeAsBytesSync(List.filled(200, 1));

      try {
        expect(service.getCachedIconPath('com.test.multi', serial: serialA),
            equals(iconA.path));
        expect(service.getCachedIconPath('com.test.multi', serial: serialB),
            isNull);
      } finally {
        if (iconA.existsSync()) iconA.deleteSync();
      }
    });

    test('sanitizeSerial cleans colons and special characters', () {
      expect(IconExtractionService.sanitizeSerial('192.168.1.100:5555'),
          equals('192_168_1_100_5555'));
      expect(
          IconExtractionService.sanitizeSerial(
              'adb-ZD222H7659-gUr5K7._adb-tls-connect._tcp'),
          equals('adb-ZD222H7659-gUr5K7__adb-tls-connect__tcp'));
    });
  });
}
