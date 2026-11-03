import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/window_manager_controller.dart';
import '../models/dex_window.dart';
import '../services/adb_service.dart';
import 'app_icon_widget.dart';
import 'embedded_stream_viewport.dart';

class ResizableWindowFrame extends StatefulWidget {
  final DexWindow window;
  final WindowManagerController controller;
  final Size desktopSize;

  const ResizableWindowFrame({
    super.key,
    required this.window,
    required this.controller,
    required this.desktopSize,
  });

  @override
  State<ResizableWindowFrame> createState() => _ResizableWindowFrameState();
}

class _ResizableWindowFrameState extends State<ResizableWindowFrame> {
  bool _showSnapFlyout = false;

  @override
  Widget build(BuildContext context) {
    final win = widget.window;
    final isActive = widget.controller.activeWindowId == win.id;
    const handleSize = 8.0;

    return Positioned(
      left: win.x,
      top: win.y,
      width: win.width,
      height: win.height,
      child: Listener(
        onPointerDown: (_) => widget.controller.bringToFront(win.id),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14171F),
            borderRadius: win.isMaximized ? BorderRadius.zero : BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF60CDFF).withOpacity(0.45)
                  : const Color(0xFF333333).withOpacity(0.6),
              width: isActive ? 1.2 : 0.8,
            ),
            boxShadow: win.isMaximized
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isActive ? 0.55 : 0.3),
                      blurRadius: isActive ? 28 : 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: win.isMaximized ? BorderRadius.zero : BorderRadius.circular(9),
            child: Stack(
              children: [
                // Window Main Layout: Title bar + Content
                Column(
                  children: [
                    // Title Bar (Windows 11 Mica styled)
                    _buildTitleBar(context, isActive),
                    // Body / Mirrored Viewport
                    Expanded(child: _buildWindowContent(context)),
                  ],
                ),

                // Windows 11 Snap Layouts Flyout Menu
                if (_showSnapFlyout)
                  Positioned(
                    top: 36,
                    right: 48,
                    child: _buildSnapLayoutsFlyout(context),
                  ),

                // 8 Resize Handles (Only when NOT maximized)
                if (!win.isMaximized) ...[
                  // Top
                  Positioned(
                    top: 0,
                    left: handleSize,
                    right: handleSize,
                    height: handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            top: win.y + d.delta.dy,
                            height: win.height - d.delta.dy,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom
                  Positioned(
                    bottom: 0,
                    left: handleSize,
                    right: handleSize,
                    height: handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            height: win.height + d.delta.dy,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Left
                  Positioned(
                    left: 0,
                    top: handleSize,
                    bottom: handleSize,
                    width: handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            left: win.x + d.delta.dx,
                            width: win.width - d.delta.dx,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Right
                  Positioned(
                    right: 0,
                    top: handleSize,
                    bottom: handleSize,
                    width: handleSize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            width: win.width + d.delta.dx,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Top-Left Corner
                  Positioned(
                    top: 0,
                    left: 0,
                    width: handleSize * 2,
                    height: handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            left: win.x + d.delta.dx,
                            top: win.y + d.delta.dy,
                            width: win.width - d.delta.dx,
                            height: win.height - d.delta.dy,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Top-Right Corner
                  Positioned(
                    top: 0,
                    right: 0,
                    width: handleSize * 2,
                    height: handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            top: win.y + d.delta.dy,
                            width: win.width + d.delta.dx,
                            height: win.height - d.delta.dy,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom-Left Corner
                  Positioned(
                    bottom: 0,
                    left: 0,
                    width: handleSize * 2,
                    height: handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            left: win.x + d.delta.dx,
                            width: win.width - d.delta.dx,
                            height: win.height + d.delta.dy,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom-Right Corner
                  Positioned(
                    bottom: 0,
                    right: 0,
                    width: handleSize * 2,
                    height: handleSize * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) {
                          widget.controller.resize(
                            win.id,
                            width: win.width + d.delta.dx,
                            height: win.height + d.delta.dy,
                            desktopSize: widget.desktopSize,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, bool isActive) {
    final win = widget.window;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => widget.controller.toggleMaximize(win.id, widget.desktopSize),
      onPanUpdate: (details) {
        widget.controller.updatePosition(win.id, details.delta.dx, details.delta.dy, widget.desktopSize);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF202020) : const Color(0xFF181818),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF2C2C2C), width: 0.8),
          ),
        ),
        child: Row(
          children: [
            // App Icon
            AppIconWidget(
              app: win.app,
              size: 18,
              borderRadius: 4,
              showShadow: false,
            ),
            const SizedBox(width: 8),

            // App Title
            Expanded(
              child: Text(
                win.app.name,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Quick Nav Controls inside Title Bar (shown on widescreen)
            if (win.width >= 480) ...[
              _buildNavButton(Icons.arrow_back_rounded, 'Back', () => AdbService().goBack()),
              _buildNavButton(Icons.home_rounded, 'Home', () => AdbService().goHome()),
              _buildNavButton(Icons.layers_rounded, 'Recents', () => AdbService().showRecents()),
              const SizedBox(width: 6),
              Container(width: 1, height: 16, color: const Color(0xFF333333)),
              const SizedBox(width: 4),
            ],

            // Windows 11 Caption Controls: Minimize, Maximize/Snap, Close
            _Windows11CaptionButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              width: 44,
              onTap: () => widget.controller.minimizeWindow(win.id),
            ),
            _Windows11CaptionButton(
              icon: win.isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
              tooltip: win.isMaximized ? 'Restore' : 'Maximize / Snap',
              width: 44,
              onTap: () {
                setState(() => _showSnapFlyout = !_showSnapFlyout);
              },
            ),
            _Windows11CaptionButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              width: 44,
              isClose: true,
              onTap: () => widget.controller.closeWindow(win.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapLayoutsFlyout(BuildContext context) {
    final win = widget.window;

    return MouseRegion(
      onExit: (_) => setState(() => _showSnapFlyout = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.96),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Snap Layouts',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // 50/50 Split Template
                Row(
                  children: [
                    Expanded(
                      child: _buildSnapZone(
                        label: 'Left 50%',
                        icon: Icons.vertical_split_rounded,
                        onTap: () {
                          setState(() => _showSnapFlyout = false);
                          widget.controller.snapLeft(win.id, widget.desktopSize);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSnapZone(
                        label: 'Right 50%',
                        icon: Icons.vertical_split_rounded,
                        onTap: () {
                          setState(() => _showSnapFlyout = false);
                          widget.controller.snapRight(win.id, widget.desktopSize);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Maximize / Fullscreen Template
                _buildSnapZone(
                  label: win.isMaximized ? 'Restore Window' : 'Full Screen Maximize',
                  icon: win.isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                  onTap: () {
                    setState(() => _showSnapFlyout = false);
                    widget.controller.toggleMaximize(win.id, widget.desktopSize);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnapZone({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF60CDFF)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildWindowContent(BuildContext context) {
    return EmbeddedStreamViewport(
      window: widget.window,
      desktopSize: widget.desktopSize,
    );
  }
}

/// Windows 11 Caption Control Button (Minimize, Maximize, Close)
class _Windows11CaptionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final double width;
  final bool isClose;
  final VoidCallback onTap;

  const _Windows11CaptionButton({
    required this.icon,
    required this.tooltip,
    this.width = 44,
    this.isClose = false,
    required this.onTap,
  });

  @override
  State<_Windows11CaptionButton> createState() => _Windows11CaptionButtonState();
}

class _Windows11CaptionButtonState extends State<_Windows11CaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHovered
        ? (widget.isClose ? const Color(0xFFE81123) : Colors.white.withOpacity(0.08))
        : Colors.transparent;

    final iconColor = _isHovered && widget.isClose
        ? Colors.white
        : (_isHovered ? Colors.white : const Color(0xFFCBD5E1));

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: widget.width,
            height: 36,
            color: bgColor,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.isClose ? 14 : 12,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
