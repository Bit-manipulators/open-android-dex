# 🌟 Good First Issues for New Contributors

Welcome to **Open Android DeX**! We love open-source contributions. 

To help you get started quickly and submit your first Pull Request, we have curated bite-sized, high-impact tasks below. Each issue lists the motivation, target files, acceptance criteria, and how to verify your changes.

---

## 🟢 Issue #1: Keyboard Shortcut (Super / Meta Key) to Toggle App Drawer

- **Difficulty:** Easy
- **Stack:** Flutter (`lib/views/dex_desktop_screen.dart`) OR Python (`app.py`)
- **Category:** User Experience / Shortcuts

### Description
In traditional desktop environments (Windows, macOS Spotlight, GNOME, KDE), pressing the `Super` (Windows) key or `Ctrl + Space` toggles the application launcher. Currently in Open Android DeX, users must click the 9-dot launcher button on the taskbar.

### What to Do
1. In `lib/views/dex_desktop_screen.dart`, add a keyboard event listener for `LogicalKeyboardKey.meta` or `LogicalKeyboardKey.metaLeft`.
2. When pressed, toggle `_isDrawerOpen = !_isDrawerOpen;`.
3. In `app.py`, update `_on_key_pressed` to handle `Gdk.KEY_Super_L` or `Gdk.KEY_Super_R` to toggle the app drawer flowbox.

### How to Verify
- Run `./scripts/run_demo.sh`.
- Press the `Super` / `Windows` key on your keyboard and observe the app drawer smoothly toggling open and closed.

---

## 🟢 Issue #2: Window Snap Presets (Half-Screen Left / Right Tiling)

- **Difficulty:** Easy / Medium
- **Stack:** Flutter (`lib/controllers/window_manager_controller.dart`, `lib/widgets/resizable_window_frame.dart`)
- **Category:** Window Management

### Description
Power users expect snapping windows to screen halves:
- `Super + Left Arrow`: Snap window to left 50% of the desktop.
- `Super + Right Arrow`: Snap window to right 50% of the desktop.

### What to Do
1. Add methods `snapLeft(String windowId, Size desktopSize)` and `snapRight(String windowId, Size desktopSize)` to `WindowManagerController`.
2. Update the target window's `x`, `y`, `width`, and `height` to:
   - Left: `x = 0`, `y = 0`, `width = desktopSize.width / 2`, `height = desktopSize.height - taskbarHeight`.
   - Right: `x = desktopSize.width / 2`, `y = 0`, `width = desktopSize.width / 2`, `height = desktopSize.height - taskbarHeight`.
3. Bind keyboard shortcut or double-clicking the titlebar border.

### How to Verify
- Launch demo mode with `./scripts/run_demo.sh`.
- Open Calculator or Settings, trigger snap, and ensure window occupies exactly half the screen.

---

## 🟢 Issue #3: Wallpaper Theme Switcher in Quick Settings

- **Difficulty:** Easy
- **Stack:** Flutter (`lib/widgets/quick_settings_panel.dart`, `lib/views/dex_desktop_screen.dart`)
- **Category:** UI / Customization

### Description
Allow users to cycle through wallpapers or choose a dark glassmorphism gradient directly from the Quick Settings tray panel.

### What to Do
1. Locate available wallpapers in `assets/` (`wallpaper_1.svg`, `wallpaper_dark.jpg`, etc.).
2. Add a simple row in `QuickSettingsPanel` with 3 thumbnail buttons or an "Appearance: Next Wallpaper" toggle.
3. Persist user wallpaper selection in local state.

### How to Verify
- Click the bottom-right Quick Settings panel, click wallpaper toggle, and observe background dynamically update.

---

## 🟡 Issue #4: Battery Charging Pulse & Status Visualizer

- **Difficulty:** Medium
- **Stack:** Flutter (`lib/widgets/desktop_taskbar.dart`) & Python (`app.py`)
- **Category:** Visuals / Polish

### Description
When the Android device is plugged in and actively charging (`isCharging == true`), show a subtle animated green pulse or lightning badge next to the battery percentage.

### What to Do
1. In `lib/widgets/desktop_taskbar.dart`, check `_adb.isCharging`.
2. Add an animated icon or color transition between `Color(0xFF10B981)` (Emerald) and `Color(0xFF34D399)` (Mint).
3. Ensure low battery (< 20% and not charging) shows `Color(0xFFEF4444)` (Red).

### How to Verify
- In demo mode, test varying battery values and observe the taskbar status icons.

---

## 🟡 Issue #5: Bidirectional Clipboard Sync Daemon

- **Difficulty:** Medium / Advanced
- **Stack:** Python (`app.py`, `adb_client.py`) OR Dart/Flutter
- **Category:** Core Integration

### Description
Allow copying text on the host Linux machine and pasting directly into the phone (or vice-versa).

### What to Do
1. Query host clipboard (via `wl-paste` on Wayland or `xclip` on X11, or GTK clipboard API).
2. When the clipboard string changes, push it to Android via ADB command:
   ```bash
   adb shell cmd clipboard set text "<copied_string>"
   ```
3. Read phone clipboard periodically or on window focus switch:
   ```bash
   adb shell cmd clipboard get
   ```

### How to Verify
- Copy text on Linux host, switch to Android DeX app, press `Ctrl+V`, and verify text appears.

---

## 🚀 How to Submit Your Pull Request

1. Fork the repository and clone your fork.
2. Run `./scripts/dev_setup.sh` to install dependencies.
3. Run `python3 run_tests.py` to ensure existing tests pass.
4. Create a feature branch: `git checkout -b feature/your-awesome-feature`.
5. Implement your change and test with `./scripts/run_demo.sh`.
6. Commit your changes with clear messages (`git commit -m "feat(ui): add Super key drawer toggle"`).
7. Push to your fork and submit a PR against `main`!

