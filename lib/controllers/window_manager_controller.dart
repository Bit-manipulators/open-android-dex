import 'dart:math';
import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../models/dex_window.dart';
import '../services/scrcpy_stream_service.dart';

class WindowManagerController extends ChangeNotifier {
  final List<DexWindow> _windows = [];
  int _topZIndex = 1;
  String? _activeWindowId;

  List<DexWindow> get windows => List.unmodifiable(_windows);
  List<DexWindow> get openWindows =>
      _windows.where((w) => !w.isMinimized).toList();
  String? get activeWindowId => _activeWindowId;

  DexWindow? getWindow(String id) {
    try {
      return _windows.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  void openApp(AppInfo app, Size desktopSize) {
    // If already open, unminimize and bring to front
    final existing =
        _windows.where((w) => w.app.packageName == app.packageName).toList();
    if (existing.isNotEmpty) {
      final win = existing.first;
      win.isMinimized = false;
      bringToFront(win.id);
      notifyListeners();
      return;
    }

    // Open all windows in desktop display ratio (16:10 widescreen DeX desktop ratio)
    final rawW = min(desktopSize.width * 0.72, 1080.0).clamp(640.0, 1280.0);
    final winWidth = (rawW.toInt() & ~1).toDouble();
    // Inner video height is (winHeight - 40) for 38px titlebar + border
    final innerH = ((winWidth / 1.6).toInt() & ~1).clamp(400, 860);
    final winHeight = (innerH + 40).toDouble();

    // Stagger position based on number of windows
    final offset = (_windows.length % 5) * 30.0;
    final initialX = ((desktopSize.width - winWidth) / 2 + offset)
        .clamp(20.0, max(20.0, desktopSize.width - winWidth - 20))
        .toDouble();
    final initialY = ((desktopSize.height - winHeight - 60) / 2 + offset)
        .clamp(20.0, max(20.0, desktopSize.height - winHeight - 80))
        .toDouble();

    _topZIndex++;
    final newWin = DexWindow(
      id: 'win_${DateTime.now().millisecondsSinceEpoch}_${app.packageName}',
      app: app,
      x: initialX,
      y: initialY,
      width: winWidth,
      height: winHeight,
      zIndex: _topZIndex,
    );

    _windows.add(newWin);
    _activeWindowId = newWin.id;

    // Note: The app is launched directly onto the isolated virtual display via scrcpy --start-app
    notifyListeners();
  }

  void bringToFront(String id) {
    final win = getWindow(id);
    if (win == null) return;
    _topZIndex++;
    win.zIndex = _topZIndex;
    _activeWindowId = id;
    notifyListeners();
  }

  void closeWindow(String id) {
    final win = getWindow(id);
    if (win != null) {
      try {
        win.scrcpyProcess?.kill();
        ScrcpyStreamService().stopSession(id);
      } catch (_) {}
      _windows.remove(win);
      if (_activeWindowId == id) {
        final remaining = openWindows;
        _activeWindowId = remaining.isNotEmpty ? remaining.last.id : null;
      }
      notifyListeners();
    }
  }

  void minimizeWindow(String id) {
    final win = getWindow(id);
    if (win != null) {
      win.isMinimized = true;
      if (_activeWindowId == id) {
        final remaining = openWindows;
        _activeWindowId = remaining.isNotEmpty ? remaining.last.id : null;
      }
      notifyListeners();
    }
  }

  void toggleMinimize(String id) {
    final win = getWindow(id);
    if (win == null) return;
    if (win.isMinimized) {
      win.isMinimized = false;
      bringToFront(id);
    } else {
      if (_activeWindowId == id) {
        win.isMinimized = true;
        final remaining = openWindows;
        _activeWindowId = remaining.isNotEmpty ? remaining.last.id : null;
      } else {
        bringToFront(id);
      }
    }
    notifyListeners();
  }

  void toggleMaximize(String id, Size desktopSize) {
    final win = getWindow(id);
    if (win == null) return;

    if (win.isMaximized) {
      // Restore
      win.isMaximized = false;
      win.x = win.prevX;
      win.y = win.prevY;
      win.width = win.prevWidth;
      win.height = win.prevHeight;
    } else {
      // Maximize
      win.saveGeometry();
      win.isMaximized = true;
      win.x = 0;
      win.y = 0;
      win.width = (desktopSize.width.toInt() & ~1).toDouble();
      final maxH = max(100.0, desktopSize.height - 56.0); // leave taskbar space
      win.height = (maxH.toInt() & ~1).toDouble();
    }
    bringToFront(id);
    notifyListeners();
  }

  void snapLeft(String id, Size desktopSize) {
    final win = getWindow(id);
    if (win == null) return;
    if (win.isMaximized) win.isMaximized = false;
    win.saveGeometry();
    win.x = 0;
    win.y = 0;
    win.width = (desktopSize.width / 2).floorToDouble();
    win.height = max(100.0, desktopSize.height - 52.0);
    bringToFront(id);
    notifyListeners();
  }

  void snapRight(String id, Size desktopSize) {
    final win = getWindow(id);
    if (win == null) return;
    if (win.isMaximized) win.isMaximized = false;
    win.saveGeometry();
    final halfW = (desktopSize.width / 2).floorToDouble();
    win.x = halfW;
    win.y = 0;
    win.width = desktopSize.width - halfW;
    win.height = max(100.0, desktopSize.height - 52.0);
    bringToFront(id);
    notifyListeners();
  }

  void snapTopLeft(String id, Size desktopSize) {
    final win = getWindow(id);
    if (win == null) return;
    if (win.isMaximized) win.isMaximized = false;
    win.saveGeometry();
    final halfW = (desktopSize.width / 2).floorToDouble();
    final halfH = ((desktopSize.height - 52.0) / 2).floorToDouble();
    win.x = 0;
    win.y = 0;
    win.width = halfW;
    win.height = halfH;
    bringToFront(id);
    notifyListeners();
  }

  void snapTopRight(String id, Size desktopSize) {
    final win = getWindow(id);
    if (win == null) return;
    if (win.isMaximized) win.isMaximized = false;
    win.saveGeometry();
    final halfW = (desktopSize.width / 2).floorToDouble();
    final halfH = ((desktopSize.height - 52.0) / 2).floorToDouble();
    win.x = halfW;
    win.y = 0;
    win.width = desktopSize.width - halfW;
    win.height = halfH;
    bringToFront(id);
    notifyListeners();
  }

  void updatePosition(String id, double dx, double dy, Size desktopSize) {
    final win = getWindow(id);
    if (win == null || win.isMaximized) return;

    win.x = (win.x + dx).clamp(0.0, max(0.0, desktopSize.width - 80));
    win.y = (win.y + dy).clamp(0.0, max(0.0, desktopSize.height - 100));
    notifyListeners();
  }

  void resize(
    String id, {
    double? left,
    double? top,
    double? width,
    double? height,
    required Size desktopSize,
  }) {
    final win = getWindow(id);
    if (win == null || win.isMaximized) return;

    const minW = 320.0;
    const minH = 380.0;

    if (left != null && width != null) {
      if (width >= minW && left >= 0) {
        win.x = left;
        win.width = width;
      }
    } else if (width != null) {
      win.width = width.clamp(minW, desktopSize.width - win.x);
    }

    if (top != null && height != null) {
      if (height >= minH && top >= 0) {
        win.y = top;
        win.height = height;
      }
    } else if (height != null) {
      win.height = height.clamp(minH, desktopSize.height - 56.0 - win.y);
    }

    notifyListeners();
  }
}
