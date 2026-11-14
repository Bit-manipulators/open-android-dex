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

    test('resolves Samsung Galaxy suite package names to clean human names',
        () {
      expect(AppInfo.fromPackage('com.sec.android.app.popupcalculator').name,
          equals('Calculator'));
      expect(AppInfo.fromPackage('com.sec.android.app.sbrowser').name,
          equals('Samsung Internet'));
      expect(AppInfo.fromPackage('com.sec.android.app.camera').name,
          equals('Camera'));
      expect(AppInfo.fromPackage('com.sec.android.gallery3d').name,
          equals('Gallery'));
      expect(AppInfo.fromPackage('com.sec.android.app.myfiles').name,
          equals('My Files'));
      expect(AppInfo.fromPackage('com.sec.android.app.clockpackage').name,
          equals('Clock'));
      expect(AppInfo.fromPackage('com.sec.android.app.voicenote').name,
          equals('Voice Recorder'));
      expect(AppInfo.fromPackage('com.sec.android.app.samsungapps').name,
          equals('Galaxy Store'));
      expect(AppInfo.fromPackage('com.samsung.android.dialer').name,
          equals('Phone'));
      expect(AppInfo.fromPackage('com.samsung.android.messaging').name,
          equals('Messages'));
      expect(AppInfo.fromPackage('com.samsung.android.calendar').name,
          equals('Calendar'));
      expect(AppInfo.fromPackage('com.samsung.android.app.notes').name,
          equals('Samsung Notes'));
    });

    test('resolves Xiaomi / MIUI & HyperOS suite package names to clean human names',
        () {
      expect(AppInfo.fromPackage('com.miui.calculator').name,
          equals('Calculator'));
      expect(AppInfo.fromPackage('com.miui.gallery').name,
          equals('Gallery'));
      expect(AppInfo.fromPackage('com.miui.cleanmaster').name,
          equals('Security'));
      expect(AppInfo.fromPackage('com.miui.notes').name,
          equals('Notes'));
      expect(AppInfo.fromPackage('com.miui.weather2').name,
          equals('Weather'));
      expect(AppInfo.fromPackage('com.miui.compass').name,
          equals('Compass'));
      expect(AppInfo.fromPackage('com.miui.screenrecorder').name,
          equals('Screen Recorder'));
      expect(AppInfo.fromPackage('com.miui.videoplayer').name,
          equals('Mi Video'));
      expect(AppInfo.fromPackage('com.miui.player').name,
          equals('Mi Music'));
      expect(AppInfo.fromPackage('com.xiaomi.scanner').name,
          equals('Scanner'));
      expect(AppInfo.fromPackage('com.xiaomi.calendar').name,
          equals('Calendar'));
      expect(AppInfo.fromPackage('com.mi.android.globalfileexplorer').name,
          equals('File Manager'));
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
