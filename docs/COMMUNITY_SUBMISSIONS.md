# 📢 Community Launch & Contributor Outreach Kit

Use the copy-paste templates below to announce **Open Android DeX** on developer forums, open-source directories, and social media.

---

## 1. Reddit Launch Posts

### Subreddit: r/linux & r/opensource
**Title:** `Show r/linux: Open Android DeX — Clean-room open-source desktop environment for Android on Linux`

```markdown
Hey everyone!

I've been working on **Open Android DeX**, a 100% clean-room open-source desktop environment 
that transforms any Android smartphone into a multi-window desktop workstation under Linux (Wayland and X11):

🔗 **GitHub:** https://github.com/Bit-manipulators/open-android-dex
📜 **License:** GPL-3.0

### Why build this?
Samsung DeX and Motorola Ready For are proprietary, locked to specific OEM brands, and 
lack native Linux desktop integration. Open Android DeX works across brands using clean 
ADB transport, in-process C++ FFmpeg texture decoding inside a Flutter compositor, and a 
lightweight fallback Python GTK4 shell.

### What is implemented:
- 8-way smooth window resizing with geometry persistence
- Multi-window Z-ordering, active focus switching, drop shadows
- Taskbar, 9-dot launcher, real-time app search
- Staged boot sequencer (ADB -> Device handshake -> Headless scrcpy)
- Hardware volume stepping & media controls
- 🧪 **Demo Mode**: Developers can run and test the UI without an Android device plugged in!

### We Need Contributors!
We're looking for help with:
- PipeWire / PulseAudio host forwarding
- Bidirectional clipboard synchronization
- Window snap presets & tiling shortcuts
- Android companion notification daemon

Check out `docs/GOOD_FIRST_ISSUES.md` and `CONTRIBUTING.md` to get started!
```

---

### Subreddit: r/FlutterDev
**Title:** `Open Android DeX: Linux Desktop Compositor built with Flutter + in-process FFmpeg C++ video textures`

```markdown
Hi Flutter community!

We built a desktop compositor using Flutter for Linux that turns Android devices into a 
full desktop environment:
https://github.com/Bit-manipulators/open-android-dex

Technical highlights for Flutter devs:
- Custom C++ `FlPixelBufferTexture` receiving H.264 video frames from headless scrcpy via named pipes.
- Custom 8-direction interactive window frame resize manager with drag throttling and z-index elevation.
- Zero-hardware Demo Mode for easy UI hacking (`./scripts/run_demo.sh`).

We'd love feedback from the community and welcome pull requests on UI polish, shortcut handling, and animations!
```

---

## 2. Hacker News ("Show HN")

**Title:** `Show HN: Open Android DeX – Open-source desktop environment for Android under Linux`

```text
Open Android DeX is an open-source (GPL-3.0) desktop environment that turns Android smartphones 
into a multi-window workstation under Linux (Wayland and X11).

Repo: https://github.com/Bit-manipulators/open-android-dex

Instead of relying on proprietary OEM desktop modes (Samsung DeX, Motorola Ready For), Open Android DeX 
uses clean-room ADB protocol commands and native in-process FFmpeg video decoding to provide a true 
multi-window desktop canvas with window resizing, taskbar, dock, and app drawer.

A zero-device Demo Mode is included so developers can test the environment without hardware:
./scripts/run_demo.sh

We welcome community feedback, code audits, and pull requests!
```

---

## 3. Pull Request Submissions to "Awesome" Lists

### Submission to `vinta/awesome-python`
Add under `GUI Development` or `System Tools`:
```markdown
- [Open Android DeX](https://github.com/Bit-manipulators/open-android-dex) - Open-source GTK4 and Flutter desktop environment connecting Android phones to Linux.
```

### Submission to `Solido/awesome-flutter`
Add under `Desktop Applications`:
```markdown
- [Open Android DeX](https://github.com/Bit-manipulators/open-android-dex) - Open-source Linux desktop compositor transforming Android devices into multi-window workstations.
```

### Submission to `input-output-hk/awesome-linux`
Add under `Desktop Environments & Window Management`:
```markdown
- [Open Android DeX](https://github.com/Bit-manipulators/open-android-dex) - Open-source desktop workstation mode for Android under Linux (Wayland & X11).
```

