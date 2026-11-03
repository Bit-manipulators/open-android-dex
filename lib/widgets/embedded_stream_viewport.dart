import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dex_window.dart';
import '../services/adb_service.dart';
import '../services/scrcpy_stream_service.dart';
import '../services/texture_stream_channel.dart';
import '../services/touch_input_service.dart';
import 'app_icon_widget.dart';

/// Embedded viewport widget that renders the live interactive screen area
/// for an Android application inside a resizable desktop window.
class EmbeddedStreamViewport extends StatefulWidget {
  final DexWindow window;
  final Size desktopSize;

  const EmbeddedStreamViewport({
    super.key,
    required this.window,
    required this.desktopSize,
  });

  @override
  State<EmbeddedStreamViewport> createState() => _EmbeddedStreamViewportState();
}

class _EmbeddedStreamViewportState extends State<EmbeddedStreamViewport> {
  final _touchInput = TouchInputService();
  final _streamService = ScrcpyStreamService();
  final _adb = AdbService();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  final ScrcpyDisplayMode _currentMode = ScrcpyDisplayMode.virtualDisplay;
  bool _isStreaming = false;
  bool _isAdapting = false;
  static const bool _preserveAspect = true;
  double _streamAspect = 16 / 10;
  String _statusMessage = 'Connecting stream...';
  int? _textureId;

  // Pointer touch feedback animation
  Offset? _lastTouchPos;
  Timer? _touchFadeTimer;
  Timer? _resizeDebounceTimer;
  double? _lastAdaptedWidth;
  double? _lastAdaptedHeight;

  StreamSubscription? _sessionSub;
  StreamSubscription? _deviceSub;

  @override
  void initState() {
    super.initState();
    _lastAdaptedWidth = widget.window.width;
    _lastAdaptedHeight = widget.window.height;
    _startStream();

    _deviceSub = _adb.onDeviceStateChanged.listen((connected) {
      if (connected && !_isStreaming && mounted) {
        _startStream();
      }
    });

    _sessionSub = _streamService.onSessionStateChanged.listen((session) {
      if (session.id == widget.window.id && mounted) {
        setState(() {
          _isStreaming = session.isRunning;
          _statusMessage = session.isRunning
              ? (_currentMode == ScrcpyDisplayMode.virtualDisplay
                  ? 'Virtual Display Active'
                  : 'Phone Screen Mirrored (Off)')
              : 'Stream Disconnected';
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant EmbeddedStreamViewport oldWidget) {
    super.didUpdateWidget(oldWidget);

    final widthDiff = ((widget.window.width) - (_lastAdaptedWidth ?? widget.window.width)).abs();
    final heightDiff = ((widget.window.height) - (_lastAdaptedHeight ?? widget.window.height)).abs();
    final maximizeChanged = widget.window.isMaximized != oldWidget.window.isMaximized;

    if (maximizeChanged || widthDiff > 20 || heightDiff > 20) {
      // Automatically adapt Android virtual display resolution to the new window shape.
      // While dragging, the video scales smoothly. 450ms after the user releases or pauses
      // resizing, the virtual display resolution automatically re-renders without needing
      // to manually click "Adapt Size"!
      _resizeDebounceTimer?.cancel();
      _resizeDebounceTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) {
          _startStream();
        }
      });
    }
  }

  @override
  void dispose() {
    _touchFadeTimer?.cancel();
    _resizeDebounceTimer?.cancel();
    _sessionSub?.cancel();
    _deviceSub?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    if (_textureId != null) {
      TextureStreamChannel.stopStream(_textureId!);
    }
    _streamService.stopSession(widget.window.id);
    _streamService.cleanupPipe(widget.window.id);
    super.dispose();
  }

  Future<void> _startStream() async {
    if (_isAdapting) return;
    _isAdapting = true;
    if (mounted) setState(() {});

    try {
      if (_adb.isDemoMode) {
        if (mounted) {
          setState(() {
            _isStreaming = true;
            _statusMessage = 'Demo Simulation Active';
            _isAdapting = false;
          });
        }
        return;
      }

      final serial = _adb.selectedDeviceSerial;
      if (serial == null) {
        if (mounted) {
          setState(() {
            _isStreaming = false;
            _statusMessage = 'No ADB device connected';
            _isAdapting = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Adapting resolution...';
        });
      }

      final targetW = (widget.window.width.toInt() & ~1).clamp(360, 3840);
      final targetH = ((widget.window.height - 80).toInt() & ~1).clamp(360, 3840);
      _streamAspect = targetW / targetH;

      final oldTexId = _textureId;

      // 1. Start or restart headless scrcpy session with graceful handshake
      final session = await _streamService.startSession(
        windowId: widget.window.id,
        packageName: widget.window.app.packageName,
        serial: serial,
        mode: _currentMode,
        width: targetW,
        height: targetH,
        dpi: 240,
      );

      // 2. Request native texture registration for the video stream
      int? texId;
      if (session != null) {
        texId = await TextureStreamChannel.startStream(
          path: session.pipePath,
          width: targetW,
          height: targetH,
        );
      }

      // 3. Stop old texture stream after new texture is created
      if (oldTexId != null && oldTexId != texId) {
        TextureStreamChannel.stopStream(oldTexId);
      }

      if (mounted) {
        _lastAdaptedWidth = targetW.toDouble();
        _lastAdaptedHeight = (targetH + 80).toDouble();
        setState(() {
          _textureId = texId;
          _isStreaming = session?.isRunning ?? false;
          _statusMessage = _isStreaming
              ? (_currentMode == ScrcpyDisplayMode.virtualDisplay
                  ? 'Virtual Display Active'
                  : 'Phone Screen Mirrored')
              : 'Connecting stream...';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdapting = false;
        });
      }
    }
  }

  Offset _mapLocalToVideo(Offset local, BoxConstraints constraints) {
    if (!_preserveAspect) {
      return local;
    }

    final boxW = constraints.maxWidth;
    final boxH = constraints.maxHeight;
    final boxAspect = boxW / boxH;

    double renderW, renderH, padX, padY;
    if (boxAspect > _streamAspect) {
      renderH = boxH;
      renderW = renderH * _streamAspect;
      padX = (boxW - renderW) / 2;
      padY = 0;
    } else {
      renderW = boxW;
      renderH = renderW / _streamAspect;
      padX = 0;
      padY = (boxH - renderH) / 2;
    }

    final clampedX = (local.dx - padX).clamp(0.0, renderW);
    final clampedY = (local.dy - padY).clamp(0.0, renderH);

    final normX = renderW > 0 ? (clampedX / renderW) : 0.0;
    final normY = renderH > 0 ? (clampedY / renderH) : 0.0;

    final targetW = constraints.maxWidth;
    final targetH = constraints.maxHeight;

    return Offset(normX * targetW, normY * targetH);
  }

  void _onPointerDown(PointerDownEvent e, BoxConstraints constraints) {
    _focusNode.requestFocus();
    setState(() => _lastTouchPos = e.localPosition);
    _touchFadeTimer?.cancel();
    _touchFadeTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _lastTouchPos = null);
    });

    final mapped = _mapLocalToVideo(e.localPosition, constraints);
    if (_adb.isDemoMode) return;
    _touchInput.onPointerDown(
      localX: mapped.dx,
      localY: mapped.dy,
    );
  }

