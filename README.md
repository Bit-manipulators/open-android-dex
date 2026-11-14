# Open Android DeX

[![CI](https://github.com/Bit-manipulators/open-android-dex/actions/workflows/ci.yml/badge.svg)](https://github.com/Bit-manipulators/open-android-dex/actions)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Platform: Linux & Windows 11](https://img.shields.io/badge/Platform-Linux%20(X11%20%7C%20Wayland)%20%7C%20Windows%2011-teal.svg)](#system-requirements)
[![Packaging: AppImage & Setup](https://img.shields.io/badge/Packages-AppImage%20%7C%20Setup.exe%20%7C%20Portable-orange.svg)](#installation--release-packages)
[![Android: 10 - 16](https://img.shields.io/badge/Android-API%2029--36-green.svg)](#android-device-support)
[![Good First Issues](https://img.shields.io/badge/PRs-Welcome-brightgreen.svg)](docs/GOOD_FIRST_ISSUES.md)
[![Dev Containers](https://img.shields.io/badge/Dev%20Containers-Ready-blue.svg)](.devcontainer)

An open-source desktop environment that transforms your Android smartphone or tablet into a multi-window workstation under **Windows 11** and **Linux** (Wayland and X11) — featuring resizable floating windows, an interactive DeX taskbar, app drawer, low-latency screen streaming, and keyboard/mouse/touchpad input mapping.

<p align="center">
  <a href="https://github.com/Bit-manipulators/open-android-dex/releases/latest/download/Open-Android-DeX-Linux-x86_64.AppImage">
    <img src="https://img.shields.io/badge/Download%20for-Linux%20AppImage-2ea44f?style=for-the-badge&logo=linux&logoColor=white&labelColor=24292f" alt="Download Open Android DeX for Linux" />
  </a>
  <a href="https://github.com/Bit-manipulators/open-android-dex/releases/latest/download/Open-Android-DeX-Windows-x64-Setup.exe">
    <img src="https://img.shields.io/badge/Download%20for-Windows%2011-0078d4?style=for-the-badge&logo=windows&logoColor=white&labelColor=24292f" alt="Download Open Android DeX for Windows 11" />
  </a>
  <a href="https://github.com/Bit-manipulators/open-android-dex/releases/latest">
    <img src="https://img.shields.io/badge/All%20Releases-v2.0.2-informational?style=for-the-badge&logo=github&logoColor=white&labelColor=24292f" alt="View All Releases" />
  </a>
</p>

<p align="center">
  <img src="video_and_screenshorts/open_android_dex_demo.gif" alt="Open Android DeX Live Demo" width="100%" style="border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,0.5);" />
</p>

<p align="center">
  <img src="video_and_screenshorts/open_android_dex_screenshort.png" alt="Open Android DeX Clean Multi-Window Desktop Workspace" width="100%" style="border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,0.5);" />
</p>
<p align="center">
  <em>True multi-window Android desktop workstation on Linux — floating resizable apps, taskbar, and quick settings with zero system bar clutter.</em>
</p>

---

## 📑 Table of Contents

- [Overview & Goals](#overview--goals)
- [Installation & Release Packages](#-installation--release-packages)
  - [Windows 11 (Installer & Portable)](#-windows-11-x64)
  - [Linux (Portable AppImage)](#-linux-x86_64-appimage)
- [Feature Status Matrix](#feature-status-matrix)
- [Architecture & Shell Options](#architecture--shell-options)
  - [1. Flutter Desktop Compositor (Primary: Linux & Windows 11)](#1-flutter-desktop-compositor-primary-linux--windows-11)
  - [2. Python / GTK4 Shell (Lightweight Fallback: Linux)](#2-python--gtk4-shell-lightweight-fallback-linux)
  - [3. Android Companion App](#3-android-companion-app)
- [System Requirements](#system-requirements)
  - [Windows 11 Host](#windows-11-host)
  - [Linux Host](#linux-host)
  - [Android Device Support](#android-device-support)
- [Quick Start Guide](#quick-start-guide)
  - [Running on Windows 11](#running-on-windows-11)
  - [Running the Linux AppImage](#running-the-linux-appimage)
  - [Building from Source](#building-from-source)
- [Testing & Quality Assurance](#testing--quality-assurance)
- [Provenance & Reverse-Engineering Transparency](#provenance--reverse-engineering-transparency)
- [Documentation & Contributing](#documentation--contributing)
- [License](#license)

---

## Overview & Goals

**Open Android DeX** aims to deliver a modern, multi-window desktop computing experience powered directly by your personal Android phone connected to a **Windows 11** or **Linux** laptop or external monitor.

### Key Project Objectives
* **True Multi-Window Workspace**: Float, drag, resize, maximize, and minimize independent Android applications across an expansive desktop canvas.
* **Low Latency & High Frame Rate**: Decode 60 FPS video streams in-process directly to GPU textures via hardware-accelerated pipelines.
* **Universal Desktop Support**: Native multi-window experience on both **Windows 11 (x64)** and **Linux** (Wayland & X11).
* **Clean-Room Open Source**: 100% original code licensed under GPL-3.0, without proprietary binaries, proprietary libraries, or vendor lock-in.
* **Dual Architecture Flexibility**: A modern, feature-rich Flutter compositor alongside an ultra-lightweight GTK4 shell.

---

## 📦 Installation & Release Packages

Precompiled, validated releases are distributed via [GitHub Releases](https://github.com/Bit-manipulators/open-android-dex/releases/latest):

### 🪟 Windows 11 (x64)
* **Installer:** [`Open-Android-DeX-Windows-x64-Setup.exe`](https://github.com/Bit-manipulators/open-android-dex/releases/latest/download/Open-Android-DeX-Windows-x64-Setup.exe) ([Direct v2.0.2 link](https://github.com/Bit-manipulators/open-android-dex/releases/download/v2.0.2/Open-Android-DeX-v2.0.2-Windows-x64-Setup.exe)) — Standard setup wizard with Desktop & Start Menu integration and uninstaller.
* **Portable Package:** [`Open-Android-DeX-Windows-x64-Portable.zip`](https://github.com/Bit-manipulators/open-android-dex/releases/latest/download/Open-Android-DeX-Windows-x64-Portable.zip) ([Direct v2.0.2 link](https://github.com/Bit-manipulators/open-android-dex/releases/download/v2.0.2/Open-Android-DeX-v2.0.2-Windows-x64-Portable.zip)) — Standalone folder; extract and launch `open_android_dex.exe` anywhere with zero installation.
* 📖 Detailed setup & driver instructions: [`docs/WINDOWS_SETUP.md`](docs/WINDOWS_SETUP.md)

### 🐧 Linux (x86_64 AppImage)
* **Portable AppImage:** [`Open-Android-DeX-Linux-x86_64.AppImage`](https://github.com/Bit-manipulators/open-android-dex/releases/latest/download/Open-Android-DeX-Linux-x86_64.AppImage) ([Direct v2.0.2 link](https://github.com/Bit-manipulators/open-android-dex/releases/download/v2.0.2/Open-Android-DeX-v2.0.2-Linux-x86_64.AppImage)) — Self-contained executable bundling all required Flutter and multimedia shared libraries.
  ```bash
  chmod +x Open-Android-DeX-Linux-x86_64.AppImage
  ./Open-Android-DeX-Linux-x86_64.AppImage
  ```
* 📖 Comprehensive guide & desktop integration: [`docs/APPIMAGE_GUIDE.md`](docs/APPIMAGE_GUIDE.md)

---

## Feature Status Matrix

| Feature | Status | Description |
| :--- | :--- | :--- |
| **Windows 11 (x64) Compositor** | ✅ **Implemented** | Native Win32 desktop runner, texture streaming, and bundled installer/portable packages |
| **Linux AppImage Distribution** | ✅ **Implemented** | Standalone portable bundle with Wayland and X11 support |
| **8-Way Window Resizing** | ✅ **Implemented** | Smooth edge and corner dragging with geometry persistence |
| **Z-Index Window Ordering** | ✅ **Implemented** | Active window elevation, focus switching, and drop shadows |
| **In-Process Video Textures** | ✅ **Implemented** | Hardware/multithreaded FFmpeg C-API decoding on Windows & Linux direct to GPU textures |
| **Trackpad & Touchpad Scrolling** | ✅ **Implemented** | Two-finger smooth scrolling and natural pan/zoom gestures |
| **DeX Bottom Taskbar** | ✅ **Implemented** | 9-dot launcher, Android navigation (Back, Home, Recents), clock |
| **App Drawer & OEM Icons** | ✅ **Implemented** | Samsung One UI & Xiaomi MIUI/HyperOS app suite recognition, DEX icon dumper + APK fallback extraction |
| **Staged Boot Sequencer** | ✅ **Implemented** | 5-step detection and health check (ADB → Device → Link → scrcpy) |
| **Media Volume Control** | ✅ **Implemented** | Hardware volume stepping and mute toggles via ADB |
| **Android Display Compatibility** | ✅ **Implemented** | Isolated virtual displays on Android 14+ (`--new-display`); low-latency primary mirror with automatic screen-off (`--turn-screen-off`) on Android 10–13 |
| **Real-Time Notification Sync** | 🟡 **Partially Implemented** | `dumpsys` polling in desktop; Companion daemon in Kotlin |
| **Audio Forwarding to Host** | 🔵 **Planned** | PipeWire / PulseAudio / WASAPI integration via scrcpy tunnel |
| **Bidirectional Clipboard Sync** | 🔵 **Planned** | Automatic copy-paste synchronization between host and phone |
| **Direct Control Socket Touch** | 🧪 **Experimental** | Direct binary touch packets over scrcpy control port |

*Legend: ✅ Implemented | 🟡 Partially Implemented | 🔵 Planned | 🧪 Experimental*

---

## Architecture & Shell Options

Open Android DeX provides two distinct desktop shells tailored for different use cases:

```
┌─────────────────────────────────────────────────────────────┐
│                 Open Android DeX Ecosystem                  │
├──────────────────────────────┬──────────────────────────────┤
│ Primary: Flutter Compositor  │ Fallback: Python GTK4 Shell  │
│  - Rich multi-window canvas  │  - Low memory footprint      │
│  - In-process FFmpeg decoder │  - Standalone scrcpy window  │
│  - Samsung DeX glassmorphism │  - Fast zero-compile startup │
├──────────────────────────────┴──────────────────────────────┤
│               Shared ADB & Transport Protocols              │
│       (ADB Daemon, Port Forwarding, Headless scrcpy)        │
└─────────────────────────────────────────────────────────────┘
```

For full technical diagrams, data flows, and IPC details, refer to [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### 1. Flutter Desktop Compositor (Primary: Linux & Windows 11)
* **Code Location:** [`lib/`](lib/), [`linux/`](linux/), and [`windows/`](windows/)
* **Window Engine:** Draggable and 8-direction resizable window frames with active focus management, smooth two-finger trackpad/touchpad scrolling, and minimize/maximize memory.
* **Streaming Engine:**
  - **Linux:** Headless `scrcpy` writes live H.264 video to an IPC named pipe (`$XDG_RUNTIME_DIR/opendex/`), which [`stream_texture.cc`](linux/stream_texture.cc) decodes into an `FlPixelBufferTexture` rendered in real-time.
  - **Windows 11:** Headless `scrcpy.exe` streams to a Win32 Named Pipe (`\\.\pipe\opendex_stream_*`), which [`stream_texture_windows.cpp`](windows/runner/stream_texture_windows.cpp) decodes into a GPU-accelerated `flutter::PixelBufferTexture` via embedded FFmpeg C-API decoding (`avcodec`, `avformat`, `swscale`, `avutil`).
* **Adaptive Display Manager:** Dynamically probes the device Android SDK version (`ro.build.version.sdk`). Automatically routes application windows to isolated virtual displays on Android 14+ (`--new-display`), or to high-frame-rate primary screen mirror mode with `--turn-screen-off` on Android 10–13, complete with automatic 900ms process monitoring and fail-safe recovery.

### 2. Python / GTK4 Shell (Lightweight Fallback: Linux)
* **Code Location:** [`app.py`](app.py) and supporting Python modules
* **Model:** Pure PyGObject GTK4 desktop launcher with status bar, app drawer, and system dock.
* **Streaming:** Launches `scrcpy` in an external standalone window matching host compositor conventions.

### 3. Android Companion App
* **Code Location:** [`android_companion/`](android_companion/)
* **Model:** Clean-room Kotlin service featuring `NotificationListenerService` and a loopback-bound TCP daemon (`127.0.0.1:8888`) for event broadcasting.

---

## System Requirements

### Windows 11 Host
* **Operating System:** Windows 11 (64-bit x64) or Windows 10 Build 19041+
* **Pre-bundled:** The official Installer and Portable packages already bundle `adb.exe`, `scrcpy.exe`, `scrcpy-server`, and all required FFmpeg & MSVC runtime DLLs.
* **Tools (for running from source):**
  * `adb.exe` ([Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools))
  * `scrcpy.exe` ([Genymobile scrcpy 2.0+](https://github.com/Genymobile/scrcpy/releases))
  * OEM Android USB Drivers (Google, Samsung, Xiaomi, Motorola, etc.)
  * Visual Studio 2022 with C++ desktop workload & Flutter SDK 3.24+

### Linux Host
* **Operating System:** Linux (Arch Linux, Ubuntu 20.04+, Debian 11+, Fedora 36+)
* **Display Server:** Wayland (Hyprland, Sway, GNOME, KDE) or X11
* **Tools:**
  * `adb` (Android Debug Bridge, version 31+)
  * `scrcpy` (version 2.0 - 5.0+)
  * `libfuse2` (for running the AppImage; or launch with `--appimage-extract-and-run`)
  * Python 3.10+ (for Python GTK shell and test suite)
  * Flutter SDK 3.24+ (for building from source)

### Android Device Support
* Any smartphone, tablet, or handheld running **Android 10 through Android 16** (API Level 29–36).
* **OEM Compatibility**: Verified on **Samsung Galaxy** (One UI), **Xiaomi / Redmi / POCO** (MIUI / HyperOS), **Google Pixel**, **Motorola**, and generic AOSP.
* **Display Operating Modes**:
  - **Android 14+ (API 34+)**: Uses `--new-display` to create isolated, resizable secondary virtual displays while your phone screen stays free.
  - **Android 10–13 (API 29–33)**: Seamlessly operates via primary display streaming with `--turn-screen-off` so your phone display remains powered off while the desktop window displays the application.
* **USB Debugging** enabled in *Developer Options*.
* (Optional) **Wireless Debugging** (Android 11+) supported via QR code pairing or IP:port.

---

## Quick Start Guide

### 🚀 Instant Demo Mode (No Android Phone Needed!)

Want to test, explore, or build features without plugging in a physical phone? You can launch Open Android DeX immediately in simulated **Demo Mode**:

```bash
# Auto-detects Flutter or Python and launches instant Demo Mode:
./scripts/run_demo.sh

# Or run the Python/GTK4 shell directly in demo mode:
python3 app.py --demo
```

---

### Running on Windows 11

1. Download the pre-built Windows release from [GitHub Releases](https://github.com/Bit-manipulators/open-android-dex/releases/latest):
   - **`Open-Android-DeX-v2.0.2-Windows-x64-Setup.exe`**: Standard installer with desktop shortcut and clean uninstallation.
   - **`Open-Android-DeX-v2.0.2-Windows-x64-Portable.zip`**: Zero-install standalone archive.
   *(Both packages come pre-bundled with `adb.exe`, `scrcpy.exe`, `scrcpy-server`, and all required FFmpeg & MSVC runtime DLLs).*
2. Connect your Android device via USB and enable **USB Debugging** (accept the RSA fingerprint prompt on your phone).
3. Launch Open Android DeX from your Start Menu, Desktop, or extracted portable directory.
4. See [`docs/WINDOWS_SETUP.md`](docs/WINDOWS_SETUP.md) for full driver and configuration details.

### Running the Linux AppImage

1. Download **`Open-Android-DeX-Linux-x86_64.AppImage`**.
2. Run:
   ```bash
   chmod +x Open-Android-DeX-Linux-x86_64.AppImage
   ./Open-Android-DeX-Linux-x86_64.AppImage
   ```
3. See [`docs/APPIMAGE_GUIDE.md`](docs/APPIMAGE_GUIDE.md) for desktop integration and troubleshooting.

---

### Building from Source

#### Building the Linux AppImage
```bash
./scripts/build_appimage.sh
```

#### Building the Windows 11 Application
```powershell
# From PowerShell on Windows:
.\scripts\build_windows.ps1
```

#### Running the Flutter Desktop Shell from Source
```bash
# On Linux:
./run_flutter_dex.sh

# On Windows:
flutter run -d windows
```

Or via Flutter CLI:
```bash
flutter run -d linux
```

### Running the Python / GTK4 Shell

```bash
python3 app.py
```

Or install as a local command:
```bash
pip install -e .
open-android-dex
```

---

## Testing & Quality Assurance

The repository includes a zero-dependency test runner and full CI integration:

```bash
# Run all unit tests with zero third-party dependencies:
python3 run_tests.py

# Or via pytest:
PYTHONPATH=. pytest tests/ -v

# Run Flutter static analysis
flutter analyze

# Run Flutter tests
flutter test
```

---

## ⚖️ Provenance & Reverse-Engineering Transparency

Open Android DeX is an **independent, clean-room, open-source project**.

* **Reference Software Studied:** Earlier exploratory phases studied compiled reference binaries (`.AppImage`, `libapp.so`, and reference companion JARs) using public binary analysis to understand high-level architectural requirements (such as virtual display binding and video texture pipelines).
* **Public Specifications Used:** All implementations in this repository are based exclusively on publicly documented open-source protocols, including the official [scrcpy protocol](https://github.com/Genymobile/scrcpy), Android Open Source Project (AOSP) documentation, and standard Linux/GTK APIs.
* **Clean-Room Codebase:** No code, strings, proprietary assets, or binaries from any closed-source application are used or distributed in this repository.
* **Third-Party Trademarks:** "Android" and "Samsung DeX" are trademarks of their respective owners. Their mention here is purely descriptive of factual technical compatibility.

For detailed security review and threat models, see [`docs/SECURITY.md`](docs/SECURITY.md).

---

## Documentation & Contributing

Comprehensive architectural and developer guides are available in `docs/`:

* 🪟 **[Windows 11 Setup Guide](docs/WINDOWS_SETUP.md)**: Installation, ADB setup, USB drivers, and troubleshooting on Windows 11.
* 🐧 **[Linux AppImage Guide](docs/APPIMAGE_GUIDE.md)**: Running, desktop integration, and building portable AppImages.
* 📑 **[Technical Compatibility Report](docs/TECHNICAL_COMPATIBILITY_REPORT.md)**: Deep architectural analysis of Windows 11 and Linux cross-platform layer.
* 🌟 **[Good First Issues for Contributors](docs/GOOD_FIRST_ISSUES.md)**: 5 bite-sized, ready-to-solve starter issues with code pointers.
* 📢 **[Community Outreach & Launch Kit](docs/COMMUNITY_SUBMISSIONS.md)**: Ready-to-use posts for Reddit, Hacker News, and Awesome lists.
* 📖 **[Architecture & Data Flow](docs/ARCHITECTURE.md)**: Video decoding, IPC, window management.
* 🛡️ **[Security Policy & Threat Model](docs/SECURITY.md)**: Socket isolation, ADB authorization, and least-privilege review.
* 🗺️ **[Development Roadmap & Issues](docs/ROADMAP.md)**: 6 strategic pillars and 12 actionable issue proposals.
* 🔍 **[Comprehensive Project Audit](docs/PROJECT_AUDIT.md)**: Detailed audit report of all components and bugs.
* 🤝 **[Contribution Guidelines](CONTRIBUTING.md)**: Setup, branch conventions, PR checklist.
* 📜 **[Code of Conduct](CODE_OF_CONDUCT.md)**: Community standards and enforcement.

We warmly welcome external contributors! Check out **[`docs/GOOD_FIRST_ISSUES.md`](docs/GOOD_FIRST_ISSUES.md)** to grab an issue and submit your first PR!

---

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see the [`LICENSE`](LICENSE) file for details.  
Copyright (c) 2026 [Bit-manipulators](https://github.com/Bit-manipulators/open-android-dex).
