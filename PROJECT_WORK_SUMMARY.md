# Open Android DeX — Comprehensive Project & Reverse Engineering Report

This document compiles all reverse-engineering discoveries, architectural breakdowns, bug fixes, and implementations completed for the **Open Android DeX** project.

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Target Environment & Connected Hardware](#target-environment--connected-hardware)
3. [Deep Reverse Engineering of `non_tracked_folder/`](#deep-reverse-engineering-of-non_tracked_folder)
   - [Desktop App (`dex_for_linux`)](#desktop-app-dex_for_linux)
   - [Native Pipeline (`librust_lib_android_dex.so`)](#native-pipeline-librust_lib_android_dexso)
   - [Android Companion (`Android Dex.apk` & Server JARs)](#android-companion-android-dexapk--server-jars)
   - [Display Modes: Native scrcpy vs. Virtual Display (`new_display`)](#display-modes-native-scrcpy-vs-virtual-display-new_display)
4. [Why Apps Were Opening on the Phone Instead of the Laptop](#why-apps-were-opening-on-the-phone-instead of the laptop)
5. [Python / GTK4 Implementation Overhaul (`app.py`)](#python--gtk4-implementation-overhaul-apppy)
6. [Flutter Desktop Implementation with Resizable Windows (`lib/`)](#flutter-desktop-implementation-with-resizable-windows-lib)
   - [Architecture & Module Layout](#architecture--module-layout)
   - [8-Direction Resizable Window Engine (`ResizableWindowFrame`)](#8-direction-resizable-window-engine-resizablewindowframe)
   - [Window Management & Z-Index Ordering (`WindowManagerController`)](#window-management--z-index-ordering-windowmanagercontroller)
   - [Samsung DeX Bottom Taskbar & App Drawer](#samsung-dex-bottom-taskbar--app-drawer)
7. [How to Run Both Applications](#how-to-run-both-applications)
   - [Running the Flutter Desktop Shell](#running-the-flutter-desktop-shell)
   - [Running the Python / GTK4 Shell](#running-the-python--gtk4-shell)
   - [Running the Reference Reverse-Engineered Build](#running-the-reference-reverse-engineered-build)
   - [Direct Scrcpy Hardware-Accelerated Commands](#direct-scrcpy-hardware-accelerated-commands)

---

## 1. Executive Summary
The primary goals addressed in this session:
1. **Reverse Engineer `non_tracked_folder/`**: Dissected the compiled reference binaries (`Android_Dex_Linux_x64.AppImage`, `libapp.so`, `librust_lib_android_dex.so`, and server JARs) using REA and binary analysis to uncover how Samsung DeX-style floating windows, virtual displays, and video texture pipelines operate.
2. **Diagnose App Opening Bug**: Solved why clicking app icons was launching apps exclusively on the user's handheld phone rather than displaying and streaming onto the laptop monitor.
3. **Build a Native Flutter Desktop GUI with Resizable Windows**: Implemented a complete Flutter desktop environment inside `lib/` featuring draggable, 8-way resizable window frames, Samsung DeX taskbar, ADB device synchronization, and scrcpy display mirroring.
4. **Fix the Legacy GTK4 Shell (`app.py`)**: Resolved vertical icon clipping, updated deprecated CSS context providers, and fixed scrcpy 5.0.1 CLI argument incompatibility (`--bit-rate` → `-b`).

---

## 2. Target Environment & Connected Hardware
- **Host OS**: Linux (Arch Linux x86_64, Kernel 7.2.11)
- **Display Server**: Wayland with Hyprland Compositor (`DISPLAY=:1`, `WAYLAND_DISPLAY=wayland-1`)
- **Connected Physical Device**: Motorola moto g54 5G (`ZD222H7659`)
- **Android Platform**: Android 16 (API Level 36)
- **Scrcpy Version**: `scrcpy 5.0.1` (`/usr/bin/scrcpy`)
- **Flutter SDK**: Flutter 3.24.5 (Dart 3.5.4) at `/home/amit/development/flutter`

---

## 3. Deep Reverse Engineering of `non_tracked_folder/`

### Desktop App (`dex_for_linux`)
The reference application is a compiled Flutter/Dart Linux desktop application:
- Main binary: `usr/bin/Android_Dex`
- Flutter assets: `usr/bin/data/flutter_assets`
- Compiled Dart kernel: `usr/lib/libapp.so`

Key reverse-engineered Dart modules in `package:android_dex/`:
- `core/floating_app_wrapper/floating_wrapper.dart`: Manages individual floating app window frames on the desktop canvas.
- `core/floating_app_wrapper/window_geometry.dart`: Tracks `(x, y, width, height)` and handles resizing.
- `core/floating_app_wrapper/window_title_bar.dart`: Renders app icons, titles, and minimize/maximize/close actions.
- `core/window_manager.dart`: Coordinates z-index and active focused window state.
- `Scrcpy/scrcpy_service.dart` & `Scrcpy/scrcpy_video_manager.dart`: Manages ADB daemon connections and texture binding.

### Native Pipeline (`librust_lib_android_dex.so`)
The reference application does not use external window popups; it renders the phone screen directly into Flutter widgets using a custom Rust pipeline:
```
┌────────────────────────────┐
│ Android Phone (ADB Daemon) │
└─────────────┬──────────────┘
              │ TCP Socket (H.264 / H.265 stream)
              ▼
┌────────────────────────────┐
│ librust_lib_android_dex.so │
│  - Tokio async socket      │
│  - FFmpeg (libavcodec)     │
│  - yuv_to_rgba420          │
│  - irondash_texture        │
└─────────────┬──────────────┘
              │ Texture ID (int64)
              ▼
┌────────────────────────────┐
│ Flutter Desktop Engine     │
│  - Texture(textureId: ...) │
│  - Control Socket events   │
└────────────────────────────┘
```
1. **Video Streaming**: Connects to the local TCP port forwarded by ADB from the phone's scrcpy-server.
2. **Decoding**: Passes video packets into FFmpeg `AVCodecContext` using VA-API hardware acceleration with CPU software fallback.
3. **Texture Registration**: Decoded RGBA frames are copied into a Flutter pixel buffer texture registered via `irondash_texture`.
4. **Input Injection**: Mouse clicks and drag movements on the Flutter widget are converted to scrcpy touch protocol packets (`scrcpy_send_touch`) and dispatched over the control socket.

### Android Companion (`Android Dex.apk` & Server JARs)
Inside `usr/share/Android_Dex/Build_copy/`:
- `AndroidDex-main-server.jar`: Customized `scrcpy-server` (version 3.3.4).
- `AndroidDex-screen-server.jar`: Virtual display and screen-casting daemon.
- `AndroidDex-companion-server.jar`: Java/Kotlin daemon executed via `app_process` (`com.shrey.androiddex.server.Main`) for volume control, app listings, and system state telemetry.

### Display Modes: Native scrcpy vs. Virtual Display (`new_display`)
The reference application contains two operational modes discovered in `libapp.so`:
1. **Standalone Window Mode**:
   > *"Launches apps directly using scrcpy.exe as a standalone process. Simpler but opens as a native OS window outside the desktop."*
2. **Virtual Display Mode (`new_display`)**:
   > *"Experimental: Launch apps with a flexible window that can be resized on the fly. Best for multitasking..."*
   Command pattern used:
   ```bash
   app_process / com.shrey.re_size_scrcpy.Server 3.3.3 \
     new_display=576x1376/270:r2 \
     vd_system_decorations=false \
     scid=... tunnel_forward=true stay_awake=true \
     video_encoder=c2.android.avc.encoder video_bit_rate=9000000 max_size=1920 max_fps=60
   ```
   When `new_display` is supplied, Android creates an **independent virtual display** inside Android WindowManager. The physical phone screen is never activated; the app renders exclusively to the virtual buffer streamed to the PC.

---

## 4. Why Apps Were Opening on the Phone Instead of the Laptop
In both the original Python GTK implementation and early iterations of the GUI:
1. Clicking an app tile invoked `adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1` or `am start`.
2. This told Android to launch the app on **Display 0** (the physical phone screen).
3. On the laptop, the GUI was either running without an active scrcpy process or was displaying a static placeholder card (`Container` with icon and text fields) instead of establishing a video stream.
4. **Resolution**:
   - To show apps in external floating windows on the laptop: Launch `scrcpy -s <serial> --start-app=<package> --turn-screen-off --always-on-top`.
   - To show apps inside a virtual display: Supply `--new-display=<w>x<h>/<dpi>` so Android does not wake or display the app on the physical phone screen.

---

## 5. Python / GTK4 Implementation Overhaul (`app.py`)
Key fixes applied to the GTK4 application:
1. **Icon Clipping Fix**:
   - Replaced collapsed `center.set_valign(Gtk.Align.CENTER)` container with `Gtk.Align.FILL` and added `min_content_height(400)` with `vexpand=True` on `ScrolledWindow`, completely resolving the sliced half-circle bug.
2. **Modern Visual System**:
   - Configured 60×60 rounded squircle app badges with 12 distinct linear gradient themes.
   - Built an intelligent package name resolver that maps Android package IDs (e.g. `com.google.android.gm` → "Gmail", `com.ubercab` → "Uber", `com.anthropic.claude` → "Claude").
3. **scrcpy 5.0.1 Parameter Updates in `scrcpy_client.py`**:
   - Changed deprecated `--bit-rate` argument to `-b` / `--video-bit-rate`. (scrcpy 5.0.1 exits immediately if `--bit-rate` is passed).
   - Added `--always-on-top`, `--stay-awake`, and `--no-window-aspect-ratio-lock`.

---

## 6. Flutter Desktop Implementation with Resizable Windows (`lib/`)

### Architecture & Module Layout
A native Linux Flutter desktop application was created in the repository root:
```
lib/
├── controllers/
│   └── window_manager_controller.dart  # Window state, z-index, maximize/restore logic
├── models/
│   ├── app_info.dart                   # Package metadata, icons, gradients, categories
│   └── dex_window.dart                 # Geometry (x, y, w, h), saved state, process link
├── services/
│   └── adb_service.dart                # ADB bridge, device polling, scrcpy runner
├── views/
│   └── dex_desktop_screen.dart         # Main desktop shell with wallpaper & window stack
├── widgets/
│   ├── app_drawer_dialog.dart          # Slide-up search & application grid
│   ├── desktop_taskbar.dart            # Samsung DeX bottom taskbar & status indicators
│   └── resizable_window_frame.dart     # 8-direction resize handles & window controls
└── main.dart                           # Flutter app entry point & dark theme setup
```

### 8-Direction Resizable Window Engine (`ResizableWindowFrame`)
Windows are rendered inside a desktop `Stack` as `Positioned` widgets.
- **Title Bar**:
  - App icon with gradient badge and title.
  - Quick Android navigation controls (Back, Home, Recents).
  - Minimize (`_`), Maximize/Restore (`□` / `❐`), and Close (`✕`) buttons.
  - Pan gesture tracking for smooth dragging across the desktop.
  - Double-tap title bar to toggle maximize/restore.
- **8 Resize Handles**:
  - Top, Bottom, Left, Right borders.
  - Top-Left, Top-Right, Bottom-Left, Bottom-Right corners.
  - Dynamic `MouseCursor` updates (`resizeUpDown`, `resizeLeftRight`, `resizeUpLeftDownRight`, `resizeUpRightDownLeft`).
  - Minimum window constraints enforced (`minWidth: 320`, `minHeight: 380`).

### Window Management & Z-Index Ordering (`WindowManagerController`)
- Maintains an ordered list of `DexWindow` instances.
- Active window focus: Clicking anywhere on a window elevates its `zIndex` and draws an active accent border and drop shadow.
- Staggered cascading positions when multiple windows are opened.

### Samsung DeX Bottom Taskbar & App Drawer
- **Taskbar (`desktop_taskbar.dart`)**:
  - 9-dot launcher button to toggle the app drawer.
  - Hardware Android navigation bar (Back, Home, Recent Apps).
  - Active running window pills with green state indicators.
  - Device status capsule: Phone model, live battery %, charging status bolt, formatted clock and date.
- **App Drawer (`app_drawer_dialog.dart`)**:
  - Live search bar with instant query filtering.
  - Category filter pills (All, Tools, Media, Social, System).
  - High-DPI application grid.

---

## 7. How to Run Both Applications

### Running the Flutter Desktop Shell
A launcher script `run_flutter_dex.sh` is provided in the repository:
```bash
cd /home/amit/github/ID2/open-android-dex
./run_flutter_dex.sh
```
Or run directly via Flutter:
```bash
/home/amit/development/flutter/bin/flutter run -d linux
```

### Running the Python / GTK4 Shell
```bash
cd /home/amit/github/ID2/open-android-dex
python3 app.py
```

### Running the Reference Reverse-Engineered Build
To run the pre-built reference application from `non_tracked_folder`:
```bash
cd /home/amit/github/ID2/open-android-dex
./non_tracked_folder/dex_for_linux/run_android_dex.sh
```

### Direct Scrcpy Hardware-Accelerated Commands
To launch specific apps directly as standalone floating windows on your laptop display with the phone screen off:
```bash
# Calculator
scrcpy -s ZD222H7659 --start-app=com.google.android.calculator --turn-screen-off --always-on-top

# Chrome
scrcpy -s ZD222H7659 --start-app=com.android.chrome --turn-screen-off --always-on-top

# YouTube
scrcpy -s ZD222H7659 --start-app=com.google.android.youtube --turn-screen-off --always-on-top

# Virtual Display Mode (Display ID created on Android, phone screen untouched)
scrcpy -s ZD222H7659 --new-display=720x1280/240 --start-app=com.google.android.calculator --always-on-top
```
