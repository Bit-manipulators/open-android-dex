import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/adb_service.dart';

/// Pure Android 16 Expressive Quick Settings / Control Center Panel.
/// Features frosted glassmorphism, Material You Expressive pills,
/// tactile dual-layer capsule sliders with inverted clip mask,
/// and responsive Android 16 media card.
class QuickSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const QuickSettingsPanel({super.key, required this.onClose});

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel> {
  final _adb = AdbService();
  StreamSubscription<bool>? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _adb.onDeviceStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    int hour = now.hour % 12;
    if (hour == 0) hour = 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Prevent taps inside panel from triggering outside-tap dismissal
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: 376,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF13151A).withOpacity(0.93),
            borderRadius: BorderRadius.circular(28),
            border:
                Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.65),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Android 16 Status Header (Time, Date, Battery Capsule, Action Buttons)
              _buildHeader(),
              const SizedBox(height: 14),

              // 2. Primary Dual Connectivity Capsules (Internet/Wi-Fi and Bluetooth)
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryCapsule(
                      title: 'Internet',
                      subtitle:
                          _adb.isWifiEnabled ? 'Wi-Fi On' : 'Disconnected',
                      icon: _adb.isWifiEnabled
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      isActive: _adb.isWifiEnabled,
                      onTap: () async {
                        await _adb.toggleWifi();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPrimaryCapsule(
                      title: 'Bluetooth',
                      subtitle: _adb.isBluetoothEnabled ? 'Active' : 'Off',
                      icon: _adb.isBluetoothEnabled
                          ? Icons.bluetooth_rounded
                          : Icons.bluetooth_disabled_rounded,
                      isActive: _adb.isBluetoothEnabled,
                      onTap: () async {
                        await _adb.toggleBluetooth();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Android 16 Quick Action Grid (2x2 unified tiles)
              Row(
                children: [
                  Expanded(
                    child: _buildQuickTile(
                      title: 'Do Not Disturb',
                      subtitle: _adb.isDndEnabled ? 'On' : 'Off',
                      icon: _adb.isDndEnabled
                          ? Icons.do_not_disturb_on_rounded
                          : Icons.do_not_disturb_off_rounded,
                      isActive: _adb.isDndEnabled,
                      onTap: () async {
                        await _adb.toggleDnd();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickTile(
                      title: 'Auto-rotate',
                      subtitle: _adb.isAutoRotate ? 'Auto' : 'Locked',
                      icon: _adb.isAutoRotate
                          ? Icons.screen_rotation_rounded
                          : Icons.screen_lock_rotation_rounded,
                      isActive: _adb.isAutoRotate,
                      onTap: () async {
                        await _adb.toggleAutoRotate();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickTile(
                      title: 'Screenshot',
                      subtitle: 'Capture',
                      icon: Icons.screenshot_monitor_rounded,
                      isActive: false,
                      onTap: () async {
                        await _adb.takeScreenshot();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickTile(
                      title: 'Lock Screen',
                      subtitle: 'Sleep',
                      icon: Icons.lock_outline_rounded,
                      isActive: false,
                      onTap: () async {
                        await _adb.lockScreen();
                        widget.onClose();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Android 16 Tactile Dual-Layer Sliders (Brightness & Volume)
              _Android16CapsuleSlider(
                value: (_adb.screenBrightness / 255).clamp(0.0, 1.0),
                icon: Icons.brightness_medium_rounded,
                label: 'Brightness',
                valueText: '${((_adb.screenBrightness / 255) * 100).toInt()}%',
                onChanged: (val) {
                  final brightnessVal = (val * 255).round();
                  setState(() => _adb.screenBrightness = brightnessVal);
                  _adb.setBrightness(brightnessVal);
                },
              ),
              const SizedBox(height: 10),
              _Android16CapsuleSlider(
                value: (_adb.currentVolume / _adb.maxVolume).clamp(0.0, 1.0),
                icon: _adb.currentVolume == 0
                    ? Icons.volume_off_rounded
                    : (_adb.currentVolume > 14
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded),
                label: 'Volume',
                valueText: '${_adb.currentVolume}/${_adb.maxVolume}',
                onChanged: (val) {
                  final vol = (val * _adb.maxVolume).round();
                  setState(() => _adb.currentVolume = vol);
                  _adb.setVolume(vol);
                },
              ),
              const SizedBox(height: 14),

              // 5. Android 16 Media Player Card ("Now Playing")
              _buildAndroid16MediaCard(),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time & Date
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatCurrentTime(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatCurrentDate(),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Android 16 Header Actions: Battery Capsule & Action Circles
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Battery Stadium Pill
            _buildBatteryBadge(),
            const SizedBox(width: 8),

            // Settings button
            _buildCircleAction(
              icon: Icons.settings_outlined,
              tooltip: 'Android Settings',
              onTap: () => _adb.openSettings(),
            ),
            const SizedBox(width: 6),

            // Close button
            _buildCircleAction(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: widget.onClose,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatteryBadge() {
    final isCharging = _adb.isCharging;
    final level = _adb.batteryLevel;
    final Color iconColor = isCharging
        ? const Color(0xFF34D399)
        : (level <= 20
            ? const Color(0xFFF87171)
            : const Color(0xFFA8C7FA));

    final IconData iconData = isCharging
        ? Icons.battery_charging_full_rounded
        : (level <= 20
            ? Icons.battery_alert_rounded
            : Icons.battery_std_rounded);

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            '$level%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2127),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            hoverColor: const Color(0xFF2C2F38),
            onTap: onTap,
            child: Center(
              child: Icon(icon, size: 15, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryCapsule({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 58,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA8C7FA) : const Color(0xFF1E2127),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD3E3FD).withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          hoverColor: isActive
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF00325B).withOpacity(0.12)
                        : const Color(0xFF2B2E37),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 18,
                      color: isActive
                          ? const Color(0xFF00325B)
                          : const Color(0xFFE2E2E6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              isActive ? const Color(0xFF00325B) : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF041E49).withOpacity(0.8)
                              : const Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isActive
                      ? const Color(0xFF00325B).withOpacity(0.6)
                      : Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA8C7FA) : const Color(0xFF1E2127),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD3E3FD).withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          hoverColor: isActive
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF00325B).withOpacity(0.12)
                        : const Color(0xFF2B2E37),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 15,
                      color: isActive
                          ? const Color(0xFF00325B)
                          : const Color(0xFFE2E2E6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              isActive ? const Color(0xFF00325B) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF041E49).withOpacity(0.8)
                              : const Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAndroid16MediaCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Output Pill
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 12,
                      color: Color(0xFFA8C7FA),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_adb.deviceModel} Output',
                        style: const TextStyle(
                          color: Color(0xFFA8C7FA),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.cast_connected_rounded,
                size: 13,
                color: Color(0xFFA8C7FA),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Track Info & Squircle Album Art
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _adb.currentMediaTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      _adb.currentMediaArtist,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar with timestamps
          Row(
            children: [
              const Text(
                '0:45',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 3.5,
                    color: const Color(0xFF2C323D),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.35,
                        child: Container(
                          color: const Color(0xFFA8C7FA),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '3:20',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: Colors.white.withOpacity(0.08),
                  onTap: () => _adb.mediaPrevious(),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.skip_previous_rounded,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // Big Android 16 Squircle Play/Pause button
              Material(
                color: const Color(0xFFA8C7FA),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  hoverColor: Colors.white.withOpacity(0.15),
                  onTap: () async {
                    await _adb.mediaPlayPause();
                    setState(() {});
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    child: Icon(
                      _adb.isMediaPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 22,
                      color: const Color(0xFF00325B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  hoverColor: Colors.white.withOpacity(0.08),
                  onTap: () => _adb.mediaNext(),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.skip_next_rounded,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Android 16 Tactile Fluid Capsule Slider Widget.
/// Uses dual-layer inverted clip mask so text and icons always have
/// 100% optimal contrast regardless of fill level.
class _Android16CapsuleSlider extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final IconData icon;
  final String label;
  final String valueText;

  const _Android16CapsuleSlider({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.label,
    required this.valueText,
  });

  Widget _buildContent({
    required Color iconColor,
    required Color textColor,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            valueText,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final clampedVal = value.clamp(0.0, 1.0);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final newVal = (details.localPosition.dx / w).clamp(0.0, 1.0);
              onChanged(newVal);
            },
            onTapDown: (details) {
              final newVal = (details.localPosition.dx / w).clamp(0.0, 1.0);
              onChanged(newVal);
            },
            child: Container(
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2127),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Stack(
                children: [
                  // Layer 1: Base Dark Track Layer (White / Slate text)
                  Positioned.fill(
                    child: _buildContent(
                      iconColor: Colors.white70,
                      textColor: Colors.white,
                      valueColor: const Color(0xFF94A3B8),
                    ),
                  ),

                  // Layer 2: Active Fill Layer (Clipped to clampedVal)
                  // Dark Navy text on Light Blue fill
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: w * clampedVal,
                          height: 44,
                          color: const Color(0xFFA8C7FA),
                          child: OverflowBox(
                            minWidth: w,
                            maxWidth: w,
                            alignment: Alignment.centerLeft,
                            child: _buildContent(
                              iconColor: const Color(0xFF00325B),
                              textColor: const Color(0xFF00325B),
                              valueColor: const Color(0xFF00325B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
