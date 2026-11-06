import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

typedef AdbRunner = Future<ProcessResult> Function(List<String> args);

/// Service responsible for mapping user gestures, touchpad interactions,
/// two-finger scrolling, and keyboard input from the desktop viewport to Android.
class TouchInputService {
  static final TouchInputService _instance = TouchInputService._internal();
  factory TouchInputService() => _instance;
  TouchInputService._internal();

  /// Pluggable ADB command runner for tests and custom dispatchers.
  AdbRunner adbRunner = (args) => Process.run('adb', args);

  /// Multiplier to tune two-finger touchpad scrolling responsiveness.
  double scrollSensitivity = 8.0;

  /// Whether two-finger scroll behaves naturally (content moves in finger direction).
  bool naturalScrolling = true;

  // Single-pointer drag state
  DateTime _lastMoveTime = DateTime.now();
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;

  // Multi-pointer / Touchscreen 2-finger gesture state
  final Map<int, Offset> _activePointers = {};
  Offset? _lastTwoFingerCentroid;
  bool _isMultiTouchScrollActive = false;

  // Trackpad / Touchpad PanZoom state
  bool _isPanZoomActive = false;
  bool get isPanZoomActive => _isPanZoomActive;
  bool get isMultiTouchScrollActive => _isMultiTouchScrollActive;

  // Two-finger scroll accumulator & queue
  double _accumulatedScrollX = 0.0;
  double _accumulatedScrollY = 0.0;
  Offset _scrollAnchor = Offset.zero;
  bool _isDispatchingScroll = false;
  Timer? _scrollFlushTimer;

  String? _activeScrollSerial;
  int? _activeScrollDisplayId;
  double _activeViewportWidth = 1.0;
  double _activeViewportHeight = 1.0;
  int _activeDeviceWidth = 1080;
  int _activeDeviceHeight = 2400;

