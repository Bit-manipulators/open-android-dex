# Open Android Dex

An original, from-scratch **open-source** GTK4 desktop shell that turns your
Android phone into a desktop-style environment under **Linux** — wallpaper,
status bar, app drawer, and dock, with screen mirroring via scrcpy.

## ⚖️ Legal & copyright notice

**Open Android Dex is an independent, clean-room project.** It is NOT
affiliated with, endorsed by, sponsored by, or derived from any proprietary
or closed-source product, including any application named "Android DEX" or
similar.

* All code in this repository is **original work**, licensed under the GNU General Public License v3.0 (GPL-3.0) — see
  `LICENSE`.
* **No** code, binaries, strings, configuration files, artwork, icons, sounds,
  or other assets from any third-party or closed-source application are used,
  copied, embedded, bundled, or distributed in this repository or by this
  software.
* All assets shipped in `assets/` are original, generated from scratch
  (simple SVG placeholders — replace them with your own art if you like; the
  app works without assets at all).
* Design model: where this project implements behavior similar to other
  desktop-phone tools, it was built from *publicly published documentation
  and descriptions of behavior only* — never from disassembly, ripping, or
  extraction of any third-party binary.
* "Android" is a trademark of Google LLC. This project is not affiliated
  with, endorsed by, or sponsored by Google LLC. The name is used only to
  describe factual compatibility with the Android platform.
* scrcpy and ADB are third-party open-source tools, governed by their own
  licenses (Apache-2.0, etc.) and are not distributed by this repository.
* If you redistribute or fork this project, keep this notice and the `LICENSE`
  file intact. If you add third-party assets or code, they must be
  compatible with GPL-3.0 and clearly attributed.

**Contribution policy:** patches that copy code or assets from closed-source
applications will be rejected. Clean-room work only.

## Features

- **Desktop-style shell** — wallpaper, translucent glass top bar (device
  name, live battery ⚡, volume, clock, device picker), bottom dock
- **Boot sequence** with progress feedback: start ADB → detect/auto-select
  device → verify shell link → confirm scrcpy availability → ready
- **App drawer** — every user app on the phone appears as a tile; click a
  tile to launch the app on the phone
- **Screen mirroring** via scrcpy (`Mirror` in the dock)
- **Phone control from the desktop** — Home, Back, Recent Apps, Lock,
  Volume, DPAD navigation (`Ctrl+Shift+` arrow keys)
- **URL launcher** — type a link, it opens in the phone's browser

## Requirements

- Python 3.10+
- PyGObject / GTK4 (GTK >= 4.10)
- `adb` — `sudo apt install adb`
- `scrcpy` — `sudo apt install scrcpy`
- A phone with **USB debugging** enabled

## Run Flutter Desktop Application (DeX Mode with Resizable Windows)

```bash
cd /path/to/open-android-dex
./run_flutter_dex.sh
```

or directly:

```bash
flutter run -d linux
```

### Features in Flutter GUI:
- **Internal Resizable & Draggable Windows**:
  - Drag from title bar across the desktop canvas.
  - 8-direction smooth edge and corner resizing (Top, Bottom, Left, Right, Corners).
  - Minimize (`_`), Maximize / Restore (`□`), Close (`✕`), and double-click to maximize/restore.
  - Active window focus with z-index ordering and drop shadows.
- **DeX Desktop Environment**:
  - Ambient dark wallpaper with high-res graphics.
  - Floating Device Capsule (`moto g54 5G • Desktop 0 • Connected via ADB`).
  - Desktop quick-launch app grid.
- **Interactive DeX Taskbar**:
  - 9-dot App Drawer launcher grid with search and category filtering.
  - Android Navigation Bar: Back (`<`), Home (`○`), Recents (`□`).
  - Running app icons with active pill indicators (click to minimize/restore/bring to front).
  - Live battery %, charging indicator, clock, and connected device pill.
- **Per-App Device Control & Mirroring**:
  - 1-click Screen Mirroring via scrcpy directly onto the laptop monitor.
  - Instant text injection & physical hardware button shortcuts (Volume, Power, Enter).

---

## Run Legacy Python / GTK4 Shell

```bash
cd /path/to/open-android-dex
python3 app.py
```

or, after `pip install .`:

```bash
open-android-dex
```

Flow: plug the phone in → press **Boot Sequence** → the boot card disappears
and your app grid loads → press **Mirror** to open the scrcpy window (you
can position it over the wallpaper like a DeX window).

## Boot flow

| Step | Progress | What happens |
| :--- | :--- | :--- |
| 1 | 0.04 | `adb start-server` |
| 2 | 0.15 | Device detection: 0 → prompt to connect; 1 → auto-select; 2+ → pick from list |
| 3 | 0.40 | Shell link verification (`getprop` device identity) |
| 4 | 0.70 | scrcpy availability check |
| 5 | 1.00 | System ready — device connected |

Failing steps produce clear, actionable messages instead of raw errors
(e.g. unauthorized devices prompt you to accept the debugging dialog on the
phone).

## Module map

```
app.py ─────────────── DeX-style GTK4 shell, boot orchestration glue
├── adb_client.py ──── adb subprocess wrapper (single source of truth)
├── device_manager.py  target-device selection state machine
├── boot_manager.py ── sequenced init steps + progress events (threaded)
├── scrcpy_client.py ─ screen mirroring process management
├── input_controller.py  key/tap/swipe → adb input events
├── volume_control.py  media volume adjustment
├── url_launcher.py ── android.intent.action.VIEW launcher
└── window_manager.py  device window/task helpers (home, recents, lock)
```

## Roadmap

- Per-app desktop windows (decode scrcpy's video stream into native GTK
  widgets instead of launching an external scrcpy window)
- Own companion service for notifications/media-session telemetry
  (original Kotlin module, written from scratch)
- Gaming-mode key profiles
- Wi-Fi (wireless debugging) pairing support

## License

GNU General Public License v3.0 (GPL-3.0) — see [`LICENSE`](LICENSE). Copyright (c) 2026 [Bit-manipulators](https://github.com/Bit-manipulators/open-android-dex).
