import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/models/app_info.dart';
import 'package:open_android_dex/services/adb_service.dart';
import 'package:open_android_dex/services/scrcpy_stream_service.dart';
import 'package:open_android_dex/widgets/app_drawer_dialog.dart';
import 'package:open_android_dex/widgets/display_resolution_dialog.dart';

void main() {
  group('Resolution Presets & Custom Resolution Tests (Issue #15)', () {
    final service = ScrcpyStreamService();

    setUp(() {
      service.clearCustomResolution();
    });

    test('default preset is auto', () {
      expect(service.activePreset.id, equals('auto'));
      expect(service.activePreset.isAuto, isTrue);
    });

    test('setResolutionPreset updates active preset and custom values', () {
      final preset1080p =
          ScrcpyStreamService.presets.firstWhere((p) => p.id == '1080p');
      service.setResolutionPreset(preset1080p,
          customW: 1920, customH: 1080, customD: 240);

      expect(service.activePreset.id, equals('1080p'));
      expect(service.customWidth, equals(1920));
      expect(service.customHeight, equals(1080));
      expect(service.customDpi, equals(240));

      service.clearCustomResolution();
      expect(service.activePreset.id, equals('auto'));
      expect(service.customWidth, isNull);
    });

    testWidgets('DisplayResolutionDialog renders and applies 1080p preset',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DisplayResolutionDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Display Resolution & DPI'), findsOneWidget);
      expect(find.text('1080p FHD (1920x1080 @ 240 DPI)'), findsOneWidget);
      expect(find.text('Apply & Stream'), findsOneWidget);

      // Select 1080p preset chip
      await tester.tap(find.text('1080p FHD (1920x1080 @ 240 DPI)'));
      await tester.pumpAndSettle();

      // Ensure button is visible before tapping
      await tester.ensureVisible(find.text('Apply & Stream'));
      await tester.pumpAndSettle();

      // Tap Apply
      await tester.tap(find.text('Apply & Stream'));
      await tester.pumpAndSettle();

      expect(service.activePreset.id, equals('1080p'));
    });
  });

  group('System App Hiding & Filtering Tests (Issue #17)', () {
    final adb = AdbService();

    setUp(() {
      adb.enableDemoMode();
    });

    tearDown(() {
      adb.stopPolling();
    });

    test('AppInfo correctly stores and preserves isSystemApp flag', () {
      final userApp = AppInfo.fromPackage('com.example.userapp', null, false);
      expect(userApp.isSystemApp, isFalse);

      final sysApp = AppInfo.fromPackage('com.android.settings', null, true);
      expect(sysApp.isSystemApp, isTrue);

      final copied = sysApp.copyWith(name: 'Custom Settings');
      expect(copied.isSystemApp, isTrue);
    });

    testWidgets(
        'AppDrawerDialog hides system apps by default and reveals on toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDrawerDialog(
              onSelectApp: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default: "System Apps (Hidden)" chip is present
      expect(find.text('System Apps (Hidden)'), findsOneWidget);

      // User apps should be visible (e.g. Chrome)
      expect(find.text('Chrome'), findsOneWidget);

      // System apps should be hidden by default (e.g. Settings, Documents / Files)
      expect(find.text('Settings'), findsNothing);

      // Toggle chip to show system apps
      await tester.tap(find.text('System Apps (Hidden)'));
      await tester.pumpAndSettle();

      // Now chip says "System Apps (Shown)"
      expect(find.text('System Apps (Shown)'), findsOneWidget);

      // System apps should now be visible
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
