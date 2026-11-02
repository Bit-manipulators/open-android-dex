import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/main.dart';

void main() {
  testWidgets('App renders desktop shell', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenAndroidDexApp());
    expect(find.byType(OpenAndroidDexApp), findsOneWidget);
  });
}
