# Open Android DeX — Development Roadmap & Actionable Issues

> **Document Version:** 1.0.0  
> **Status:** Planning & Contributor Guide  
> **Maintainer Approval Status:** Proposals Prepared for Review (No issues automatically created)  

---

## Table of Contents

1. [Strategic Roadmap (6 Pillars)](#1-strategic-roadmap-6-pillars)
   - [Pillar 1: Stability & Core Bug Fixes](#pillar-1-stability--core-bug-fixes)
   - [Pillar 2: Linux Integration & Wayland / X11 Support](#pillar-2-linux-integration--wayland--x11-support)
   - [Pillar 3: Android Companion Development](#pillar-3-android-companion-development)
   - [Pillar 4: Desktop Experience & Window Management](#pillar-4-desktop-experience--window-management)
   - [Pillar 5: Testing, Benchmarking & Device Compatibility](#pillar-5-testing-benchmarking--device-compatibility)
   - [Pillar 6: Packaging & Distribution](#pillar-6-packaging--distribution)
2. [Actionable GitHub Issue Proposals](#2-actionable-github-issue-proposals)
   - [Issue 1 (Beginner): Add Package Name Validation in ADB Client](#issue-1-beginner-add-package-name-validation-in-adb-client)
   - [Issue 2 (Beginner): Support Custom Dark / Light Theme Switching in Taskbar](#issue-2-beginner-support-custom-dark--light-theme-switching-in-taskbar)
   - [Issue 3 (Intermediate): Implement Host-to-Device Bi-Directional Clipboard Sync](#issue-3-intermediate-implement-host-to-device-bi-directional-clipboard-sync)
   - [Issue 4 (Intermediate): Audio Forwarding Pipeline via PulseAudio / PipeWire](#issue-4-intermediate-audio-forwarding-pipeline-via-pulseaudio--pipewire)
   - [Issue 5 (Intermediate): Implement Companion TCP Client in Flutter Shell](#issue-5-intermediate-implement-companion-tcp-client-in-flutter-shell)
   - [Issue 6 (Intermediate): Dynamic Virtual Display Density (DPI) Slider](#issue-6-intermediate-dynamic-virtual-display-density-dpi-slider)
   - [Issue 7 (Advanced): Hardware-Accelerated VA-API / NVDEC Video Decoding in Native C++](#issue-7-advanced-hardware-accelerated-va-api--nvdec-video-decoding-in-native-c)
   - [Issue 8 (Intermediate): Multi-Monitor Desktop Workspace Routing](#issue-8-intermediate-multi-monitor-desktop-workspace-routing)
   - [Issue 9 (Beginner): Mock ADB Service for Flutter Widget Tests](#issue-9-beginner-mock-adb-service-for-flutter-widget-tests)
   - [Issue 10 (Intermediate): AppImage & Flatpak Packaging Manifests](#issue-10-intermediate-appimage--flatpak-packaging-manifests)
   - [Issue 11 (Advanced): Direct Scrcpy Control Socket Touch Injection](#issue-11-advanced-direct-scrcpy-control-socket-touch-injection)
   - [Issue 12 (Beginner): Update Python Monogram Generator for Multi-Language Labels](#issue-12-beginner-update-python-monogram-generator-for-multi-language-labels)

---

## 1. Strategic Roadmap (6 Pillars)

### Pillar 1: Stability & Core Bug Fixes
* **Near Term**: Eliminate unhandled exceptions in background worker threads, harden intent argument tokenization, and ensure robust process cleanup when closing windows.
* **Medium Term**: Add automatic reconnect and session state recovery when physical USB cables are disconnected and re-attached.

### Pillar 2: Linux Integration & Wayland / X11 Support
* **Near Term**: Full Wayland compatibility under Hyprland, Sway, GNOME Shell, and KDE Plasma.
* **Medium Term**: Host system tray integration (`appindicator` / `libayatana`) and freedesktop `.desktop` application shortcuts.

### Pillar 3: Android Companion Development
* **Near Term**: Complete Gradle standalone build setup for `android_companion`, compile debug APKs, and implement local loopback client connection from desktop.
* **Medium Term**: Media playback control (play/pause/skip) through `MediaSessionManager` and active volume level synchronization.

### Pillar 4: Desktop Experience & Window Management
* **Near Term**: Snapping to screen edges (left half, right half, maximize), window minimization tray in taskbar, keyboard shortcut manager.
* **Medium Term**: Multi-app split screen, custom desktop wallpapers, widget support (clock, weather, system telemetry).

### Pillar 5: Testing, Benchmarking & Device Compatibility
* **Near Term**: Expand unit test coverage across all Python modules to >90%, introduce Flutter mock services.
* **Medium Term**: Matrix testing across Android 10 through Android 16 with diverse physical manufacturers (Motorola, Samsung, Google Pixel, Xiaomi, OnePlus).

### Pillar 6: Packaging & Distribution
* **Near Term**: GitHub Actions automated release pipeline producing `.tar.gz` and `.deb` binaries.
* **Medium Term**: Official Flatpak distribution on Flathub and Arch User Repository (`aur/open-android-dex`) package.

---

## 2. Actionable GitHub Issue Proposals

### Issue 1 (Beginner): Add Package Name Validation in ADB Client
* **Title:** `[Enhancement]: Validate Android package and component names before shell execution`
* **Problem Description:**  
  Currently, `AdbClient.start_component()` and `launchAppOnDevice()` accept arbitrary string identifiers and concatenate them into ADB shell commands. While internal calls use sanitized names, malformed or untrusted input could cause unexpected behavior.
* **Expected Outcome:**  
  Package names are validated against regex `^[a-zA-Z0-9_.]+$` before invoking ADB, raising `ValueError` on invalid syntax.
* **Relevant Files:** [`adb_client.py`](file:///root/open-android-dex/adb_client.py), [`lib/services/adb_service.dart`](file:///root/open-android-dex/lib/services/adb_service.dart)
* **Acceptance Criteria:**
  - [ ] Regex validation implemented in `AdbClient.start_component` and `AdbService.launchAppOnDevice`.
  - [ ] Unit tests added in `tests/test_adb_client.py` asserting invalid strings are rejected.
* **Estimated Difficulty:** ⭐ Very Easy (Good First Issue)
* **Suggested Labels:** `good first issue`, `security`, `python`

---

### Issue 2 (Beginner): Support Custom Dark / Light Theme Switching in Taskbar
* **Title:** `[Feature]: Add theme switching capability to Quick Settings panel`
* **Problem Description:**  
  The desktop taskbar and quick settings panel are hardcoded to dark ambient colors (`#0F172A`). Users on brighter monitors have requested an option to toggle between Dark and Obsidian themes.
* **Expected Outcome:**  
  A quick-setting toggle in `QuickSettingsPanel` allowing users to alternate between Dark Mode and High-Contrast Black.
* **Relevant Files:** [`lib/widgets/quick_settings_panel.dart`](file:///root/open-android-dex/lib/widgets/quick_settings_panel.dart), [`lib/widgets/desktop_taskbar.dart`](file:///root/open-android-dex/lib/widgets/desktop_taskbar.dart)
* **Acceptance Criteria:**
  - [ ] Theme toggle icon added to `QuickSettingsPanel`.
  - [ ] State persisted across sessions using local configuration file.
* **Estimated Difficulty:** ⭐ Very Easy (Good First Issue)
* **Suggested Labels:** `good first issue`, `ui`, `flutter`

---

### Issue 3 (Intermediate): Implement Host-to-Device Bi-Directional Clipboard Sync
* **Title:** `[Feature]: Synchronize clipboard text bidirectionally between Linux host and Android`
* **Problem Description:**  
  Copying text on the Linux desktop does not currently propagate to the Android device clipboard automatically, requiring manual text injection.
* **Expected Outcome:**  
  When text is copied on the Linux host, it is synced to Android via `adb shell cmd clipboard set-text` or scrcpy clipboard channel, and vice versa.
* **Relevant Files:** [`lib/services/adb_service.dart`](file:///root/open-android-dex/lib/services/adb_service.dart), [`app.py`](file:///root/open-android-dex/app.py)
* **Acceptance Criteria:**
  - [ ] Text copied on Linux is accessible in Android's paste buffer.
  - [ ] Rate limiting / debouncing applied to avoid excessive ADB invocations.
* **Estimated Difficulty:** ⭐⭐ Medium
* **Suggested Labels:** `enhancement`, `desktop`, `flutter`

---

### Issue 4 (Intermediate): Audio Forwarding Pipeline via PulseAudio / PipeWire
* **Title:** `[Feature]: Enable Android audio streaming to host PipeWire/PulseAudio output`
* **Problem Description:**  
  Currently, `scrcpy` is launched with `--no-audio` in `ScrcpyStreamService` to reduce startup latency. Audio plays through the phone speaker rather than laptop speakers or headphones.
* **Expected Outcome:**  
  Audio is forwarded over scrcpy's native audio tunnel (`--audio-codec=opus` or `raw`) into host audio sinks with low latency.
* **Relevant Files:** [`lib/services/scrcpy_stream_service.dart`](file:///root/open-android-dex/lib/services/scrcpy_stream_service.dart), [`scrcpy_client.py`](file:///root/open-android-dex/scrcpy_client.py)
* **Acceptance Criteria:**
  - [ ] Configurable audio forwarding toggle in Quick Settings.
  - [ ] Audio latency measured below 100ms over USB connection.
  - [ ] Graceful fallback if host audio sink is unavailable.
* **Estimated Difficulty:** ⭐⭐ Medium
* **Suggested Labels:** `enhancement`, `audio`, `linux`

---

### Issue 5 (Intermediate): Implement Companion TCP Client in Flutter Shell
* **Title:** `[Feature]: Connect Flutter shell to CompanionServer on port 8888 for real-time notifications`
* **Problem Description:**  
  `android_companion` broadcasts real-time notifications over TCP port `8888`, but the Flutter shell currently polls `adb shell dumpsys notification` every few seconds.
* **Expected Outcome:**  
  `AdbService` forwards port `8888` (`adb forward tcp:8888 tcp:8888`) and establishes a persistent socket client, updating the notification center immediately when an event is received.
* **Relevant Files:** [`lib/services/adb_service.dart`](file:///root/open-android-dex/lib/services/adb_service.dart), [`lib/widgets/notification_center_dialog.dart`](file:///root/open-android-dex/lib/widgets/notification_center_dialog.dart)
* **Acceptance Criteria:**
  - [ ] Instant notification delivery (<50ms from phone trigger to desktop popup).
  - [ ] Automatic fallback to `dumpsys` polling if the companion app is not installed.
* **Estimated Difficulty:** ⭐⭐ Medium
* **Suggested Labels:** `feature`, `android`, `networking`

---

### Issue 6 (Intermediate): Dynamic Virtual Display Density (DPI) Slider
* **Title:** `[Feature]: Add adjustable DPI density slider for Android virtual displays`
* **Problem Description:**  
  Virtual displays are initialized with a static DPI of `240`. On high-resolution 4K or ultra-wide monitors, UI elements appear either too large or too small.
* **Expected Outcome:**  
  Users can select their preferred scaling density (160 DPI to 480 DPI) per window or globally from Quick Settings.
* **Relevant Files:** [`lib/services/scrcpy_stream_service.dart`](file:///root/open-android-dex/lib/services/scrcpy_stream_service.dart), [`lib/widgets/quick_settings_panel.dart`](file:///root/open-android-dex/lib/widgets/quick_settings_panel.dart)
* **Acceptance Criteria:**
  - [ ] DPI argument passed dynamically to `--new-display=<w>x<h>/<dpi>`.
  - [ ] Virtual display restarts with updated scaling cleanly.
* **Estimated Difficulty:** ⭐⭐ Medium
* **Suggested Labels:** `enhancement`, `ui`, `flutter`

---

### Issue 7 (Advanced): Hardware-Accelerated VA-API / NVDEC Video Decoding in Native C++
* **Title:** `[Optimization]: Implement VA-API / NVDEC hardware acceleration in stream_texture.cc`
* **Problem Description:**  
  Currently, `linux/stream_texture.cc` uses CPU software decoding via `avcodec_find_decoder(AV_CODEC_ID_H264)`. On resource-constrained laptops, running 3 concurrent floating windows increases CPU load.
* **Expected Outcome:**  
  Detect and initialize hardware acceleration (`av_hwdevice_ctx_create` with `AV_HWDEVICE_TYPE_VAAPI` or `CUDA/NVDEC`), falling back to software decoding if hardware decoders are missing.
* **Relevant Files:** [`linux/stream_texture.cc`](file:///root/open-android-dex/linux/stream_texture.cc), [`linux/CMakeLists.txt`](file:///root/open-android-dex/linux/CMakeLists.txt)
* **Acceptance Criteria:**
  - [ ] CPU utilization decreases by >40% during 60 FPS video playback.
  - [ ] Automatic fallback to CPU if GPU driver does not support VA-API.
* **Estimated Difficulty:** ⭐⭐⭐ Advanced
* **Suggested Labels:** `performance`, `c++`, `ffmpeg`, `gpu`

---

### Issue 8 (Intermediate): Multi-Monitor Desktop Workspace Routing
* **Title:** `[Feature]: Allow dragging floating windows across multiple monitors or full-screen secondary display`
* **Problem Description:**  
  In multi-monitor Linux setups, Open Android DeX is currently confined to a single window canvas. Users want to project Android DeX onto an external monitor in dedicated fullscreen mode.
* **Expected Outcome:**  
  Option in taskbar to fullscreen the DeX canvas on a selected monitor (`GdkMonitor`).
* **Relevant Files:** [`linux/my_application.cc`](file:///root/open-android-dex/linux/my_application.cc), [`lib/views/dex_desktop_screen.dart`](file:///root/open-android-dex/lib/views/dex_desktop_screen.dart)
* **Acceptance Criteria:**
  - [ ] Monitor picker dialog detects all connected desktop displays.
  - [ ] Canvas moves seamlessly to target display.
* **Estimated Difficulty:** ⭐⭐ Medium
* **Suggested Labels:** `feature`, `linux`, `wayland`

---

### Issue 9 (Beginner): Mock ADB Service for Flutter Widget Tests
* **Title:** `[Test]: Implement MockAdbService to prevent pending timer errors in widget tests`
* **Problem Description:**  
  `test/widget_test.dart` encounters timer issues because `DexDesktopScreen` instantiates a real `AdbService` that starts `Timer.periodic`.
* **Expected Outcome:**  
  `DexDesktopScreen` accepts an optional `AdbService` interface or dependency-injected mock, enabling completely isolated headless widget tests.
* **Relevant Files:** [`test/widget_test.dart`](file:///root/open-android-dex/test/widget_test.dart), [`lib/services/adb_service.dart`](file:///root/open-android-dex/lib/services/adb_service.dart)
* **Acceptance Criteria:**
  - [ ] `flutter test` completes with 0 errors and no pending timers.
  - [ ] Mock allows testing connected, disconnected, and error states.
* **Estimated Difficulty:** ⭐ Easy
* **Suggested Labels:** `testing`, `good first issue`, `flutter`

---

### Issue 10 (Intermediate): AppImage & Flatpak Packaging Manifests
* **Title:** `[Packaging]: Create Flatpak manifest and AppImage build script for Linux distributions`
* **Problem Description:**  
  Users currently need to clone the repository and run developer scripts. Providing single-file AppImages or Flatpaks allows one-click execution on Ubuntu, Fedora, Arch, and SteamOS.
* **Expected Outcome:**  
  A working `org.openandroiddex.OpenAndroidDeX.yaml` Flatpak manifest bundled with required runtime dependencies (`scrcpy`, `adb`, `ffmpeg`).
* **Relevant Files:** Root directory, `.github/workflows/`
* **Acceptance Criteria:**
  - [ ] AppImage or Flatpak builds cleanly via GitHub Actions.
  - [ ] Successfully runs and discovers connected ADB devices on target distros.
* **Estimated Difficulty:** ⭐⭐ Medium
* **Suggested Labels:** `packaging`, `flatpak`, `ci/cd`

---

### Issue 11 (Advanced): Direct Scrcpy Control Socket Touch Injection
* **Title:** `[Optimization]: Replace adb shell input with direct scrcpy control socket protocol`
* **Problem Description:**  
  Mouse clicks in `EmbeddedStreamViewport` currently dispatch `adb shell input tap x y`. Spawning a new `adb` subprocess per click introduces ~30ms of latency and limits touch dragging smoothness.
* **Expected Outcome:**  
  Connect directly to scrcpy's control TCP socket on port `27183` and send binary control packets (`SC_CONTROL_MSG_TYPE_INJECT_TOUCH_EVENT`).
* **Relevant Files:** [`lib/services/touch_input_service.dart`](file:///root/open-android-dex/lib/services/touch_input_service.dart), [`lib/services/scrcpy_stream_service.dart`](file:///root/open-android-dex/lib/services/scrcpy_stream_service.dart)
* **Acceptance Criteria:**
  - [ ] Touch input latency reduced to <5ms.
  - [ ] Continuous dragging / gestures are buttery smooth without ADB subprocess queue saturation.
* **Estimated Difficulty:** ⭐⭐⭐ Advanced
* **Suggested Labels:** `optimization`, `networking`, `scrcpy`

---

### Issue 12 (Beginner): Update Python Monogram Generator for Multi-Language Labels
* **Title:** `[Bug]: Support Cyrillic, CJK, and accented Unicode strings in Python monogram generator`
* **Problem Description:**  
  [`app.py#L1022`](file:///root/open-android-dex/app.py#L1022) generates two-letter monograms by slicing ASCII strings (`words[0][:1] + words[1][:1]`). On devices with non-Latin app titles (Chinese, Japanese, Arabic, Russian), uppercase slicing can produce incomplete glyphs.
* **Expected Outcome:**  
  Use Python's `unicodedata` and grapheme cluster handling to generate clean monograms for international app titles.
* **Relevant Files:** [`app.py`](file:///root/open-android-dex/app.py), [`tests/test_app.py`](file:///root/open-android-dex/tests/test_app.py)
* **Acceptance Criteria:**
  - [ ] Unicode titles produce valid single-grapheme or dual-grapheme initials.
  - [ ] Unit tests added in `tests/test_app.py` validating international names.
* **Estimated Difficulty:** ⭐ Easy (Good First Issue)
* **Suggested Labels:** `good first issue`, `python`, `i18n`
