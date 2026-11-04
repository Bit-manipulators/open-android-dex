import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/window_manager_controller.dart';
import '../models/dex_window.dart';
import '../services/adb_service.dart';
import 'app_icon_widget.dart';
import 'connection_mode_dialog.dart';

/// Desktop Taskbar featuring pure Windows 11 style active window items,
/// acrylic hover & focus states, signature cyan bottom indicator pill,
/// and Windows 11 taskbar thumbnail preview & snap flyout menu.
class DesktopTaskbar extends StatefulWidget {
  final WindowManagerController controller;
  final Size desktopSize;
  final VoidCallback onToggleDrawer;
  final bool isDrawerOpen;
  final VoidCallback onToggleQuickSettings;
  final bool isQuickSettingsOpen;
  final VoidCallback onToggleNotifications;
  final bool isNotificationsOpen;

  const DesktopTaskbar({
    super.key,
    required this.controller,
    required this.desktopSize,
    required this.onToggleDrawer,
    required this.isDrawerOpen,
    required this.onToggleQuickSettings,
    required this.isQuickSettingsOpen,
    required this.onToggleNotifications,
    required this.isNotificationsOpen,
  });

  @override
  State<DesktopTaskbar> createState() => _DesktopTaskbarState();
}

class _DesktopTaskbarState extends State<DesktopTaskbar> {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  // Windows 11 Hover Preview & Menu State
  String? _previewWindowId;
  Timer? _previewHoverTimer;
  double _previewGlobalX = 0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _previewHoverTimer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    int hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  void _showPreview(String windowId, double globalX) {
    _previewHoverTimer?.cancel();
    _previewHoverTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() {
          _previewWindowId = windowId;
          _previewGlobalX = globalX;
        });
      }
    });
  }

  void _hidePreview() {
    _previewHoverTimer?.cancel();
    if (_previewWindowId != null && mounted) {
      setState(() => _previewWindowId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adb = AdbService();
    final windows = widget.controller.windows;
    final activeId = widget.controller.activeWindowId;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Taskbar Main Bar
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F131D).withOpacity(0.92),
            border: const Border(
                top: BorderSide(color: Color(0xFF232D3F), width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. App Drawer Button (DeX 9-dot launcher)
              InkWell(
                onTap: widget.onToggleDrawer,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isDrawerOpen
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF1E2638),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Android Nav Bar: Back, Home, Recents
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF171E2D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTaskbarIcon(Icons.arrow_back_ios_new_rounded, 'Back',
                        () => adb.goBack()),
                    _buildTaskbarIcon(
                        Icons.circle_outlined, 'Home', () => adb.goHome()),
                    _buildTaskbarIcon(Icons.crop_square_rounded, 'Recent Apps',
                        () => adb.showRecents()),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              Container(width: 1, height: 26, color: const Color(0xFF263248)),
              const SizedBox(width: 12),

              // 3. Open Windows / App Items in Taskbar (Windows 11 Styled)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: windows.map((win) {
                      final isActive = activeId == win.id && !win.isMinimized;
                      return _Windows11TaskbarItem(
                        key: ValueKey(win.id),
                        window: win,
                        isActive: isActive,
                        onTap: () {
                          _hidePreview();
                          widget.controller.toggleMinimize(win.id);
                        },
                        onSecondaryTap: () {
                          setState(() {
                            _previewWindowId =
                                (_previewWindowId == win.id) ? null : win.id;
                          });
                        },
                        onHoverEnter: (globalX) =>
                            _showPreview(win.id, globalX),
                        onHoverExit: () => _hidePreview(),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 4. System Tray: Notifications, Quick Settings, Device Capsule, Battery, Time
              const SizedBox(width: 8),

              // Notification Bell
              Tooltip(
                message: 'Notifications (${adb.activeNotifications.length})',
                child: InkWell(
                  onTap: widget.onToggleNotifications,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.isNotificationsOpen
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF172033),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isNotificationsOpen
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2D3C5C),
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          adb.activeNotifications.isNotEmpty
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          size: 16,
                          color: widget.isNotificationsOpen
                              ? Colors.white
                              : (adb.activeNotifications.isNotEmpty
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF94A3B8)),
                        ),
                        if (adb.activeNotifications.isNotEmpty)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Quick Settings Toggle (Android 16 Control Center)
              Tooltip(
                message: 'Quick Settings & Media Controls (Android 16)',
                child: InkWell(
                  onTap: widget.onToggleQuickSettings,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.isQuickSettingsOpen
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF172033),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isQuickSettingsOpen
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2D3C5C),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          adb.currentVolume == 0
                              ? Icons.volume_off_rounded
                              : (adb.currentVolume > 15
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded),
                          size: 14,
                          color: widget.isQuickSettingsOpen
                              ? Colors.white
                              : const Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          adb.isWifiEnabled
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          size: 14,
                          color: widget.isQuickSettingsOpen
                              ? Colors.white
                              : const Color(0xFF34D399),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Device Capsule
              Tooltip(
                message:
                    'Connection Mode: ${adb.isWireless ? "Wireless Wi-Fi" : (adb.isWired ? "Wired USB" : "Disconnected")} (Click to change)',
                child: InkWell(
                  onTap: () => ConnectionModeDialog.show(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172033),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: adb.isWireless
                            ? const Color(0xFF3B82F6)
                            : (adb.isWired
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2D3C5C)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          adb.isWireless
                              ? Icons.wifi_rounded
                              : (adb.isWired
                                  ? Icons.usb_rounded
                                  : Icons.phone_android_rounded),
                          size: 14,
                          color: adb.isWireless
                              ? const Color(0xFF60A5FA)
                              : (adb.isWired
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          adb.deviceModel,
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Battery Capsule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF172033),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2D3C5C)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      adb.isCharging
                          ? Icons.battery_charging_full_rounded
                          : (adb.batteryLevel > 20
                              ? Icons.battery_full_rounded
                              : Icons.battery_alert_rounded),
                      size: 14,
                      color: adb.isCharging
                          ? const Color(0xFFFBBF24)
                          : (adb.batteryLevel > 20
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF87171)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${adb.batteryLevel}%',
                      style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Clock & Date
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A29),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(_now),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(_now),
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Windows 11 Active Window Flyout Menu & Hover Preview
        if (_previewWindowId != null) ...[
          _buildWindows11PreviewOverlay(
            context,
            widget.controller.getWindow(_previewWindowId!),
          ),
        ],
      ],
    );
  }

  Widget _buildWindows11PreviewOverlay(BuildContext context, DexWindow? win) {
    if (win == null) return const SizedBox.shrink();

    // Clamp preview horizontal position so it stays cleanly on screen
    final clampX =
        (_previewGlobalX - 110).clamp(16.0, widget.desktopSize.width - 250);

    return Positioned(
      left: clampX,
      bottom: 60,
      child: MouseRegion(
        onEnter: (_) => _previewHoverTimer?.cancel(),
        onExit: (_) => _hidePreview(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F).withOpacity(0.95),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: Colors.white.withOpacity(0.14), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: App Icon, Name, and Windows 11 Close Button
                  Row(
                    children: [
                      AppIconWidget(
                        app: win.app,
                        size: 16,
                        borderRadius: 3,
                        showShadow: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          win.app.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Windows 11 Close Button (turns red on hover)
                      _Windows11CloseIcon(
                        onTap: () {
                          _hidePreview();
                          widget.controller.closeWindow(win.id);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Miniature Window Preview Card
                  InkWell(
                    onTap: () {
                      _hidePreview();
                      widget.controller.bringToFront(win.id);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Mini titlebar imitation
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 16,
                            child: Container(
                              color: const Color(0xFF222222),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  AppIconWidget(
                                      app: win.app, size: 9, borderRadius: 2),
                                  const SizedBox(width: 4),
                                  Text(
                                    win.app.name,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Viewport Center Icon
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIconWidget(
                                  app: win.app, size: 32, borderRadius: 6),
                              const SizedBox(height: 6),
                              Text(
                                win.isMinimized
                                    ? 'Minimized'
                                    : 'Active Workspace',
                                style: TextStyle(
                                  color: win.isMinimized
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF60CDFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Windows 11 Quick Action Bar (Snap, Maximize, Minimize, Close)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildWin11ActionTile(
                        icon: Icons.vertical_split_rounded,
                        tooltip: 'Snap Left (50%)',
                        onTap: () {
                          _hidePreview();
                          widget.controller
                              .snapLeft(win.id, widget.desktopSize);
                        },
                      ),
                      _buildWin11ActionTile(
                        icon: Icons.horizontal_split_rounded,
                        tooltip: 'Snap Right (50%)',
                        onTap: () {
                          _hidePreview();
                          widget.controller
                              .snapRight(win.id, widget.desktopSize);
                        },
                      ),
                      _buildWin11ActionTile(
                        icon: win.isMaximized
                            ? Icons.filter_none_rounded
                            : Icons.crop_square_rounded,
                        tooltip: win.isMaximized ? 'Restore' : 'Maximize',
                        onTap: () {
                          _hidePreview();
                          widget.controller
                              .toggleMaximize(win.id, widget.desktopSize);
                        },
                      ),
                      _buildWin11ActionTile(
                        icon: Icons.remove_rounded,
                        tooltip: 'Minimize',
                        onTap: () {
                          _hidePreview();
                          widget.controller.minimizeWindow(win.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWin11ActionTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          hoverColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Icon(icon, size: 14, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskbarIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Icon(icon, size: 16, color: const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}

/// Windows 11 Taskbar App Button with authentic acrylic styling,
/// Segoe-like typography, and signature cyan bottom indicator pill.
class _Windows11TaskbarItem extends StatefulWidget {
  final DexWindow window;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final ValueChanged<double> onHoverEnter;
  final VoidCallback onHoverExit;

  const _Windows11TaskbarItem({
    super.key,
    required this.window,
    required this.isActive,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  @override
  State<_Windows11TaskbarItem> createState() => _Windows11TaskbarItemState();
}

class _Windows11TaskbarItemState extends State<_Windows11TaskbarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final win = widget.window;
    final isActive = widget.isActive;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: MouseRegion(
        onEnter: (e) {
          setState(() => _isHovered = true);
          widget.onHoverEnter(e.position.dx);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          widget.onHoverExit();
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onSecondaryTap: widget.onSecondaryTap,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.12)
                    : (_isHovered
                        ? Colors.white.withOpacity(0.08)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive
                      ? Colors.white.withOpacity(0.14)
                      : (_isHovered
                          ? Colors.white.withOpacity(0.06)
                          : Colors.transparent),
                  width: 0.8,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // App Icon and Name
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIconWidget(
                        app: win.app,
                        size: 20,
                        borderRadius: 4,
                        showShadow: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        win.app.name,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (_isHovered
                                  ? Colors.white70
                                  : const Color(0xFFCBD5E1)),
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),

                  // Windows 11 Signature Indicator Pill at bottom edge
                  Positioned(
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 18.0 : (win.isMinimized ? 4.0 : 6.0),
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(
                                0xFF60CDFF) // Signature Windows 11 Cyan Accent
                            : (win.isMinimized
                                ? Colors.white24
                                : Colors.white60),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF60CDFF).withOpacity(0.7),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Windows 11 Caption Close Icon with signature red hover transition
class _Windows11CloseIcon extends StatefulWidget {
  final VoidCallback onTap;

  const _Windows11CloseIcon({required this.onTap});

  @override
  State<_Windows11CloseIcon> createState() => _Windows11CloseIconState();
}

class _Windows11CloseIconState extends State<_Windows11CloseIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFE81123) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 13,
            color: _isHovered ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}
