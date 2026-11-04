import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service responsible for mapping user gestures and mouse interactions
/// from the Flutter desktop viewport to the Android device.
class TouchInputService {
  static final TouchInputService _instance = TouchInputService._internal();
  factory TouchInputService() => _instance;
  TouchInputService._internal();

  DateTime _lastMoveTime = DateTime.now();
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;

  /// Translates viewport coordinates to device coordinates.
  Point<int> normalizeCoordinates({
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) {
    if (viewportWidth <= 0 || viewportHeight <= 0) {
      return const Point(0, 0);
    }

    final double clampedX = localX.clamp(0.0, viewportWidth);
    final double clampedY = localY.clamp(0.0, viewportHeight);

    final int targetX = ((clampedX / viewportWidth) * deviceWidth).round();
    final int targetY = ((clampedY / viewportHeight) * deviceHeight).round();

    return Point(targetX, targetY);
  }

  /// Sends a single tap event to the Android device.
  Future<void> sendTap({
    required String? serial,
    int? displayId,
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    if (serial == null) return;

    final target = normalizeCoordinates(
      localX: localX,
      localY: localY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );

    try {
      final args = ['-s', serial, 'shell', 'input'];
      if (displayId != null) {
        args.addAll(['-d', displayId.toString()]);
      }
      args.addAll(['tap', target.x.toString(), target.y.toString()]);
      await Process.run('adb', args);
    } catch (e) {
      debugPrint('Error sending tap: $e');
    }
  }

  /// Marks the start of a touch/drag gesture.
  void onPointerDown({
    required double localX,
    required double localY,
  }) {
    _isDragging = true;
    _dragStartX = localX;
    _dragStartY = localY;
  }

  /// Handles drag / swipe movement with throttling to prevent ADB queue saturation.
  Future<void> onPointerMove({
    required String? serial,
    int? displayId,
    required double currentX,
    required double currentY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    if (serial == null || !_isDragging) return;

    final now = DateTime.now();
    if (now.difference(_lastMoveTime).inMilliseconds < 120) {
      // Throttle intermediate drag events
      return;
    }
    _lastMoveTime = now;

    final start = normalizeCoordinates(
      localX: _dragStartX,
      localY: _dragStartY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );

    final end = normalizeCoordinates(
      localX: currentX,
      localY: currentY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );

    // Update start point for incremental swipe chaining
    _dragStartX = currentX;
    _dragStartY = currentY;

    try {
      final args = ['-s', serial, 'shell', 'input'];
      if (displayId != null) {
        args.addAll(['-d', displayId.toString()]);
      }
      args.addAll([
        'swipe',
        start.x.toString(),
        start.y.toString(),
        end.x.toString(),
        end.y.toString(),
        '100', // swipe duration in ms
      ]);
      await Process.run('adb', args);
    } catch (e) {
      debugPrint('Error sending drag/swipe: $e');
    }
  }

  /// Concludes a drag gesture.
  Future<void> onPointerUp({
    required String? serial,
    int? displayId,
    required double endX,
    required double endY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    if (!_isDragging) return;
    _isDragging = false;

    final dx = (endX - _dragStartX).abs();
    final dy = (endY - _dragStartY).abs();

    if (dx < 6 && dy < 6) {
      // If minimal movement, register as a clean tap
      await sendTap(
        serial: serial,
        displayId: displayId,
        localX: endX,
        localY: endY,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        deviceWidth: deviceWidth,
        deviceHeight: deviceHeight,
      );
    } else {
      final start = normalizeCoordinates(
        localX: _dragStartX,
        localY: _dragStartY,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        deviceWidth: deviceWidth,
        deviceHeight: deviceHeight,
      );

      final end = normalizeCoordinates(
        localX: endX,
        localY: endY,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        deviceWidth: deviceWidth,
        deviceHeight: deviceHeight,
      );

      try {
        final args = ['-s', serial!, 'shell', 'input'];
        if (displayId != null) {
          args.addAll(['-d', displayId.toString()]);
        }
        args.addAll([
          'swipe',
          start.x.toString(),
          start.y.toString(),
          end.x.toString(),
          end.y.toString(),
          '150',
        ]);
        await Process.run('adb', args);
      } catch (e) {
        debugPrint('Error sending final swipe: $e');
      }
    }
  }

  /// Sends a scroll wheel event (page up / page down / roll).
  Future<void> sendScroll({
    required String? serial,
    int? displayId,
    required double scrollDeltaY,
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    if (serial == null) return;

    final center = normalizeCoordinates(
      localX: localX,
      localY: localY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );

    final int scrollDistance = (scrollDeltaY * 4).round();
    final int startY = center.y;
    final int endY = (center.y - scrollDistance).clamp(50, deviceHeight - 50);

    try {
      final args = ['-s', serial, 'shell', 'input'];
      if (displayId != null) {
        args.addAll(['-d', displayId.toString()]);
      }
      args.addAll([
        'swipe',
        center.x.toString(),
        startY.toString(),
        center.x.toString(),
        endY.toString(),
        '100',
      ]);
      await Process.run('adb', args);
    } catch (e) {
      debugPrint('Error sending scroll swipe: $e');
    }
  }

  /// Injects text into the focused Android text box.
  Future<void> sendText(String? serial, String text, {int? displayId}) async {
    if (serial == null || text.isEmpty) return;

    // Replace whitespace and escape shell characters for adb input text
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll(' ', '%s')
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'")
        .replaceAll('&', r'\&')
        .replaceAll('<', r'\<')
        .replaceAll('>', r'\>')
        .replaceAll('|', r'\|')
        .replaceAll(';', r'\;')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`');
    try {
      final args = ['-s', serial, 'shell', 'input'];
      if (displayId != null) {
        args.addAll(['-d', displayId.toString()]);
      }
      args.addAll(['text', escaped]);
      await Process.run('adb', args);
    } catch (e) {
      debugPrint('Error sending text: $e');
    }
  }

  /// Sends a hardware key event (Enter, Backspace, Arrows, etc.) to the device/display.
  Future<void> sendKeyEvent(String? serial, int keyCode,
      {int? displayId}) async {
    if (serial == null) return;
    try {
      final args = ['-s', serial, 'shell', 'input'];
      if (displayId != null) {
        args.addAll(['-d', displayId.toString()]);
      }
      args.addAll(['keyevent', keyCode.toString()]);
      await Process.run('adb', args);
    } catch (e) {
      debugPrint('Error sending keyevent: $e');
    }
  }
}

class Point<T extends num> {
  final T x;
  final T y;
  const Point(this.x, this.y);
}
