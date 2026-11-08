# Open Android DeX — Linux AppImage Guide

> **Target Platform:** Linux x86_64 (Arch Linux, Ubuntu 20.04+, Debian 11+, Fedora 36+, openSUSE)  
> **Package Format:** Standalone Portable Type 2 AppImage  
> **Desktop Support:** Wayland (GNOME, KDE Plasma, Hyprland, Sway) & X11

---

## 1. Quick Start

The AppImage format packages Open Android DeX into a single executable file containing the Flutter runtime, GTK bindings, and multimedia decoding libraries.

### Download & Run
1. Download **`Open-Android-DeX-Linux-x86_64.AppImage`** from the [Releases](https://github.com/Bit-manipulators/open-android-dex/releases).
2. Make the file executable:
   ```bash
   chmod +x Open-Android-DeX-Linux-x86_64.AppImage
   ```
3. Run the application:
   ```bash
   ./Open-Android-DeX-Linux-x86_64.AppImage
   ```

---

## 2. System Prerequisites

The AppImage bundles all internal application dependencies, but requires standard Android host debugging utilities on the host system:

### 1. `adb` (Android Debug Bridge)
Install `adb` from your distribution's package manager:
* **Ubuntu / Debian:** `sudo apt install adb`
* **Arch Linux:** `sudo pacman -S android-tools`
* **Fedora:** `sudo dnf install android-tools`

### 2. `scrcpy` (Headless Mirroring Engine)
* **Ubuntu / Debian:** `sudo apt install scrcpy`
* **Arch Linux:** `sudo pacman -S scrcpy`
* **Fedora:** `sudo dnf install scrcpy`

### 3. FUSE (Filesystem in Userspace)
AppImages require `libfuse2` to mount:
* **Ubuntu 22.04+ / Debian 12+:**
  ```bash
  sudo apt install libfuse2
  ```
* If FUSE is not available (e.g. headless containers or restricted environments), run with:
  ```bash
  ./Open-Android-DeX-Linux-x86_64.AppImage --appimage-extract-and-run
  ```

---

## 3. Desktop Integration (Optional)

To integrate Open Android DeX into your system application launcher:

### Using AppImageLauncher (Automatic)
Install [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher). When double-clicking the AppImage, it will automatically register the desktop icon, MIME types, and menu entries.

### Manual Desktop Entry
Create `~/.local/share/applications/open_android_dex.desktop`:
```ini
[Desktop Entry]
Name=Open Android DeX
Comment=Transform your Android device into a desktop workstation
Exec=/path/to/Open-Android-DeX-Linux-x86_64.AppImage
Icon=open_android_dex
Terminal=false
Type=Application
Categories=Utility;System;Development;
```

---

## 4. Building the AppImage from Source

You can build the AppImage locally using the automated build script:

```bash
# Clone the feature branch
git clone https://github.com/Bit-manipulators/open-android-dex.git
cd open-android-dex
git checkout feature/windows11-appimage-support

# Install Linux build requirements
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev \
    libavcodec-dev libavformat-dev libswscale-dev libavutil-dev curl

# Execute the AppImage build pipeline
./scripts/build_appimage.sh
```

The resulting AppImage will be placed in `build/release_artifacts/Open-Android-DeX-Linux-x86_64.AppImage`.

---

## 5. Troubleshooting & Compatibility

| Symptom | Cause | Remedy |
| :--- | :--- | :--- |
| **"dlopen(): error loading libfuse.so.2"** | Missing FUSE 2 library on modern Ubuntu/Debian | Run `sudo apt install libfuse2` or launch with `--appimage-extract-and-run`. |
| **Window scaling issues on Wayland** | Fractional scaling mismatch | Open Android DeX runs with `--no-enable-impeller` and uses standard GDK Wayland scaling. |
| **Phone disconnected message** | USB cable in charge-only mode | Ensure your USB cable supports high-speed data transfer; select "File Transfer / Android Auto" on your phone. |
| **Permission denied on /dev/bus/usb** | Missing udev rules for Android | Install `android-udev-rules` package or restart adb server: `adb kill-server && sudo adb start-server`. |
