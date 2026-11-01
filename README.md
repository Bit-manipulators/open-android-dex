# Android Desktop Remote

Original, from-scratch desktop application for controlling an Android device
from Linux. Built with Python, GTK4, ADB, and scrcpy.

This is an independent reimplementation. No code, strings, or assets from any
third-party binary were copied. All source below is original work.

## Features

- Discover and connect to Android devices over ADB
- Mirror device screen to the desktop (scrcpy)
- Send keyboard and mouse input to the device
- Control device volume
- Open URLs on the device
- Manage application windows

## Requirements

- Python 3.10+
- PyGObject / GTK4
- `adb` (Android Debug Bridge)
- `scrcpy`

## Install

```bash
git clone <this-repo>
cd android_desktop_remote
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

## Run

```bash
python3 -m android_desktop_remote
```

## License

MIT License. See LICENSE.
