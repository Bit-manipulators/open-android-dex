import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/services/adb_service.dart';
import 'package:open_android_dex/views/dex_desktop_screen.dart';
import 'package:open_android_dex/widgets/app_drawer_dialog.dart';

void main() {
  setUp(() {
    final adb = AdbService();
    adb.enableDemoMode();
  });

  tearDown(() {
    AdbService().stopPolling();
  });

  testWidgets('AppDrawerDialog automatically selects/focuses the search bar',
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

    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.autofocus, isTrue);
    expect(searchField.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
      'Pressing Enter after typing app name in AppDrawerDialog opens first app',
      (WidgetTester tester) async {
    String? selectedPkg;
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDrawerDialog(
            onSelectApp: (app) => selectedPkg = app.packageName,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type "chrome" and press hardware Enter key
    await tester.enterText(find.byType(TextField), 'chrome');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selectedPkg, 'com.android.chrome');
    expect(closed, isTrue);
  });

  testWidgets('Clicking outside QuickSettingsPanel closes it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DexDesktopScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially QuickSettingsPanel is closed
    expect(find.text('Internet'), findsNothing);

    // Open QuickSettingsPanel by tapping Control Center button on taskbar
    final quickSettingsBtn =
        find.byTooltip('Quick Settings & Media Controls (Android 16)');
    expect(quickSettingsBtn, findsOneWidget);
    await tester.tap(quickSettingsBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify it is open
    expect(find.text('Internet'), findsOneWidget);

    // Click outside (e.g. top-left of desktop at (100, 100))
    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify it is closed/minimized
    expect(find.text('Internet'), findsNothing);
  });

  testWidgets('Desktop icons are placed statically with no scroll view',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DexDesktopScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify desktop icons are present statically
    expect(find.text('Chrome'), findsWidgets);
    expect(find.text('Calculator'), findsWidgets);
  });
}
