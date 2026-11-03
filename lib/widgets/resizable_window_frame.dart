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

    return Container(
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
          // Draggable Area (Icon, App Title, and empty area for moving/double-tap to maximize)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => widget.controller.toggleMaximize(win.id, widget.desktopSize),
              onPanUpdate: (details) {
                widget.controller.updatePosition(win.id, details.delta.dx, details.delta.dy, widget.desktopSize);
              },
              child: Row(
                children: [
                  AppIconWidget(
                    app: win.app,
                    size: 18,
                    borderRadius: 4,
                    showShadow: false,
                  ),
                  const SizedBox(width: 8),
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
                ],
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

          // Windows 11 Caption Controls: Minimize, Maximize/Restore, Close
          _buildCaptionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimize',
            onTap: () => widget.controller.minimizeWindow(win.id),
          ),
          _buildCaptionButton(
            icon: win.isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
            tooltip: win.isMaximized ? 'Restore' : 'Maximize',
            onTap: () => widget.controller.toggleMaximize(win.id, widget.desktopSize),
          ),
          _buildCaptionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            isClose: true,
            hoverColor: const Color(0xFFE81123),
            onTap: () => widget.controller.closeWindow(win.id),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color hoverColor = const Color(0x1FFFFFFF),
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverColor,
          child: SizedBox(
            width: 44,
            height: 36,
            child: Icon(
              icon,
              size: isClose ? 14 : 12,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
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
