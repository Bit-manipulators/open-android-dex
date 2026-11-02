import 'dart:io';
import 'app_info.dart';

class DexWindow {
  final String id;
  final AppInfo app;
  double x;
  double y;
  double width;
  double height;
  bool isMinimized;
  bool isMaximized;

  // Saved coordinates before maximize
  double prevX;
  double prevY;
  double prevWidth;
  double prevHeight;

  int zIndex;
  Process? scrcpyProcess;
  bool isScrcpyActive;

  DexWindow({
    required this.id,
    required this.app,
    this.x = 100,
    this.y = 80,
    this.width = 420,
    this.height = 680,
    this.isMinimized = false,
    this.isMaximized = false,
    this.prevX = 100,
    this.prevY = 80,
    this.prevWidth = 420,
    this.prevHeight = 680,
    this.zIndex = 0,
    this.scrcpyProcess,
    this.isScrcpyActive = false,
  });

  void saveGeometry() {
    prevX = x;
    prevY = y;
    prevWidth = width;
    prevHeight = height;
  }
}
