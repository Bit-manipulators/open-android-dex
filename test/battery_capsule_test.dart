import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/widgets/battery_capsule.dart';

void main() {
  group('TaskbarBatteryCapsule Tests', () {
    testWidgets(
        'renders charging state with bolt icon and emerald/mint styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskbarBatteryCapsule(
              batteryLevel: 94,
              isCharging: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('94%'), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.battery_charging_full_rounded));
      // Midpoint or within emerald (0xFF10B981) to mint (0xFF34D399) range
      expect(iconWidget.color, isNotNull);
      expect(
          iconWidget.color?.value, anyOf(0xFF10B981, 0xFF34D399, 0xFF22C68D));
    });

    testWidgets(
        'renders low battery state (< 20%) with red alert icon and color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskbarBatteryCapsule(
              batteryLevel: 15,
              isCharging: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('15%'), findsOneWidget);
      expect(find.byIcon(Icons.battery_alert_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.battery_alert_rounded));
      expect(iconWidget.color, const Color(0xFFEF4444));
    });

    testWidgets(
        'renders normal battery state (>= 20%) with normal battery icon and mint color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskbarBatteryCapsule(
              batteryLevel: 65,
              isCharging: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('65%'), findsOneWidget);
      expect(find.byIcon(Icons.battery_full_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);

      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.battery_full_rounded));
      expect(iconWidget.color, const Color(0xFF34D399));
    });

    testWidgets(
        'charging state takes precedence even if battery level is below 20%',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaskbarBatteryCapsule(
              batteryLevel: 10,
              isCharging: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('10%'), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });
  });
}