  void _onPointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    setState(() => _lastTouchPos = e.localPosition);
    if (_adb.isDemoMode) return;
    final mapped = _mapLocalToVideo(e.localPosition, constraints);
    final session = _streamService.getSession(widget.window.id);
    final devW = session?.targetWidth ?? widget.window.width.toInt();
    final devH = session?.targetHeight ?? widget.window.height.toInt();
    _touchInput.onPointerMove(
      serial: _adb.selectedDeviceSerial,
      displayId: session?.displayId,
      currentX: mapped.dx,
      currentY: mapped.dy,
      viewportWidth: constraints.maxWidth,
      viewportHeight: constraints.maxHeight,
      deviceWidth: devW,
      deviceHeight: devH,
    );
  }

  void _onPointerUp(PointerUpEvent e, BoxConstraints constraints) {
    if (_adb.isDemoMode) return;
    final mapped = _mapLocalToVideo(e.localPosition, constraints);
    final session = _streamService.getSession(widget.window.id);
    final devW = session?.targetWidth ?? widget.window.width.toInt();
    final devH = session?.targetHeight ?? widget.window.height.toInt();
    _touchInput.onPointerUp(
      serial: _adb.selectedDeviceSerial,
      displayId: session?.displayId,
      endX: mapped.dx,
      endY: mapped.dy,
      viewportWidth: constraints.maxWidth,
      viewportHeight: constraints.maxHeight,
      deviceWidth: devW,
      deviceHeight: devH,
    );
  }

  void _onPointerSignal(PointerSignalEvent e, BoxConstraints constraints) {
    if (e is PointerScrollEvent) {
      final mapped = _mapLocalToVideo(e.localPosition, constraints);
      final session = _streamService.getSession(widget.window.id);
      final devW = session?.targetWidth ?? widget.window.width.toInt();
      final devH = session?.targetHeight ?? widget.window.height.toInt();
      _touchInput.sendScroll(
        serial: _adb.selectedDeviceSerial,
        displayId: session?.displayId,
        scrollDeltaY: e.scrollDelta.dy,
        localX: mapped.dx,
        localY: mapped.dy,
        viewportWidth: constraints.maxWidth,
        viewportHeight: constraints.maxHeight,
        deviceWidth: devW,
        deviceHeight: devH,
      );
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_adb.isDemoMode) {
      return KeyEventResult.handled;
    }

    final serial = _adb.selectedDeviceSerial;
    if (serial == null) return KeyEventResult.ignored;

    final session = _streamService.getSession(widget.window.id);
    final displayId = session?.displayId;

    final key = event.logicalKey;

    // Check functional and navigation keys
    int? keyCode;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      keyCode = 66; // KEYCODE_ENTER
    } else if (key == LogicalKeyboardKey.backspace) {
      keyCode = 67; // KEYCODE_DEL
    } else if (key == LogicalKeyboardKey.delete) {
      keyCode = 112; // KEYCODE_FORWARD_DEL
    } else if (key == LogicalKeyboardKey.tab) {
      keyCode = 61; // KEYCODE_TAB
    } else if (key == LogicalKeyboardKey.space) {
      keyCode = 62; // KEYCODE_SPACE
    } else if (key == LogicalKeyboardKey.escape) {
      keyCode = 111; // KEYCODE_ESCAPE
    } else if (key == LogicalKeyboardKey.arrowUp) {
      keyCode = 19; // KEYCODE_DPAD_UP
    } else if (key == LogicalKeyboardKey.arrowDown) {
      keyCode = 20; // KEYCODE_DPAD_DOWN
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      keyCode = 21; // KEYCODE_DPAD_LEFT
    } else if (key == LogicalKeyboardKey.arrowRight) {
      keyCode = 22; // KEYCODE_DPAD_RIGHT
    } else if (key == LogicalKeyboardKey.pageUp) {
      keyCode = 92; // KEYCODE_PAGE_UP
    } else if (key == LogicalKeyboardKey.pageDown) {
      keyCode = 93; // KEYCODE_PAGE_DOWN
    } else if (key == LogicalKeyboardKey.home) {
      keyCode = 122; // KEYCODE_MOVE_HOME
    } else if (key == LogicalKeyboardKey.end) {
      keyCode = 123; // KEYCODE_MOVE_END
    }

    if (keyCode != null) {
      _touchInput.sendKeyEvent(serial, keyCode, displayId: displayId);
      return KeyEventResult.handled;
    }

    // Direct printable character input
    if (event.character != null && event.character!.isNotEmpty) {
      _touchInput.sendText(serial, event.character!, displayId: displayId);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildCroppedTexture() {
    return Texture(textureId: _textureId!);
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.window;

    return Container(
      color: const Color(0xFF090D14),
      child: Column(
        children: [
          // Main Interactive Surface Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) => _handleKeyEvent(event),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onPointerDown(e, constraints),
                    onPointerMove: (e) => _onPointerMove(e, constraints),
                    onPointerUp: (e) => _onPointerUp(e, constraints),
                    onPointerSignal: (e) => _onPointerSignal(e, constraints),
                    child: Stack(
                      children: [
                        // Viewport Canvas: Clean Cropped Live Texture or Connecting Indicator
                        if (_textureId != null)
                          Positioned.fill(
                            child: Center(
                              child: _preserveAspect
                                  ? AspectRatio(
                                      aspectRatio: _streamAspect,
                                      child: _buildCroppedTexture(),
                                    )
                                  : _buildCroppedTexture(),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF0F172A),
                                  win.app.gradientColors.first.withOpacity(0.15),
                                  const Color(0xFF080C14),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppIconWidget(
                                    app: win.app,
                                    size: 72,
                                    borderRadius: 18,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    win.app.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isStreaming ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _statusMessage,
                                        style: TextStyle(
                                          color: _isStreaming ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Connecting live screen engine...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Touch feedback ripple visual
                        if (_lastTouchPos != null)
                          Positioned(
                            left: _lastTouchPos!.dx - 18,
                            top: _lastTouchPos!.dy - 18,
                            child: IgnorePointer(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF38BDF8).withOpacity(0.25),
                                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Quick Navigation & Text Injection Bar
          _buildBottomControlBar(),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar() {
    final session = _streamService.getSession(widget.window.id);
    final displayId = session?.displayId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          // Android Nav Buttons
          _buildNavIcon(Icons.arrow_back_ios_new_rounded, 'Back', () => _adb.goBack(displayId: displayId)),
          _buildNavIcon(Icons.circle_outlined, 'Home', () => _adb.goHome(displayId: displayId)),
          _buildNavIcon(Icons.crop_square_rounded, 'Recents', () => _adb.showRecents(displayId: displayId)),
          const SizedBox(width: 8),

          // Text injection field
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Type text onto device...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  filled: true,
                  fillColor: const Color(0xFF0B111E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                ),
                onSubmitted: (txt) {
                  if (txt.isNotEmpty) {
                    _touchInput.sendText(_adb.selectedDeviceSerial, txt, displayId: displayId);
                    _touchInput.sendKeyEvent(_adb.selectedDeviceSerial, 66, displayId: displayId); // Enter
                    _textController.clear();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Send Button
          InkWell(
            onTap: () {
              final txt = _textController.text.trim();
              if (txt.isNotEmpty) {
                _touchInput.sendText(_adb.selectedDeviceSerial, txt, displayId: displayId);
                _textController.clear();
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.send_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

