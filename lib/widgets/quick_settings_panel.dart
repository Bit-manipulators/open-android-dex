import 'package:flutter/material.dart';
import '../services/adb_service.dart';

class QuickSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const QuickSettingsPanel({super.key, required this.onClose});

  @override
  State<QuickSettingsPanel> createState() => _QuickSettingsPanelState();
}

class _QuickSettingsPanelState extends State<QuickSettingsPanel> {
  final _adb = AdbService();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Device & Battery
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                ),
                child: const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF60A5FA)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _adb.deviceModel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_adb.batteryLevel}% Battery ${_adb.isCharging ? "• Charging ⚡" : ""}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                onPressed: widget.onClose,
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Quick Action Tiles (Wi-Fi, Bluetooth, Lock, Screenshot)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTile(
                icon: _adb.isWifiEnabled ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                label: 'Wi-Fi',
                isActive: _adb.isWifiEnabled,
                onTap: () async {
                  await _adb.toggleWifi();
                  setState(() {});
                },
              ),
              _buildTile(
                icon: _adb.isBluetoothEnabled ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
                label: 'Bluetooth',
                isActive: _adb.isBluetoothEnabled,
                onTap: () async {
                  await _adb.toggleBluetooth();
                  setState(() {});
                },
              ),
              _buildTile(
                icon: Icons.lock_outline_rounded,
                label: 'Lock',
                isActive: false,
                onTap: () async {
                  await _adb.lockScreen();
                  widget.onClose();
                },
              ),
              _buildTile(
                icon: Icons.camera_alt_outlined,
                label: 'Capture',
                isActive: false,
                onTap: () async {
                  await _adb.takeScreenshot();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Volume Slider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _adb.currentVolume == 0
                              ? Icons.volume_off_rounded
                              : (_adb.currentVolume > 15 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
                          size: 16,
                          color: const Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Media Volume',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '${_adb.currentVolume}/${_adb.maxVolume}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveTrackColor: const Color(0xFF475569),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF3B82F6).withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _adb.currentVolume.toDouble().clamp(0, _adb.maxVolume.toDouble()),
                    min: 0,
                    max: _adb.maxVolume.toDouble(),
                    onChanged: (val) {
                      setState(() {
                        _adb.currentVolume = val.toInt();
                      });
                      _adb.setVolume(val.toInt());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. "Now Playing" Media Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adb.currentMediaTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _adb.currentMediaArtist,
                        style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 18, color: Colors.white70),
                      onPressed: () => _adb.mediaPrevious(),
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _adb.isMediaPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          await _adb.mediaPlayPause();
                          setState(() {});
                        },
                        splashRadius: 14,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 18, color: Colors.white70),
                      onPressed: () => _adb.mediaNext(),
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF60A5FA) : const Color(0xFF334155),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
