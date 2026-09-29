# 💻 OpenDeX — Android DeX Experience over ADB

Turn any modern Android phone into a full Samsung DeX-style workstation contained entirely inside **one single window** on your laptop.

---

## ✨ Features

- **Single Main Window**: No messy multiple desktop windows on your laptop. Everything (all mobile apps, taskbar, start menu) runs isolated inside one clean 1080p/2K/4K desktop window.
- **Window Resizing & Multitasking**:
  - Drag window borders to freely resize any app.
  - Desktop title bars with **Minimize (`—`)**, **Maximize (`▢`)**, and **Close (`✕`)** buttons.
  - Run multiple apps side-by-side (e.g. Chrome, WhatsApp, YouTube, and Notes all open simultaneously).
- **App Tabs & Taskbar**:
  - Open mobile apps appear as active tabs along the taskbar.
  - Click any tab to toggle or switch between active applications.
  - Windows/DeX-style Start Menu for launching apps.
- **Native PC Input Integration**:
  - True mouse pointer with hover states, scroll wheel, and right-click as "Back/Context Menu".
  - Full keyboard typing with desktop shortcuts (`Alt+Tab`, `Alt+f` for Fullscreen).
  - Shared clipboard (copy text on your PC and paste on your phone).
- **Independent Phone Screen**:
  - Your phone screen can be turned off or used independently for phone calls while you work inside DeX.
- **Wireless & USB Support**:
  - Connect via standard USB-C cable or wireless Wi-Fi ADB.

---

## 🚀 Quick Start

### Option 1: Fast One-Click CLI Launch
Connect your phone via USB with **USB Debugging** enabled, then run:

```bash
cd /home/amit/test/dex
bash launch_dex.sh
```

### Option 2: Graphical Control Center (GUI)
Launch the modern control panel to adjust resolutions, scale DPI, setup wireless connections, or launch specific app tabs:

```bash
cd /home/amit/test/dex
python3 opendex_gui.py
```

---

## ⌨️ Desktop Shortcuts & Controls

| Shortcut / Action | Function |
|---|---|
| **Click & Drag Window Edges** | Resize any mobile app window |
| **Click & Drag Title Bar** | Move window anywhere on desktop canvas |
| **Title Bar `▢` (Maximize)** | Expand app to full DeX window |
| **Title Bar `—` (Minimize)** | Minimize app to the taskbar tab |
| **Right-Click** | Back button / Context menu |
| **Middle-Click** | Android Home |
| **Alt + f** | Toggle Fullscreen on laptop |
| **Alt + Tab** | Switch between open mobile app tabs |
| **Ctrl + c / Ctrl + v** | Bidirectional Clipboard Sync |

---

## 📶 Wireless Connection (Cable-Free)

1. Connect your phone via USB once.
2. In `opendex_gui.py`, click **"Switch to Wireless ADB"** (or run `adb tcpip 5555`).
3. Disconnect the USB cable.
4. Connect using your phone's Wi-Fi IP address:
   ```bash
   adb connect 192.168.1.XX:5555
   bash launch_dex.sh
   ```
