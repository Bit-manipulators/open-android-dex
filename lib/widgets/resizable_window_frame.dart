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
            borderRadius: win.isMaximized ? BorderRadius.zero : BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF3B82F6).withOpacity(0.8) : const Color(0xFF334155).withOpacity(0.4),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: win.isMaximized
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isActive ? 0.6 : 0.35),
                      blurRadius: isActive ? 24 : 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: win.isMaximized ? BorderRadius.zero : BorderRadius.circular(11),
            child: Stack(
              children: [
                // Window Main Layout: Title bar + Content
                Column(
                  children: [
                    // Title Bar
                    _buildTitleBar(context, isActive),
                    // Body / Mirrored Viewport
                    Expanded(child: _buildWindowContent(context)),
                  ],
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
                            width: win.width - d.delta.dx,
                            top: win.y + d.delta.dy,
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
                            width: win.width + d.delta.dx,
                            top: win.y + d.delta.dy,
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
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E2330) : const Color(0xFF141720),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF2D3748), width: 0.8),
          ),
        ),
        child: Row(
          children: [
            // App Icon
            AppIconWidget(
              app: win.app,
              size: 22,
              borderRadius: 6,
              showShadow: false,
            ),
            const SizedBox(width: 8),

            // App Title
            Expanded(
              child: Text(
                win.app.name,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
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
              Container(width: 1, height: 16, color: const Color(0xFF334155)),
              const SizedBox(width: 6),
            ],

            // Window Buttons: Minimize, Maximize, Close
            _buildWindowButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              hoverColor: const Color(0xFF334155),
              onTap: () => widget.controller.minimizeWindow(win.id),
            ),
            const SizedBox(width: 4),
            _buildWindowButton(
              icon: win.isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
              tooltip: win.isMaximized ? 'Restore' : 'Maximize',
              hoverColor: const Color(0xFF334155),
              onTap: () => widget.controller.toggleMaximize(win.id, widget.desktopSize),
            ),
            const SizedBox(width: 4),
            _buildWindowButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              hoverColor: const Color(0xFFDC2626),
              onTap: () => widget.controller.closeWindow(win.id),
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

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required Color hoverColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          hoverColor: hoverColor,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(icon, size: 13, color: const Color(0xFFCBD5E1)),
          ),
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
