import 'dart:io';
import 'package:flutter/material.dart';

/// Interactive taskbar battery capsule featuring an animated emerald-to-mint
/// charging pulse, lightning indicator badge, and alert states for low battery (< 20%).
class TaskbarBatteryCapsule extends StatefulWidget {
  final int batteryLevel;
  final bool isCharging;
  final bool animateInTest;

  const TaskbarBatteryCapsule({
    super.key,
    required this.batteryLevel,
    required this.isCharging,
    this.animateInTest = false,
  });

  @override
  State<TaskbarBatteryCapsule> createState() => _TaskbarBatteryCapsuleState();
}

class _TaskbarBatteryCapsuleState extends State<TaskbarBatteryCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _colorAnimation = ColorTween(
      begin: const Color(0xFF10B981), // Emerald
      end: const Color(0xFF34D399), // Mint
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _syncAnimation();
  }

  void _syncAnimation() {
    final isTesting = Platform.environment.containsKey('FLUTTER_TEST') &&
        !widget.animateInTest;
    if (widget.isCharging && !isTesting) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0.5; // Midpoint between Emerald and Mint
    }
  }

  @override
  void didUpdateWidget(TaskbarBatteryCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCharging != oldWidget.isCharging ||
        widget.animateInTest != oldWidget.animateInTest) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLow = widget.batteryLevel < 20 && !widget.isCharging;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final Color activeColor;
        if (widget.isCharging) {
          activeColor = _colorAnimation.value ?? const Color(0xFF10B981);
        } else if (isLow) {
          activeColor = const Color(0xFFEF4444); // Red (< 20%)
        } else {
          activeColor = const Color(0xFF34D399); // Mint
        }

        final double scale = widget.isCharging ? _pulseAnimation.value : 1.0;

        final IconData iconData;
        if (widget.isCharging) {
          iconData = Icons.battery_charging_full_rounded;
        } else if (isLow) {
          iconData = Icons.battery_alert_rounded;
        } else {
          iconData = Icons.battery_full_rounded;
        }

        final String tooltipMessage;
        if (widget.isCharging) {
          tooltipMessage = 'Battery: ${widget.batteryLevel}% (Charging)';
        } else if (isLow) {
          tooltipMessage = 'Battery: ${widget.batteryLevel}% (Low Battery)';
        } else {
          tooltipMessage = 'Battery: ${widget.batteryLevel}%';
        }

        return Tooltip(
          message: tooltipMessage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF172033),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isCharging
                    ? activeColor.withOpacity(0.4)
                    : (isLow
                        ? const Color(0xFFEF4444).withOpacity(0.5)
                        : const Color(0xFF2D3C5C)),
              ),
              boxShadow: widget.isCharging
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Icon(
                    iconData,
                    size: 14,
                    color: activeColor,
                  ),
                ),
                if (widget.isCharging) ...[
                  const SizedBox(width: 3),
                  Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: activeColor,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Text(
                  '${widget.batteryLevel}%',
                  style: TextStyle(
                    color: isLow
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFE2E8F0),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
