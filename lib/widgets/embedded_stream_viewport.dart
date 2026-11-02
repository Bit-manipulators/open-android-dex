import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/dex_window.dart';
import '../services/adb_service.dart';
import '../services/scrcpy_stream_service.dart';
import '../services/texture_stream_channel.dart';
import '../services/touch_input_service.dart';

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

  ScrcpyDisplayMode _currentMode = ScrcpyDisplayMode.virtualDisplay;
  bool _isStreaming = false;
  bool _isAdapting = false;
  bool _cropStatusBar = true;
  bool _preserveAspect = true;
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
      final targetH = ((widget.window.height - 40).toInt() & ~1).clamp(360, 3840);
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
        _lastAdaptedHeight = (targetH + 40).toDouble();
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
      final adjY = _cropStatusBar ? (local.dy + 34.0) : local.dy;
      return Offset(local.dx, adjY);
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
    final effY = _cropStatusBar ? (normY * targetH + 34.0) : (normY * targetH);

    return Offset(normX * targetW, effY);
  }

  void _onPointerDown(PointerDownEvent e, BoxConstraints constraints) {
    setState(() => _lastTouchPos = e.localPosition);
    _touchFadeTimer?.cancel();
    _touchFadeTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _lastTouchPos = null);
    });

    final mapped = _mapLocalToVideo(e.localPosition, constraints);
    _touchInput.onPointerDown(
      localX: mapped.dx,
      localY: mapped.dy,
    );
  }

  void _onPointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    setState(() => _lastTouchPos = e.localPosition);
    final mapped = _mapLocalToVideo(e.localPosition, constraints);
    final topCrop = _cropStatusBar ? 34.0 : 0.0;
    final session = _streamService.getSession(widget.window.id);
    final devW = session?.targetWidth ?? widget.window.width.toInt();
    final devH = session?.targetHeight ?? widget.window.height.toInt();
    _touchInput.onPointerMove(
      serial: _adb.selectedDeviceSerial,
      currentX: mapped.dx,
      currentY: mapped.dy,
      viewportWidth: constraints.maxWidth,
      viewportHeight: constraints.maxHeight + topCrop,
      deviceWidth: devW,
      deviceHeight: devH,
    );
  }

  void _onPointerUp(PointerUpEvent e, BoxConstraints constraints) {
    final mapped = _mapLocalToVideo(e.localPosition, constraints);
    final topCrop = _cropStatusBar ? 34.0 : 0.0;
    final session = _streamService.getSession(widget.window.id);
    final devW = session?.targetWidth ?? widget.window.width.toInt();
    final devH = session?.targetHeight ?? widget.window.height.toInt();
    _touchInput.onPointerUp(
      serial: _adb.selectedDeviceSerial,
      endX: mapped.dx,
      endY: mapped.dy,
      viewportWidth: constraints.maxWidth,
      viewportHeight: constraints.maxHeight + topCrop,
      deviceWidth: devW,
      deviceHeight: devH,
    );
  }

  void _onPointerSignal(PointerSignalEvent e, BoxConstraints constraints) {
    if (e is PointerScrollEvent) {
      final mapped = _mapLocalToVideo(e.localPosition, constraints);
      final topCrop = _cropStatusBar ? 34.0 : 0.0;
      final session = _streamService.getSession(widget.window.id);
      final devW = session?.targetWidth ?? widget.window.width.toInt();
      final devH = session?.targetHeight ?? widget.window.height.toInt();
      _touchInput.sendScroll(
        serial: _adb.selectedDeviceSerial,
        scrollDeltaY: e.scrollDelta.dy,
        localX: mapped.dx,
        localY: mapped.dy,
        viewportWidth: constraints.maxWidth,
        viewportHeight: constraints.maxHeight + topCrop,
        deviceWidth: devW,
        deviceHeight: devH,
      );
    }
  }

  Widget _buildCroppedTexture() {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, c) {
          final topCrop = _cropStatusBar ? 34.0 : 0.0;
          return OverflowBox(
            alignment: Alignment.bottomCenter,
            minWidth: c.maxWidth,
            maxWidth: c.maxWidth,
            minHeight: c.maxHeight + topCrop,
            maxHeight: c.maxHeight + topCrop,
            child: Texture(textureId: _textureId!),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.window;

    return Container(
      color: const Color(0xFF090D14),
      child: Column(
        children: [
          // Stream Management Sub-header
          _buildToolbar(),

          // Main Interactive Surface Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Listener(
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
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: win.app.gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: win.app.gradientColors.first.withOpacity(0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(win.app.icon, size: 36, color: Colors.white),
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

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Mode Selector Pill
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF26334D)),
              ),
              child: Row(
                children: [
                  _buildModeTab('Virtual DeX', ScrcpyDisplayMode.virtualDisplay),
                  _buildModeTab('Mirror (Screen Off)', ScrcpyDisplayMode.mirrorPrimary),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Reconnect / Restart Stream
            Tooltip(
              message: 'Restart Video Stream',
              child: InkWell(
                onTap: _startStream,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF93C5FD)),
                      SizedBox(width: 4),
                      Text('Restart', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Clean Status Bar Crop Toggle
            Tooltip(
              message: _cropStatusBar ? 'Status Bar Hidden (Click to show)' : 'Status Bar Visible (Click to hide)',
              child: InkWell(
                onTap: () => setState(() => _cropStatusBar = !_cropStatusBar),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cropStatusBar ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _cropStatusBar ? const Color(0xFF3B82F6) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _cropStatusBar ? Icons.crop_free_rounded : Icons.crop_rounded,
                        size: 13,
                        color: _cropStatusBar ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _cropStatusBar ? 'Clean View' : 'Phone Bar',
                        style: TextStyle(
                          color: _cropStatusBar ? Colors.white : const Color(0xFFCBD5E1),
                          fontSize: 10,
                          fontWeight: _cropStatusBar ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Aspect Ratio Lock Toggle
            Tooltip(
              message: _preserveAspect ? 'Aspect Ratio Locked (No stretch)' : 'Stretched to Fit',
              child: InkWell(
                onTap: () => setState(() => _preserveAspect = !_preserveAspect),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _preserveAspect ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _preserveAspect ? const Color(0xFF10B981) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _preserveAspect ? Icons.aspect_ratio_rounded : Icons.fit_screen_rounded,
                        size: 13,
                        color: _preserveAspect ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _preserveAspect ? 'Fit Ratio' : 'Stretch',
                        style: TextStyle(
                          color: _preserveAspect ? Colors.white : const Color(0xFFCBD5E1),
                          fontSize: 10,
                          fontWeight: _preserveAspect ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Adapt Display Button (Re-renders Android UI into the new window shape)
            Tooltip(
              message: 'Adapt Android resolution to current window size',
              child: InkWell(
                onTap: _isAdapting ? null : () => _startStream(),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      _isAdapting
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF59E0B),
                              ),
                            )
                          : const Icon(Icons.transform_rounded, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        _isAdapting ? 'Adapting...' : 'Adapt Size',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Resolution Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Text(
                '${widget.window.width.toInt()}×${widget.window.height.toInt()}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, ScrcpyDisplayMode mode) {
    final isSelected = _currentMode == mode;
    return InkWell(
      onTap: () {
        if (_currentMode != mode) {
          setState(() => _currentMode = mode);
          _startStream();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          // Android Nav Buttons
          _buildNavIcon(Icons.arrow_back_ios_new_rounded, 'Back', () => _adb.goBack()),
          _buildNavIcon(Icons.circle_outlined, 'Home', () => _adb.goHome()),
          _buildNavIcon(Icons.crop_square_rounded, 'Recents', () => _adb.showRecents()),
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
                    _touchInput.sendText(_adb.selectedDeviceSerial, txt);
                    _adb.sendKeyEvent(66); // Enter
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
                _touchInput.sendText(_adb.selectedDeviceSerial, txt);
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

