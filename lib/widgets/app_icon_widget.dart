import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_info.dart';

class AppIconWidget extends StatelessWidget {
  final AppInfo app;
  final double size;
  final double? iconSize;
  final double borderRadius;
  final bool showShadow;

  const AppIconWidget({
    super.key,
    required this.app,
    this.size = 48,
    this.iconSize,
    this.borderRadius = 12,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? (size * 0.52);

    final path = app.iconPath;
    final hasRealIcon = path != null && path.isNotEmpty && File(path).existsSync();

    if (hasRealIcon) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: size * 0.2,
                    offset: Offset(0, size * 0.08),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(effectiveIconSize),
          ),
        ),
      );
    }

    return _buildFallback(effectiveIconSize);
  }

  Widget _buildFallback(double effIconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: app.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: app.gradientColors.first.withOpacity(0.35),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          app.icon,
          size: effIconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
