import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/adb_service.dart';

/// Pure Android 16 Expressive Quick Settings / Control Center Panel.
/// Features frosted glassmorphism, Material You Expressive pills,
/// tactile capsule sliders, and Android 16 media card.
class QuickSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const QuickSettingsPanel({super.key, required this.onClose});

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel> {
  final _adb = AdbService();

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: 370,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF141519).withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border:
                Border.all(color: Colors.white.withOpacity(0.09), width: 1.0),
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
              const SizedBox(height: 18),

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
              const SizedBox(height: 12),

              // 3. Android 16 Quick Action Grid (2x2 rounded pills)
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryPill(
                      label: 'Do Not Disturb',
                      icon: Icons.do_not_disturb_on_rounded,
                      isActive: _adb.isDndEnabled,
                      onTap: () async {
                        await _adb.toggleDnd();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSecondaryPill(
                      label: 'Auto-rotate',
                      icon: Icons.screen_rotation_rounded,
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
                    child: _buildSecondaryPill(
                      label: 'Screenshot',
                      icon: Icons.screenshot_monitor_rounded,
                      isActive: false,
                      onTap: () async {
                        await _adb.takeScreenshot();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSecondaryPill(
                      label: 'Lock Screen',
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
              const SizedBox(height: 18),

              // 4. Android 16 Tactile Capsule Sliders (Brightness & Volume)
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
              const SizedBox(height: 16),

              // 5. Android 16 Media Player Card ("Now Playing")
              _buildAndroid16MediaCard(),
            ],
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF282A30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _adb.isCharging
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_std_rounded,
                    size: 14,
                    color: _adb.isCharging
                        ? const Color(0xFF34D399)
                        : const Color(0xFFA8C7FA),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_adb.batteryLevel}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildCircleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF282A30),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7.0),
            child: Icon(icon, size: 16, color: Colors.white70),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA8C7FA) : const Color(0xFF282A30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD3E3FD)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF00325B).withOpacity(0.12)
                    : const Color(0xFF1E1F24),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isActive
                    ? const Color(0xFF00325B)
                    : const Color(0xFFE2E2E6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF00325B) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF041E49).withOpacity(0.8)
                          : const Color(0xFF94A3B8),
                      fontSize: 10.5,
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
    );
  }

  Widget _buildSecondaryPill({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFA8C7FA) : const Color(0xFF282A30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD3E3FD)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color:
                  isActive ? const Color(0xFF00325B) : const Color(0xFFE2E2E6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFF00325B)
                      : const Color(0xFFE2E2E6),
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroid16MediaCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22242A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Output Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_android_rounded,
                      size: 12, color: Color(0xFFA8C7FA)),
                  const SizedBox(width: 5),
                  Text(
                    '${_adb.deviceModel} Output',
                    style: const TextStyle(
                        color: Color(0xFFA8C7FA),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Icon(Icons.cast_connected_rounded,
                  size: 13, color: Color(0xFFA8C7FA)),
            ],
          ),
          const SizedBox(height: 10),

          // Track Info & Art
          Row(
            children: [
              // Squircle Album Art
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _adb.currentMediaTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _adb.currentMediaArtist,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Android 16 Squiggly / Expressive Progress Bar
          Row(
            children: [
              const Text('0:45',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 4,
                    color: const Color(0xFF334155),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 90,
                        color: const Color(0xFFA8C7FA),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('3:20',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),

          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    size: 22, color: Colors.white70),
                onPressed: () => _adb.mediaPrevious(),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 20),
              // Big Android 16 Squircle Play/Pause button
              InkWell(
                onTap: () async {
                  await _adb.mediaPlayPause();
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA8C7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _adb.isMediaPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 24,
                    color: const Color(0xFF00325B),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    size: 22, color: Colors.white70),
                onPressed: () => _adb.mediaNext(),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Android 16 Tactile Fluid Capsule Slider Widget.
/// Fluidly responds to drag and tap, with track-embedded icon and label.
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final clampedVal = value.clamp(0.0, 1.0);
        return GestureDetector(
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
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF282A30),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Stack(
              children: [
                // Filled progress portion with smooth rounded capsule shape
                FractionallySizedBox(
                  widthFactor: clampedVal,
                  heightFactor: 1.0,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFA8C7FA),
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),
                // Contents: Icon on left, Label in center, Value text on right
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 19,
                          color: clampedVal > 0.18
                              ? const Color(0xFF00325B)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: clampedVal > 0.45
                                  ? const Color(0xFF00325B)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          valueText,
                          style: TextStyle(
                            color: clampedVal > 0.88
                                ? const Color(0xFF00325B)
                                : const Color(0xFFCBD5E1),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
