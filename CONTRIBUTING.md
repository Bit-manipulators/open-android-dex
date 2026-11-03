# Contributing to Open Android DeX

Thank you for your interest in contributing to **Open Android DeX**! 🎉  
Whether you are fixing a bug, adding new device capabilities, improving documentation, or optimizing the streaming engine, we welcome your contributions.

This project is maintained under a clean-room, open-source model licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started & Prerequisites](#getting-started--prerequisites)
   - [Linux Host Dependencies](#linux-host-dependencies)
   - [Flutter SDK Setup](#flutter-sdk-setup)
   - [Python Environment](#python-environment)
   - [Android Companion Setup](#android-companion-setup)
3. [Repository Structure](#repository-structure)
4. [Building & Running Components](#building--running-components)
   - [Running the Flutter Desktop Compositor](#running-the-flutter-desktop-compositor)
   - [Running the Python / GTK4 Shell](#running-the-python--gtk4-shell)
   - [Building the Android Companion](#building-the-android-companion)
5. [Running Tests](#running-tests)
   - [Python Tests](#python-tests)
   - [Flutter Tests](#flutter-tests)
6. [Contribution Workflow](#contribution-workflow)
   - [Branch Naming Conventions](#branch-naming-conventions)
   - [Commit Message Conventions](#commit-message-conventions)
   - [Pull Request Checklist](#pull-request-checklist)
7. [Clean-Room Contribution Policy](#clean-room-contribution-policy)

---

## 1. Code of Conduct

All contributors and maintainers are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please treat everyone with respect and empathy.

---

## 2. Getting Started & Prerequisites

### 🌟 Looking for a task to work on?
Check out our curated **[Good First Issues Guide](docs/GOOD_FIRST_ISSUES.md)** for beginner-friendly, high-impact features and bug fixes with step-by-step pointers to code files.

### 🚀 Instant Demo Mode (No Hardware Needed!)
You do not need a physical Android device or active phone cable to contribute to the UI, window management, or layout features!
```bash
# Launch instant demo mode:
./scripts/run_demo.sh
```

### 1-Click Dependency Setup
Run the automated environment installer for your Linux distro:
```bash
./scripts/dev_setup.sh
```

Or install dependencies manually:

### Linux Host Dependencies
Open Android DeX runs on Linux (X11 or Wayland). Ensure you have `adb` and `scrcpy` installed on your machine:

**Debian / Ubuntu:**
```bash
sudo apt update
sudo apt install -y adb scrcpy libgtk-4-dev libgtk-3-dev python3-gi gir1.2-gtk-4.0 \
    pkg-config cmake ninja-build clang libavcodec-dev libavformat-dev libswscale-dev libavutil-dev
```

**Arch Linux / Manjaro:**
```bash
sudo pacman -S android-tools scrcpy gtk4 gtk3 python-gobject \
    cmake ninja clang ffmpeg
```

**Fedora:**
```bash
sudo dnf install -y android-tools scrcpy gtk4-devel gtk3-devel python3-gobject \
    cmake ninja-build clang ffmpeg-free-devel
```

### Flutter SDK Setup
To develop the primary Flutter desktop shell:
1. Install [Flutter SDK 3.24+](https://docs.flutter.dev/get-started/install/linux).
2. Enable Linux desktop support:
   ```bash
   flutter config --enable-linux-desktop
   ```
3. Verify your setup:
   ```bash
   flutter doctor
   ```

### Python Environment
To run the lightweight GTK4 shell or the test suite:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pytest flake8
```

### Android Companion Setup
To develop the Android companion service:
* [Android Studio Hedgehog / Jellyfish+](https://developer.android.com/studio) or command-line Android SDK.
* JDK 17+.

---

## 3. Repository Structure

| Path | Purpose |
| :--- | :--- |
| `lib/` | Flutter desktop UI (windows, taskbar, settings, stream viewport) |
| `linux/` | Native C++ Linux embedder & FFmpeg live stream texture decoder |
| `app.py` | Standalone Python / GTK4 desktop shell |
| `adb_client.py` | Python ADB communication client |
| `input_controller.py` | Keyboard and touch input mapping |
| `android_companion/` | Kotlin Android service for real-time notification push |
| `assets/` | Original SVG logos, desktop wallpapers, and application icons |
| `tests/` | Pytest automated test suite |
| `docs/` | Architecture, Security, Roadmap, and Audit documentation |

---

## 4. Building & Running Components

### Running the Flutter Desktop Compositor
Connect your phone with **USB Debugging** enabled, then run:

```bash
./run_flutter_dex.sh
```

Or directly via Flutter CLI:
```bash
flutter run -d linux
```

### Running the Python / GTK4 Shell
```bash
python3 app.py
```

### Building the Android Companion
```bash
cd android_companion
./gradlew assembleDebug
```
Install the generated APK onto your connected phone:
```bash
adb install -r build/outputs/apk/debug/android_companion-debug.apk
```

---

## 5. Running Tests

### Automated Zero-Dependency Test Runner
Run the full unit test suite without needing third-party test harnesses:
```bash
python3 run_tests.py
```

### Python Tests with Pytest
Run using `pytest`:
```bash
PYTHONPATH=. pytest tests/
```

### Flutter Tests
```bash
flutter test
flutter analyze
```

---

## 6. Contribution Workflow

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/open-android-dex.git
   cd open-android-dex
   ```
3. **Create a topic branch** from `main`:
   ```bash
   git checkout -b fix/issue-description
   ```
4. **Make your changes**, keeping them small, focused, and incremental.
5. **Add tests** verifying your bug fix or feature.
6. **Ensure all tests pass** before committing.

### Branch Naming Conventions
* `fix/<short-description>`: Bug fixes (e.g. `fix/keycode-backspace`)
* `feat/<short-description>`: New features (e.g. `feat/audio-forwarding`)
* `docs/<short-description>`: Documentation changes (e.g. `docs/update-readme`)
* `refactor/<short-description>`: Code cleanup without functional changes

### Commit Message Conventions
Follow [Conventional Commits](https://www.conventionalcommits.org/):
* `feat: implement audio forwarding via scrcpy audio tunnel`
* `fix: correct KEYCODE_DEL mapping to backspace (67)`
* `docs: add contributing and security guidelines`
* `test: add unit tests for boot sequencer`

### Pull Request Checklist
Before opening a Pull Request, verify:
- [ ] Code follows formatting standards (`flutter format .`, Python PEP 8).
- [ ] New and existing tests pass.
- [ ] Documentation is updated if user-facing behavior changed.
- [ ] No private keys, credentials, or proprietary binaries are included.

---

## 7. Clean-Room Contribution Policy

> [!IMPORTANT]
> Open Android DeX is an independent, clean-room implementation. We do **NOT** accept code, strings, resources, or binaries copied from closed-source or proprietary vendor applications (such as Samsung DeX, Motorola Ready For, etc.). Contributions must be based entirely on publicly published documentation, standard Android APIs, or original research.
