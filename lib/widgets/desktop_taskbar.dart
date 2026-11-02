import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/window_manager_controller.dart';
import '../services/adb_service.dart';
import 'connection_mode_dialog.dart';

class DesktopTaskbar extends StatefulWidget {
  final WindowManagerController controller;
  final VoidCallback onToggleDrawer;
  final bool isDrawerOpen;
  final VoidCallback onToggleQuickSettings;
  final bool isQuickSettingsOpen;
  final VoidCallback onToggleNotifications;
  final bool isNotificationsOpen;

  const DesktopTaskbar({
    super.key,
    required this.controller,
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final adb = AdbService();
    final windows = widget.controller.windows;
    final activeId = widget.controller.activeWindowId;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F131D).withOpacity(0.92),
        border: const Border(top: BorderSide(color: Color(0xFF232D3F), width: 1)),
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
                color: widget.isDrawerOpen ? const Color(0xFF2563EB) : const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.grid_view_rounded, size: 20, color: Colors.white),
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
                _buildTaskbarIcon(Icons.arrow_back_ios_new_rounded, 'Back', () => adb.goBack()),
                _buildTaskbarIcon(Icons.circle_outlined, 'Home', () => adb.goHome()),
                _buildTaskbarIcon(Icons.crop_square_rounded, 'Recent Apps', () => adb.showRecents()),
              ],
            ),
          ),

          const SizedBox(width: 12),
          Container(width: 1, height: 26, color: const Color(0xFF263248)),
          const SizedBox(width: 12),

          // 3. Open Windows / App Icons in Taskbar
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: windows.map((win) {
                  final isActive = activeId == win.id && !win.isMinimized;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => widget.controller.toggleMinimize(win.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF2563EB).withOpacity(0.2)
                              : win.isMinimized
                                  ? Colors.transparent
                                  : const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF2B374E),
                            width: isActive ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: win.app.gradientColors),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(win.app.icon, size: 11, color: Colors.white),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              win.app.name,
                              style: TextStyle(
                                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Dot indicator
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: win.isMinimized
                                    ? const Color(0xFF64748B)
                                    : (isActive ? const Color(0xFF60A5FA) : const Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  color: widget.isNotificationsOpen ? const Color(0xFF2563EB) : const Color(0xFF172033),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isNotificationsOpen ? const Color(0xFF60A5FA) : const Color(0xFF2D3C5C),
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
                          : (adb.activeNotifications.isNotEmpty ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8)),
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

          // Quick Settings Toggle (Volume & Network Status)
          Tooltip(
            message: 'Quick Settings & Media Controls',
            child: InkWell(
              onTap: widget.onToggleQuickSettings,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.isQuickSettingsOpen ? const Color(0xFF2563EB) : const Color(0xFF172033),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isQuickSettingsOpen ? const Color(0xFF60A5FA) : const Color(0xFF2D3C5C),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      adb.currentVolume == 0
                          ? Icons.volume_off_rounded
                          : (adb.currentVolume > 15 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
                      size: 14,
                      color: widget.isQuickSettingsOpen ? Colors.white : const Color(0xFF60A5FA),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      adb.isWifiEnabled ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      size: 14,
                      color: widget.isQuickSettingsOpen ? Colors.white : const Color(0xFF34D399),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Device Capsule (Click to open Connection Mode dialog)
          Tooltip(
            message: 'Connection Mode: ${adb.isWireless ? "Wireless Wi-Fi" : (adb.isWired ? "Wired USB" : "Disconnected")} (Click to change)',
            child: InkWell(
              onTap: () => ConnectionModeDialog.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF172033),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: adb.isWireless
                        ? const Color(0xFF3B82F6)
                        : (adb.isWired ? const Color(0xFF10B981) : const Color(0xFF2D3C5C)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      adb.isWireless
                          ? Icons.wifi_rounded
                          : (adb.isWired ? Icons.usb_rounded : Icons.phone_android_rounded),
                      size: 14,
                      color: adb.isWireless
                          ? const Color(0xFF60A5FA)
                          : (adb.isWired ? const Color(0xFF34D399) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      adb.deviceModel,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w500),
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
                      : (adb.batteryLevel > 20 ? Icons.battery_full_rounded : Icons.battery_alert_rounded),
                  size: 14,
                  color: adb.isCharging
                      ? const Color(0xFFFBBF24)
                      : (adb.batteryLevel > 20 ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                ),
                const SizedBox(width: 4),
                Text(
                  '${adb.batteryLevel}%',
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Clock & Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDate(_now),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
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
