import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/scrcpy_stream_service.dart';

/// Modern dialog allowing users to set custom scrcpy resolution and DPI,
/// or pick from popular widescreen and portrait presets.
class DisplayResolutionDialog extends StatefulWidget {
  final VoidCallback? onApplied;

  const DisplayResolutionDialog({super.key, this.onApplied});

  static Future<void> show(BuildContext context,
      {VoidCallback? onApplied}) async {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => DisplayResolutionDialog(onApplied: onApplied),
    );
  }

  @override
  State<DisplayResolutionDialog> createState() =>
      _DisplayResolutionDialogState();
}

class _DisplayResolutionDialogState extends State<DisplayResolutionDialog> {
  final _streamService = ScrcpyStreamService();
  late ResolutionPreset _selectedPreset;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _dpiController;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _streamService.activePreset;
    _widthController = TextEditingController(
      text: _streamService.customWidth?.toString() ??
          _selectedPreset.width?.toString() ??
          '1920',
    );
    _heightController = TextEditingController(
      text: _streamService.customHeight?.toString() ??
          _selectedPreset.height?.toString() ??
          '1080',
    );
    _dpiController = TextEditingController(
      text: _streamService.customDpi?.toString() ??
          _selectedPreset.dpi?.toString() ??
          '240',
    );
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _dpiController.dispose();
    super.dispose();
  }

  void _onSelectPreset(ResolutionPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (!preset.isAuto && preset.width != null) {
        _widthController.text = preset.width.toString();
        _heightController.text = preset.height.toString();
        _dpiController.text = preset.dpi.toString();
      }
    });
  }

  void _applySettings() {
    int? customW = int.tryParse(_widthController.text.trim());
    int? customH = int.tryParse(_heightController.text.trim());
    int? customD = int.tryParse(_dpiController.text.trim());

    if (customW != null) customW = (customW & ~1).clamp(360, 3840);
    if (customH != null) customH = (customH & ~1).clamp(360, 3840);
    if (customD != null) customD = customD.clamp(100, 640);

    _streamService.setResolutionPreset(
      _selectedPreset,
      customW: customW,
      customH: customH,
      customD: customD,
    );

    widget.onApplied?.call();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selectedPreset.id == 'custom';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 520, maxWidth: 500),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF131722).withOpacity(0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2B384E),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 36,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Close Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.aspect_ratio_rounded,
                                color: Color(0xFF38BDF8),
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Display Resolution & DPI',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Configure scrcpy virtual display resolution and density presets for desktop or phone views.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 18),

                    // Presets Chips Grid
                    const Text(
                      'RESOLUTION PRESETS',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ScrcpyStreamService.presets.map((p) {
                        final isSelected = _selectedPreset.id == p.id;
                        return ChoiceChip(
                          label: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E2638),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2A364E),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          onSelected: (_) => _onSelectPreset(p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Custom Width, Height, and DPI Fields (enabled always or when custom selected)
                    const Text(
                      'CUSTOM VALUES',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Width (px)',
                            controller: _widthController,
                            hint: '1920',
                            enabled: isCustom || !_selectedPreset.isAuto,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Height (px)',
                            controller: _heightController,
                            hint: '1080',
                            enabled: isCustom || !_selectedPreset.isAuto,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'DPI Density',
                            controller: _dpiController,
                            hint: '240',
                            enabled: isCustom || !_selectedPreset.isAuto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions: Reset & Apply
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _streamService.clearCustomResolution();
                            setState(() {
                              _selectedPreset = ScrcpyStreamService.presets[0];
                              _widthController.text = '1920';
                              _heightController.text = '1080';
                              _dpiController.text = '240';
                            });
                          },
                          child: const Text(
                            'Reset to Auto',
                            style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _applySettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Apply & Stream',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
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
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0xFF64748B),
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            isDense: true,
            filled: true,
            fillColor:
                enabled ? const Color(0xFF1E2638) : const Color(0xFF161C2A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A364E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
