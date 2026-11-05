import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/services/adb_service.dart';
import 'package:open_android_dex/widgets/quick_settings_panel.dart';

void main() {
  testWidgets('QuickSettingsPanel renders all unified buttons and sliders',
      (WidgetTester tester) async {
    final adb = AdbService();
    adb.isDemoMode = true;

    bool closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickSettingsPanel(
              onClose: () => closed = true,
            ),
          ),
        ),
      ),
    );

    // 1. Verify Header elements
    expect(find.textContaining('Output'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 2. Verify Primary Capsules (Internet & Bluetooth)
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Bluetooth'), findsOneWidget);

    // 3. Verify All 4 Quick Action Tiles
    expect(find.text('Do Not Disturb'), findsOneWidget);
    expect(find.text('Auto-rotate'), findsOneWidget);
    expect(find.text('Screenshot'), findsOneWidget);
    expect(find.text('Lock Screen'), findsOneWidget);

    // Subtitles
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);

    // 4. Verify Dual Sliders (Brightness and Volume)
    // Note: Due to dual-layer clip architecture, text exists in both base and active clip layers
    expect(find.text('Brightness'), findsNWidgets(2));
    expect(find.text('Volume'), findsNWidgets(2));

    // 5. Test interaction with Close button
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closed, isTrue);

    // 6. Test interaction with Wi-Fi tile
    final initialWifi = adb.isWifiEnabled;
    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();
    expect(adb.isWifiEnabled, !initialWifi);

    // Clean up
    adb.stopPolling();
  });
}
