# Open Android DeX — Windows 11 Setup & User Guide

> **Target Platform:** Windows 11 (64-bit x64)  
> **Status:** Official Supported Release  
> **Minimum OS:** Windows 10 Build 19041+ / Windows 11 21H2+

---

## 1. Installation Options

Open Android DeX provides two official distribution formats for Windows 11:

### Option A: Graphical Setup Installer (Recommended)
1. Download **`Open-Android-DeX-Windows-x64-Setup.exe`** from the [Releases](https://github.com/Bit-manipulators/open-android-dex/releases).
2. Double-click the installer.
3. Choose your installation location (default: `%LOCALAPPDATA%\Programs\Open Android DeX` or `C:\Program Files\Open Android DeX`).
4. (Optional) Check **"Create a desktop shortcut"**.
5. Click **Install**. Launch Open Android DeX from the Start Menu or Desktop shortcut.

### Option B: Standalone Portable ZIP
1. Download **`Open-Android-DeX-Windows-x64-Portable.zip`**.
2. Extract the archive into any folder of your choice (e.g. `C:\Tools\OpenAndroidDeX`).
3. Double-click **`open_android_dex.exe`** to launch immediately without modifying the Windows Registry.

---

## 2. Prerequisites & Dependencies

Open Android DeX Windows releases (**Setup Installer** and **Portable ZIP**) automatically bundle Google Android Platform-Tools (`adb.exe`) and `scrcpy.exe` out of the box, offering a 100% zero-configuration setup.

If running from source without bundled binaries, Open Android DeX includes an automated **Setup Assistant**:
* When launched without ADB or scrcpy, an in-app setup banner appears with a **"Install Tools Automatically (1-Click Setup)"** button.
* Tools are downloaded and configured locally in `%LOCALAPPDATA%\OpenAndroidDeX\tools\` with zero administrative privileges or PATH edits needed.

### OEM USB Drivers
* If your phone is not recognized by `adb devices`, install the appropriate USB driver for your phone brand:
  - **Google Pixel:** [Google USB Driver](https://developer.android.com/studio/run/win-usb)
  - **Samsung:** [Samsung Android USB Driver](https://developer.samsung.com/android-usb-driver)
  - **Xiaomi / OnePlus / Motorola / Oppo / Vivo:** Universal ADB driver or manufacturer PC suite.

---

## 3. Connecting Your Android Device

1. **Enable Developer Options**:
   - Go to Android **Settings** → **About phone**.
   - Tap **Build number** 7 times until you see *"You are now a developer!"*.
2. **Enable USB Debugging**:
   - Go to **Settings** → **System** → **Developer options**.
   - Toggle **USB debugging** to **ON**.
3. **Connect via USB Cable**:
   - Connect your phone to your Windows 11 PC using a high-quality USB-C data cable.
   - When the popup appears on your phone (*"Allow USB debugging?"*), check **"Always allow from this computer"** and tap **Allow**.
4. **Launch Open Android DeX**:
   - Open Android DeX will immediately detect your phone, display battery status, list installed applications in the App Drawer, and allow launching apps in floating resizable desktop windows.

---

## 4. Building from Source on Windows 11

### Requirements
- **Visual Studio 2022** with *"Desktop development with C++"* workload installed.
- **Flutter SDK 3.24+** ([Installation Guide](https://docs.flutter.dev/get-started/install/windows)).
- **Git for Windows**.
- (Optional) **Inno Setup 6** for compiling the installer.

### Build Steps
```powershell
# 1. Clone repository
git clone https://github.com/Bit-manipulators/open-android-dex.git
cd open-android-dex
git checkout feature/windows11-appimage-support

# 2. Enable Windows desktop
flutter config --enable-windows-desktop

# 3. Fetch dependencies
flutter pub get

# 4. Run automated test suite
flutter test

# 5. Build Release executable
flutter build windows --release

# 6. (Optional) Run the automated Windows packaging script
.\scripts\build_windows.ps1
```

The output artifacts will be placed in `build\release_artifacts\`:
- `Open-Android-DeX-Windows-x64-Portable.zip`
- `Open-Android-DeX-Windows-x64-Setup.exe`

---

## 5. Troubleshooting on Windows 11

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **"No ADB device connected"** | USB debugging not authorized or missing driver | Run `adb devices` in PowerShell. If status is `unauthorized`, unlock your phone and tap *"Always allow from this computer"*. If device is missing, install the OEM USB driver. |
| **Stream fails to open** | `scrcpy.exe` not found | Use the in-app 1-click Setup Assistant in the connection dialog, or place `scrcpy.exe` in the application folder. |
| **Diagnostic Log File** | Troubleshooting crashes or connection issues | Logs are saved to `%LOCALAPPDATA%\OpenAndroidDeX\logs\opendex.log`. Click the **Logs** button in the connection dialog to view. |
| **Windows SmartScreen warning** | Release is newly built and unsigned | Click *"More info"* → *"Run anyway"*. Open Android DeX is 100% open-source under GPL-3.0. |
| **Two-finger scroll direction reversed** | Personal preference | The compositor supports natural scrolling by default; mouse wheel gestures automatically scroll vertically. |
