# Android Dex — Original Reimplementation

Original, from-scratch desktop application for controlling Android devices
from Linux. Reimplements the Android Dex functionality (ADB device control,
screen mirroring via scrcpy, input injection, volume, URL launcher, window
management) using Python, GTK4, ADB, and scrcpy.

All code is original work. No code, strings, or assets were copied from any
third-party binary.

## Features

- Discover and connect to Android devices over ADB
- Mirror device screen to desktop (scrcpy)
- Send keyboard and mouse input to the device
- Control device volume
- Open URLs on the device
- Manage application windows (Home, Back, Recent Apps, Lock)
- Keyboard shortcuts: Ctrl+Shift+{Up, Down, Left, Right}

## Requirements

- Python 3.10+
- PyGObject / GTK4
- `adb` (Android Debug Bridge)
- `scrcpy`

## Run

```bash
cd /home/amit/github/ID2/open-android-dex
python3 app.py
```

## License

MIT License.
