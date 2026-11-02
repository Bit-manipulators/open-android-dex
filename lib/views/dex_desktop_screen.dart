import 'package:flutter/material.dart';
import '../controllers/window_manager_controller.dart';
import '../models/app_info.dart';
import '../services/adb_service.dart';
import '../widgets/app_drawer_dialog.dart';
import '../widgets/connection_mode_dialog.dart';
import '../widgets/desktop_taskbar.dart';
import '../widgets/notification_center_dialog.dart';
import '../widgets/quick_settings_panel.dart';
import '../widgets/resizable_window_frame.dart';

class DexDesktopScreen extends StatefulWidget {
  const DexDesktopScreen({super.key});

  @override
  State<DexDesktopScreen> createState() => _DexDesktopScreenState();
}

class _DexDesktopScreenState extends State<DexDesktopScreen> {
  final _windowManager = WindowManagerController();
  final _adb = AdbService();
  bool _isDrawerOpen = false;
  bool _isQuickSettingsOpen = false;
  bool _isNotificationsOpen = false;

  void _openDefaultAppIfNone() {
    if (_windowManager.openWindows.isEmpty && mounted) {
      final size = MediaQuery.of(context).size;
      _windowManager.openApp(
        AppInfo.fromPackage('com.google.android.calculator'),
        size,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _adb.startPolling();
    _adb.onDeviceStateChanged.listen((connected) {
      if (mounted) {
        setState(() {});
        if (connected) {
          _openDefaultAppIfNone();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final devices = await _adb.getConnectedDevices();
      if (devices.isNotEmpty) {
        // Device is already attached! Immediately launch default desktop app
        if (_adb.selectedDeviceSerial == null || !devices.contains(_adb.selectedDeviceSerial)) {
          _adb.selectedDeviceSerial = _adb.getPreferredDevice(devices);
        }
        _openDefaultAppIfNone();
      } else {
        // Prompt for Connection Mode (Wired USB / Wireless QR) on initial startup
        if (mounted) {
          ConnectionModeDialog.show(context, onConnected: () {
            _openDefaultAppIfNone();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _adb.stopPolling();
    _windowManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Scaffold(
          body: ListenableBuilder(
            listenable: _windowManager,
            builder: (context, _) {
              // Sort open windows by zIndex so top window renders on top
              final sortedWindows = List.of(_windowManager.openWindows)
                ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

              return Stack(
                children: [
                  // 1. Wallpaper Background
                  _buildWallpaper(),

                  // 2. Desktop Workspace (Desktop Icons & Widgets)
                  _buildDesktopCanvas(desktopSize),

                  // 3. Resizable Windows Stack
                  ...sortedWindows.map((win) {
                    return ResizableWindowFrame(
                      key: ValueKey(win.id),
                      window: win,
                      controller: _windowManager,
                      desktopSize: desktopSize,
                    );
                  }),

                  // 4. App Drawer Dialog (if open)
                  if (_isDrawerOpen)
                    AppDrawerDialog(
                      onSelectApp: (app) => _windowManager.openApp(app, desktopSize),
                      onClose: () => setState(() => _isDrawerOpen = false),
                    ),

                  // 5. Quick Settings Panel (if open)
                  if (_isQuickSettingsOpen)
                    Positioned(
                      right: 16,
                      bottom: 58,
                      child: QuickSettingsPanel(
                        onClose: () => setState(() => _isQuickSettingsOpen = false),
                      ),
                    ),

                  // 6. Notification Center Dialog (if open)
                  if (_isNotificationsOpen)
                    Positioned(
                      right: 60,
                      bottom: 58,
                      child: NotificationCenterDialog(
                        onClose: () => setState(() => _isNotificationsOpen = false),
                      ),
                    ),

                  // 7. Pinned Bottom Taskbar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DesktopTaskbar(
                      controller: _windowManager,
                      isDrawerOpen: _isDrawerOpen,
                      onToggleDrawer: () => setState(() {
                        _isDrawerOpen = !_isDrawerOpen;
                        if (_isDrawerOpen) {
                          _isQuickSettingsOpen = false;
                          _isNotificationsOpen = false;
                        }
                      }),
                      isQuickSettingsOpen: _isQuickSettingsOpen,
                      onToggleQuickSettings: () => setState(() {
                        _isQuickSettingsOpen = !_isQuickSettingsOpen;
                        if (_isQuickSettingsOpen) {
                          _isDrawerOpen = false;
                          _isNotificationsOpen = false;
                        }
                      }),
                      isNotificationsOpen: _isNotificationsOpen,
                      onToggleNotifications: () => setState(() {
                        _isNotificationsOpen = !_isNotificationsOpen;
                        if (_isNotificationsOpen) {
                          _isDrawerOpen = false;
                          _isQuickSettingsOpen = false;
                        }
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWallpaper() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090D16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/wallpaper.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.4, -0.3),
                    radius: 1.2,
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                      Color(0xFF020617),
                    ],
                  ),
                ),
              ),
            ),
            // Ambient dark glass overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCanvas(Size desktopSize) {
    final apps = _adb.installedApps;
    final primaryApps = apps.isNotEmpty
        ? apps.take(12).toList()
        : [
            AppInfo.fromPackage('com.google.android.calculator'),
            AppInfo.fromPackage('com.android.chrome'),
            AppInfo.fromPackage('com.google.android.youtube'),
            AppInfo.fromPackage('com.android.camera'),
            AppInfo.fromPackage('com.android.settings'),
            AppInfo.fromPackage('com.android.filemanager'),
          ];

    return Positioned.fill(
      bottom: 52, // Leave space for taskbar
      child: Stack(
        children: [
          // Top Floating Device Capsule (Original DeX Style - Click to open Connection Mode)
          Positioned(
            top: 14,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ConnectionModeDialog.show(context),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _adb.isWireless
                          ? const Color(0xFF3B82F6)
                          : (_adb.isWired ? const Color(0xFF10B981) : const Color(0xFF374151)),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1F2937),
                          border: Border.all(color: const Color(0xFF4B5563)),
                        ),
                        child: Icon(
                          _adb.isWireless
                              ? Icons.wifi_rounded
                              : (_adb.isWired ? Icons.usb_rounded : Icons.android_rounded),
                          size: 14,
                          color: _adb.isWireless
                              ? const Color(0xFF60A5FA)
                              : (_adb.isWired ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                _adb.deviceModel.isNotEmpty ? _adb.deviceModel : 'No Device',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.tune_rounded, size: 11, color: Color(0xFF94A3B8)),
                            ],
                          ),
                          Text(
                            _adb.isWireless
                                ? 'Wireless Wi-Fi • Click to Switch'
                                : (_adb.isWired ? 'Wired USB • Click to Switch' : 'Click to Setup Connection'),
                            style: TextStyle(
                              color: _adb.isWireless
                                  ? const Color(0xFF93C5FD)
                                  : (_adb.isWired ? const Color(0xFFA7F3D0) : const Color(0xFF9CA3AF)),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Desktop App Grid (Left side)
          Positioned(
            top: 24,
            left: 24,
            bottom: 24,
            width: 110,
            child: SingleChildScrollView(
              child: Column(
                children: primaryApps.map((app) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _buildDesktopAppIcon(app, desktopSize),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAppIcon(AppInfo app, Size desktopSize) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _windowManager.openApp(app, desktopSize),
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.white.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: app.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: app.gradientColors.first.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(app.icon, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                app.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
