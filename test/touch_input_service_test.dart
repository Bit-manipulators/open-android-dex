import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/services/touch_input_service.dart';

void main() {
  late TouchInputService service;
  late List<List<String>> adbCalls;

  setUp(() {
    service = TouchInputService();
    service.reset();
    adbCalls = [];
    service.adbRunner = (args) async {
      adbCalls.add(List<String>.from(args));
      return ProcessResult(0, 0, '', '');
    };
    service.scrollSensitivity = 1.0;
    service.naturalScrolling = true;
  });

  group('TouchInputService Coordinate Normalization', () {
    test('normalizes viewport coordinates to target device space accurately',
        () {
      final pt = service.normalizeCoordinates(
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );
      expect(pt.x, 540);
      expect(pt.y, 1200);
    });

    test('clamps coordinates that fall outside the viewport bounds', () {
      final pt = service.normalizeCoordinates(
        localX: 500,
        localY: -50,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );
      expect(pt.x, 1080);
      expect(pt.y, 0);
    });

    test('gracefully handles zero or negative dimensions', () {
      final pt = service.normalizeCoordinates(
        localX: 100,
        localY: 100,
        viewportWidth: 0,
        viewportHeight: 0,
      );
      expect(pt.x, 0);
      expect(pt.y, 0);
    });
  });

  group('Touchpad 2-Finger Scrolling & Gestures', () {
    test(
        'vertical 2-finger scroll down creates natural swipe moving fingers up',
        () async {
      await service.sendScroll(
        serial: 'test-device',
        scrollDeltaY: 100.0,
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      expect(args[0], '-s');
      expect(args[1], 'test-device');
      expect(args.contains('swipe'), isTrue);

      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      // Natural scrolling: scrolling down swipes finger upwards (y1 > y2)
      expect(y1, greaterThan(y2));
    });

    test(
        'vertical 2-finger scroll up creates natural swipe moving fingers down',
        () async {
      await service.sendScroll(
        serial: 'test-device',
        scrollDeltaY: -100.0,
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      // Natural scrolling: scrolling up swipes finger downwards (y1 < y2)
      expect(y1, lessThan(y2));
    });

    test('horizontal 2-finger scroll right creates swipe moving fingers left',
        () async {
      await service.sendScroll(
        serial: 'test-device',
        scrollDeltaX: 100.0,
        scrollDeltaY: 0.0,
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final x1 = int.parse(args[swipeIdx + 1]);
      final x2 = int.parse(args[swipeIdx + 3]);

      // Natural scrolling: scrolling right swipes finger leftwards (x1 > x2)
      expect(x1, greaterThan(x2));
    });

    test('passes virtual display id (-d) to ADB swipe command', () async {
      await service.sendScroll(
        serial: 'test-device',
        displayId: 2,
        scrollDeltaY: 80.0,
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      expect(args.contains('-d'), isTrue);
      final dIdx = args.indexOf('-d');
      expect(args[dIdx + 1], '2');
    });

    test('does not pass -d when displayId is 0 (primary screen) or null',
        () async {
      await service.sendTap(
        serial: 'test-device',
        displayId: 0,
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      expect(args.contains('-d'), isFalse);
    });

    test(
        'small high-precision touchpad delta scales into healthy stroke (>160px)',
        () async {
      await service.sendScroll(
        serial: 'test-device',
        scrollDeltaY: 2.0, // typical small smooth touchpad scroll event
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      service.flushPendingScroll();

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      // Stroke length must be at least 160px to clear touch slop and produce fling
      final strokeLen = (y1 - y2).abs();
      expect(strokeLen, greaterThanOrEqualTo(160));
    });

    test('shifts swipe strokes near top border so stroke length is not clipped',
        () async {
      // Cursor is near top edge (localY = 5 in 800px window -> device Y ~ 15)
      await service.sendScroll(
        serial: 'test-device',
        scrollDeltaY: 100.0,
        localX: 200,
        localY: 5,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      // Stroke length must be healthy, not 0
      final strokeLen = (y1 - y2).abs();
      expect(strokeLen, greaterThanOrEqualTo(50));
      // Y coordinates must respect boundary margins
      expect(y2, greaterThanOrEqualTo(80));
    });

    test('trackpad PointerPanZoomUpdate dispatches natural 2-finger swipe',
        () async {
      service.onPointerPanZoomStart(
        serial: 'test-device',
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
      );

      // Pan fingers UP on trackpad (panDelta.dy < 0 in Flutter)
      service.onPointerPanZoomUpdate(
        serial: 'test-device',
        panDelta: const Offset(0, -60),
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
      );

      service.onPointerPanZoomEnd(
        serial: 'test-device',
        viewportWidth: 400,
        viewportHeight: 800,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      // Sliding fingers up swipes up on screen (y1 > y2)
      expect(y1, greaterThan(y2));
    });

    test('multi-touch: two fingers down on screen triggers two-finger scroll',
        () async {
      // Finger 1 down
      service.onPointerDown(pointerId: 1, localX: 180, localY: 400);
      // Finger 2 down (multi-touch active)
      service.onPointerDown(pointerId: 2, localX: 220, localY: 400);

      // Both fingers move UP on screen
      await service.onPointerMove(
        pointerId: 1,
        serial: 'test-device',
        currentX: 180,
        currentY: 340,
        viewportWidth: 400,
        viewportHeight: 800,
      );
      await service.onPointerMove(
        pointerId: 2,
        serial: 'test-device',
        currentX: 220,
        currentY: 340,
        viewportWidth: 400,
        viewportHeight: 800,
      );

      service.flushPendingScroll();

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      expect(y1, greaterThan(y2));
    });

    test(
        'inverted scrolling reverses swipe direction when naturalScrolling is false',
        () async {
      service.naturalScrolling = false;

      await service.sendScroll(
        serial: 'test-device',
        scrollDeltaY: 100.0,
        localX: 200,
        localY: 400,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, isNotEmpty);
      final args = adbCalls.first;
      final swipeIdx = args.indexOf('swipe');
      final y1 = int.parse(args[swipeIdx + 2]);
      final y2 = int.parse(args[swipeIdx + 4]);

      // With naturalScrolling=false, scroll down swipes downwards
      expect(y1, lessThan(y2));
    });
  });

  group('Single Pointer Tap and Drag integrity', () {
    test('single tap dispatches tap command at normalized coordinates',
        () async {
      await service.sendTap(
        serial: 'test-device',
        localX: 100,
        localY: 200,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, hasLength(1));
      expect(adbCalls.first, [
        '-s',
        'test-device',
        'shell',
        'input',
        'tap',
        '270',
        '600',
      ]);
    });

    test('single click without movement registers as a tap on pointer up',
        () async {
      service.onPointerDown(pointerId: 0, localX: 100, localY: 200);
      await service.onPointerUp(
        pointerId: 0,
        serial: 'test-device',
        endX: 101,
        endY: 201,
        viewportWidth: 400,
        viewportHeight: 800,
        deviceWidth: 1080,
        deviceHeight: 2400,
      );

      expect(adbCalls, hasLength(1));
      expect(adbCalls.first, [
        '-s',
        'test-device',
        'shell',
        'input',
        'tap',
        '273',
        '603',
      ]);
    });
  });
}