  /// Resets internal gesture state (useful for tests and window detachment).
  void reset() {
    _activePointers.clear();
    _lastTwoFingerCentroid = null;
    _isMultiTouchScrollActive = false;
    _isPanZoomActive = false;
    _isDragging = false;
    _dragStartX = 0;
    _dragStartY = 0;
    _accumulatedScrollX = 0.0;
    _accumulatedScrollY = 0.0;
    _isDispatchingScroll = false;
    _scrollFlushTimer?.cancel();
    _scrollFlushTimer = null;
  }

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
      await adbRunner(args);
    } catch (e) {
      debugPrint('Error sending tap: $e');
    }
  }

  /// Marks the start of a touch/drag gesture. Supports multi-finger detection.
  void onPointerDown({
    int pointerId = 0,
    required double localX,
    required double localY,
  }) {
    _activePointers[pointerId] = Offset(localX, localY);

    if (_activePointers.length >= 2) {
      // 2 or more fingers on screen: transition into two-finger scroll
      _isDragging = false;
      _isMultiTouchScrollActive = true;
      final pts = _activePointers.values.take(2).toList();
      _lastTwoFingerCentroid = (pts[0] + pts[1]) / 2.0;
      return;
    }

    _isDragging = true;
    _isMultiTouchScrollActive = false;
    _dragStartX = localX;
    _dragStartY = localY;
  }

  /// Handles drag movement or multi-touch two-finger scroll.
  Future<void> onPointerMove({
    int pointerId = 0,
    required String? serial,
    int? displayId,
    required double currentX,
    required double currentY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    if (serial == null) return;
    _activePointers[pointerId] = Offset(currentX, currentY);

    // If 2 fingers are touching, handle as a two-finger scroll gesture
    if (_activePointers.length >= 2) {
      final pts = _activePointers.values.take(2).toList();
      final currentCentroid = (pts[0] + pts[1]) / 2.0;
      if (_lastTwoFingerCentroid != null) {
        final centroidDelta = currentCentroid - _lastTwoFingerCentroid!;
        // Screen drag: moving fingers up (dy < 0) corresponds to natural swipe up
        final deltaX = -centroidDelta.dx;
        final deltaY = -centroidDelta.dy;
        handleTwoFingerScroll(
          serial: serial,
          displayId: displayId,
          deltaX: deltaX,
          deltaY: deltaY,
          localX: currentCentroid.dx,
          localY: currentCentroid.dy,
          viewportWidth: viewportWidth,
          viewportHeight: viewportHeight,
          deviceWidth: deviceWidth,
          deviceHeight: deviceHeight,
        );
      }
      _lastTwoFingerCentroid = currentCentroid;
      return;
    }

    if (!_isDragging) return;

    final now = DateTime.now();
    if (now.difference(_lastMoveTime).inMilliseconds < 120) {
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
        '100',
      ]);
      await adbRunner(args);
    } catch (e) {
      debugPrint('Error sending drag/swipe: $e');
    }
  }

  /// Concludes a pointer gesture.
  Future<void> onPointerUp({
    int pointerId = 0,
    required String? serial,
    int? displayId,
    required double endX,
    required double endY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    _activePointers.remove(pointerId);

    if (_isMultiTouchScrollActive) {
      if (_activePointers.length < 2) {
        _isMultiTouchScrollActive = false;
        _lastTwoFingerCentroid = null;
        flushPendingScroll();
      }
      return;
    }

    if (!_isDragging) return;
    _isDragging = false;

    final dx = (endX - _dragStartX).abs();
    final dy = (endY - _dragStartY).abs();

    if (dx < 6 && dy < 6) {
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
        await adbRunner(args);
      } catch (e) {
        debugPrint('Error sending final swipe: $e');
      }
    }
  }

  /// Handles pointer cancel events.
  void onPointerCancel({int pointerId = 0}) {
    _activePointers.remove(pointerId);
    if (_activePointers.length < 2) {
      _isMultiTouchScrollActive = false;
      _lastTwoFingerCentroid = null;
    }
    _isDragging = false;
  }

  // =========================================================================
  // Trackpad / Touchpad Native Pan-Zoom Gestures
  // =========================================================================

  /// Called when a trackpad two-finger pan/zoom gesture begins.
  void onPointerPanZoomStart({
    required String? serial,
    int? displayId,
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) {
    _isPanZoomActive = true;
    _activeScrollSerial = serial;
    _activeScrollDisplayId = displayId;
    _scrollAnchor = Offset(localX, localY);
    _activeViewportWidth = viewportWidth > 0 ? viewportWidth : 1.0;
    _activeViewportHeight = viewportHeight > 0 ? viewportHeight : 1.0;
    _activeDeviceWidth = deviceWidth > 0 ? deviceWidth : 1080;
    _activeDeviceHeight = deviceHeight > 0 ? deviceHeight : 2400;
  }

  /// Called when a trackpad two-finger pan/zoom gesture updates.
  void onPointerPanZoomUpdate({
    required String? serial,
    int? displayId,
    required Offset panDelta,
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) {
    if (serial == null) return;
    _isPanZoomActive = true;

    // Moving fingers UP has panDelta.dy < 0.
    // In natural scrolling, sliding fingers up scrolls content down.
    final double dx = naturalScrolling ? -panDelta.dx : panDelta.dx;
    final double dy = naturalScrolling ? -panDelta.dy : panDelta.dy;

    handleTwoFingerScroll(
      serial: serial,
      displayId: displayId,
      deltaX: dx,
      deltaY: dy,
      localX: localX,
      localY: localY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );
  }

  /// Called when a trackpad two-finger pan/zoom gesture ends.
  void onPointerPanZoomEnd({
    required String? serial,
    int? displayId,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) {
    _isPanZoomActive = false;
    flushPendingScroll();
  }

  // =========================================================================
  // Unified 2-Finger Touchpad & Mouse Scroll Engine
  // =========================================================================

  /// Sends a scroll wheel / touchpad event (supporting 2D vertical & horizontal scroll).
  Future<void> sendScroll({
    required String? serial,
    int? displayId,
    double scrollDeltaX = 0.0,
    required double scrollDeltaY,
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) async {
    if (serial == null) return;

    final double dx = naturalScrolling ? scrollDeltaX : -scrollDeltaX;
    final double dy = naturalScrolling ? scrollDeltaY : -scrollDeltaY;

    handleTwoFingerScroll(
      serial: serial,
      displayId: displayId,
      deltaX: dx,
      deltaY: dy,
      localX: localX,
      localY: localY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );
  }

  /// Accumulates two-finger scroll delta and dispatches throttled swipe gestures to Android.
  void handleTwoFingerScroll({
    required String? serial,
    int? displayId,
    required double deltaX,
    required double deltaY,
    required double localX,
    required double localY,
    required double viewportWidth,
    required double viewportHeight,
    int deviceWidth = 1080,
    int deviceHeight = 2400,
  }) {
    if (serial == null) return;

    _activeScrollSerial = serial;
    _activeScrollDisplayId = displayId;
    _activeViewportWidth = viewportWidth > 0 ? viewportWidth : 1.0;
    _activeViewportHeight = viewportHeight > 0 ? viewportHeight : 1.0;
    _activeDeviceWidth = deviceWidth > 0 ? deviceWidth : 1080;
    _activeDeviceHeight = deviceHeight > 0 ? deviceHeight : 2400;
    _scrollAnchor = Offset(localX, localY);

    _accumulatedScrollX += deltaX * scrollSensitivity;
    _accumulatedScrollY += deltaY * scrollSensitivity;

    // Reset trailing flush timer
    _scrollFlushTimer?.cancel();
    _scrollFlushTimer = Timer(const Duration(milliseconds: 50), () {
      _dispatchScrollQueue();
    });

    // Check if accumulated distance warrants immediate swipe dispatch
    final scaleX = _activeDeviceWidth / _activeViewportWidth;
    final scaleY = _activeDeviceHeight / _activeViewportHeight;
    final devDeltaX = _accumulatedScrollX * scaleX;
    final devDeltaY = _accumulatedScrollY * scaleY;
    final totalDevDist = math.sqrt(devDeltaX * devDeltaX + devDeltaY * devDeltaY);

    if (totalDevDist >= 15.0 && !_isDispatchingScroll) {
      _dispatchScrollQueue();
    }
  }

  /// Flushes any pending accumulated scroll distance immediately.
  void flushPendingScroll() {
    _scrollFlushTimer?.cancel();
    if (!_isDispatchingScroll) {
      _dispatchScrollQueue();
    }
  }

  /// Drain accumulated scroll deltas into ADB swipe commands one at a time.
  Future<void> _dispatchScrollQueue() async {
    if (_isDispatchingScroll) return;
    _isDispatchingScroll = true;

    try {
      while (true) {
        final serial = _activeScrollSerial;
        if (serial == null) break;

        final scaleX = _activeDeviceWidth / _activeViewportWidth;
        final scaleY = _activeDeviceHeight / _activeViewportHeight;

        final devDeltaX = _accumulatedScrollX * scaleX;
        final devDeltaY = _accumulatedScrollY * scaleY;
        final rawDist = math.sqrt(devDeltaX * devDeltaX + devDeltaY * devDeltaY);

        if (rawDist < 1.0) {
          break;
        }

        // Consume all of the current accumulated delta
        _accumulatedScrollX = 0.0;
        _accumulatedScrollY = 0.0;

        // Scale stroke distance so even small touchpad movements comfortably overcome
        // Android's touch slop (~24-48px) and produce natural momentum/fling
        final strokeDist = (rawDist * 4.0).clamp(180.0, 850.0);

        final anchor = normalizeCoordinates(
          localX: _scrollAnchor.dx,
          localY: _scrollAnchor.dy,
          viewportWidth: _activeViewportWidth,
          viewportHeight: _activeViewportHeight,
          deviceWidth: _activeDeviceWidth,
          deviceHeight: _activeDeviceHeight,
        );

        // Vector: swipe opposite to scroll direction
        // deltaY > 0 (scroll down) -> swipe fingers UP (strokeVy < 0)
        double strokeVx = -(devDeltaX / rawDist) * strokeDist;
        double strokeVy = -(devDeltaY / rawDist) * strokeDist;

        // Center stroke around cursor anchor
        double startX = anchor.x - (strokeVx / 2.0);
        double startY = anchor.y - (strokeVy / 2.0);
        double endX = anchor.x + (strokeVx / 2.0);
        double endY = anchor.y + (strokeVy / 2.0);

        // Boundary margins to avoid status bar and gesture navigation pill
        const minX = 40.0;
        final maxX = _activeDeviceWidth - 40.0;
        const minY = 80.0;
        final maxY = _activeDeviceHeight - 80.0;

        // Shift stroke if it intersects screen edges so stroke length is not lost
        final minStrokeX = math.min(startX, endX);
        final maxStrokeX = math.max(startX, endX);
        if (minStrokeX < minX) {
          final shift = minX - minStrokeX;
          startX += shift;
          endX += shift;
        } else if (maxStrokeX > maxX) {
          final shift = maxX - maxStrokeX;
          startX -= shift;
          endX -= shift;
        }

        final minStrokeY = math.min(startY, endY);
        final maxStrokeY = math.max(startY, endY);
        if (minStrokeY < minY) {
          final shift = minY - minStrokeY;
          startY += shift;
          endY += shift;
        } else if (maxStrokeY > maxY) {
          final shift = maxStrokeY - maxY;
          startY -= shift;
          endY -= shift;
        }

        startX = startX.clamp(minX, maxX);
        endX = endX.clamp(minX, maxX);
        startY = startY.clamp(minY, maxY);
        endY = endY.clamp(minY, maxY);

        final effectiveLen = math.sqrt(
          (endX - startX) * (endX - startX) + (endY - startY) * (endY - startY),
        );
        if (effectiveLen < 15.0) {
          break;
        }

        // Adaptive duration: 75ms - 130ms for natural fling velocity
        final durationMs = (effectiveLen * 0.18).clamp(75.0, 130.0).round();

        final args = ['-s', serial, 'shell', 'input'];
        if (_activeScrollDisplayId != null) {
          args.addAll(['-d', _activeScrollDisplayId.toString()]);
        }
        args.addAll([
          'swipe',
          startX.round().toString(),
          startY.round().toString(),
          endX.round().toString(),
          endY.round().toString(),
          durationMs.toString(),
        ]);

        try {
          await adbRunner(args);
        } catch (e) {
          debugPrint('Error sending scroll swipe: $e');
        }
      }
    } finally {
      _isDispatchingScroll = false;
    }
  }

  // =========================================================================
  // Text & Keyboard Events
  // =========================================================================

  /// Injects text into the focused Android text box.
  Future<void> sendText(String? serial, String text, {int? displayId}) async {
    if (serial == null || text.isEmpty) return;

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
      await adbRunner(args);
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
      await adbRunner(args);
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
