import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/services/adb_service.dart';
import 'package:open_android_dex/services/touch_input_service.dart';

void main() {
  group('AdbService Tests', () {
    final adb = AdbService();

    test('generateQrPairingPayload generates 6-digit numeric password format',
        () {
      final payload = adb.generateQrPairingPayload();
      expect(payload, startsWith('WIFI:T:ADB;S:OpenAndroidDeX;P:'));
      expect(payload, endsWith(';;'));

      final match = RegExp(r'P:(\d{6});').firstMatch(payload);
      expect(match, isNotNull,
          reason: 'Pairing password in QR code must be a 6-digit number');
    });

    test('generateQrPairingPayload with custom password preserves it', () {
      final payload = adb.generateQrPairingPayload('123456', 'CustomDeX');
      expect(payload, equals('WIFI:T:ADB;S:CustomDeX;P:123456;;'));
    });

    test('isWiredSerial and isWirelessSerial correctly categorize serials', () {
      expect(AdbService.isWiredSerial('emulator-5554'), isTrue);
      expect(AdbService.isWiredSerial('1234567890ABCDEF'), isTrue);
      expect(AdbService.isWiredSerial('192.168.1.100:5555'), isFalse);
      expect(
          AdbService.isWiredSerial(
              'adb-ZD222H7659-gUr5K7._adb-tls-connect._tcp'),
          isFalse);

      expect(AdbService.isWirelessSerial('192.168.1.100:5555'), isTrue);
      expect(
          AdbService.isWirelessSerial(
              'adb-ZD222H7659-gUr5K7._adb-tls-connect._tcp'),
          isTrue);
      expect(AdbService.isWirelessSerial('1234567890ABCDEF'), isFalse);
    });

    test('supportsVirtualDisplay accurately requires Android 14+ (SDK >= 34)',
        () {
      adb.androidSdkVersion = 31; // Android 12 (e.g. Redmi Note 12 Pro)
      expect(adb.supportsVirtualDisplay, isFalse);

      adb.androidSdkVersion = 33; // Android 13
      expect(adb.supportsVirtualDisplay, isFalse);

      adb.androidSdkVersion = 34; // Android 14
      expect(adb.supportsVirtualDisplay, isTrue);

      adb.androidSdkVersion = 36; // Android 16 (e.g. Samsung Galaxy S21 FE)
      expect(adb.supportsVirtualDisplay, isTrue);
    });
  });

  group('TouchInputService Tests', () {
    final touch = TouchInputService();

    test('normalizeCoordinates correctly calculates aspect coordinates', () {
      final p1 = touch.normalizeCoordinates(
        localX: 50,
        localY: 100,
        viewportWidth: 100,
        viewportHeight: 200,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );
      expect(p1.x, equals(540));
      expect(p1.y, equals(1200));
    });

    test('normalizeCoordinates clamps values outside viewport', () {
      final p = touch.normalizeCoordinates(
        localX: -20,
        localY: 300,
        viewportWidth: 100,
        viewportHeight: 200,
        deviceWidth: 1000,
        deviceHeight: 2000,
      );
      expect(p.x, equals(0));
      expect(p.y, equals(2000));
    });
  });
}
