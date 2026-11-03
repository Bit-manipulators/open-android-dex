import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/main.dart';
import 'package:open_android_dex/services/adb_service.dart';

void main() {
  testWidgets('App renders desktop shell', (WidgetTester tester) async {
    AdbService().isDemoMode = true;
    await tester.pumpWidget(const OpenAndroidDexApp());
    expect(find.byType(OpenAndroidDexApp), findsOneWidget);
    AdbService().stopPolling();
    await tester.pumpAndSettle();
  });
}
