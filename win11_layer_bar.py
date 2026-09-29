#!/usr/bin/env python3
"""
Win11 Wayland Layer-Shell Taskbar & Navigation Dock for OpenDeX
Anchors natively on Wayland OVERLAY layer (floats on top of scrcpy at all times).
Features:
- Windows 11 Start Menu (⊞) with phone apps search
- The 3 Android Buttons: Back (◀), Home (●), Recents/Multitasking (■)
- Window Resizing / Snapping controls: Snap Left (◫), Snap Right (◪), Maximize (▢)
- Active App Tabs with close button
- Battery & Clock System Tray
ZERO APKs installed on phone.
"""

import sys
import subprocess
import threading
import time
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

CSS = b"""
window {
    background-color: transparent;
}

#dock-container {
    background-color: rgba(30, 30, 32, 0.96);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 14px;
    padding: 4px 10px;
    margin-bottom: 8px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
}

.dock-btn {
    background-color: transparent;
    border: none;
    border-radius: 8px;
    color: #f0f0f0;
    padding: 6px 10px;
    font-size: 14px;
    font-weight: bold;
    min-height: 28px;
}

.dock-btn:hover {
    background-color: rgba(255, 255, 255, 0.12);
}

.start-btn {
    color: #0078d4;
    font-size: 18px;
    padding: 4px 12px;
}

.start-btn:hover {
    background-color: rgba(0, 120, 212, 0.2);
}

.app-tab {
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    color: #e0e0e0;
    padding: 4px 10px;
    margin: 0 2px;
    font-size: 12px;
}

.app-tab:hover {
    background-color: rgba(255, 255, 255, 0.16);
}

.separator {
    background-color: rgba(255, 255, 255, 0.15);
    margin: 6px 4px;
}

.tray-label {
    color: #a0a0a0;
    font-size: 12px;
    padding: 0 6px;
}

#start-popup {
    background-color: rgba(30, 30, 32, 0.98);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 12px;
    padding: 12px;
}
"""

class Win11LayerBar:
    def __init__(self):
        self.target_display = None
        self.active_tabs = {}
        self.installed_apps = []

        self._init_css()
        self._build_window()
        self._load_apps_async()
        self._start_battery_clock_loop()
        self._start_display_detector()

    def _init_css(self):
        screen = Gdk.Screen.get_default()
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def _build_window(self):
        self.win = Gtk.Window()
        self.win.set_title("Win11-Layer-Bar")
        self.win.set_app_paintable(True)

        # Initialize GtkLayerShell on Wayland
        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT, False)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.RIGHT, False)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.BOTTOM, 10)

        # Main Dock Box
        self.dock = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        self.dock.set_name("dock-container")

        # 1. Start Menu Button (⊞)
        self.btn_start = Gtk.Button(label="⊞")
        self.btn_start.get_style_context().add_class("dock-btn")
        self.btn_start.get_style_context().add_class("start-btn")
        self.btn_start.connect("clicked", self._toggle_start_menu)
        self.dock.pack_start(self.btn_start, False, False, 0)

        self._add_sep()

        # 2. The 3 Android Buttons
        # Back (◀)
        btn_back = Gtk.Button(label="◀")
        btn_back.get_style_context().add_class("dock-btn")
        btn_back.set_tooltip_text("Android Back")
        btn_back.connect("clicked", lambda b: self._send_key(4))
        self.dock.pack_start(btn_back, False, False, 0)

        # Home (●)
        btn_home = Gtk.Button(label="●")
        btn_home.get_style_context().add_class("dock-btn")
        btn_home.set_tooltip_text("Android Home")
        btn_home.connect("clicked", lambda b: self._send_key(3))
        self.dock.pack_start(btn_home, False, False, 0)

        # Recents / Multitasking (■)
        btn_recents = Gtk.Button(label="■")
        btn_recents.get_style_context().add_class("dock-btn")
        btn_recents.set_tooltip_text("Recents / App Switcher")
        btn_recents.connect("clicked", lambda b: self._send_key(187))
        self.dock.pack_start(btn_recents, False, False, 0)

        self._add_sep()

        # 3. Window Snapping & Multitasking Controls
        # Snap Left (◫)
        btn_snap_l = Gtk.Button(label="◫")
        btn_snap_l.get_style_context().add_class("dock-btn")
        btn_snap_l.set_tooltip_text("Snap Active App Left (Split Screen)")
        btn_snap_l.connect("clicked", lambda b: self._resize_top_task(0, 0, 960, 1080))
        self.dock.pack_start(btn_snap_l, False, False, 0)

        # Snap Right (◪)
        btn_snap_r = Gtk.Button(label="◪")
        btn_snap_r.get_style_context().add_class("dock-btn")
        btn_snap_r.set_tooltip_text("Snap Active App Right (Split Screen)")
        btn_snap_r.connect("clicked", lambda b: self._resize_top_task(960, 0, 1920, 1080))
        self.dock.pack_start(btn_snap_r, False, False, 0)

        # Maximize (▢)
        btn_max = Gtk.Button(label="▢")
        btn_max.get_style_context().add_class("dock-btn")
        btn_max.set_tooltip_text("Maximize Active App")
        btn_max.connect("clicked", lambda b: self._resize_top_task(0, 0, 1920, 1080))
        self.dock.pack_start(btn_max, False, False, 0)

        self._add_sep()

        # 4. Running App Tabs Container
        self.tabs_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        self.dock.pack_start(self.tabs_box, False, False, 0)

        self._add_sep()

        # 5. System Tray (Battery, Time, Exit)
        self.lbl_battery = Gtk.Label(label="🔋 --%")
        self.lbl_battery.get_style_context().add_class("tray-label")
        self.dock.pack_start(self.lbl_battery, False, False, 0)

        self.lbl_clock = Gtk.Label(label="--:--")
        self.lbl_clock.get_style_context().add_class("tray-label")
        self.dock.pack_start(self.lbl_clock, False, False, 0)

        btn_exit = Gtk.Button(label="✕")
        btn_exit.get_style_context().add_class("dock-btn")
        btn_exit.set_tooltip_text("Close DeX Bar")
        btn_exit.connect("clicked", lambda b: Gtk.main_quit())
        self.dock.pack_start(btn_exit, False, False, 0)

        self.win.add(self.dock)
        self.win.show_all()

        # Start Menu Popover Window
        self.start_popover = None

    def _add_sep(self):
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        sep.get_style_context().add_class("separator")
        self.dock.pack_start(sep, False, False, 2)

    def _send_key(self, keycode):
        threading.Thread(target=lambda: subprocess.call(["adb", "shell", "input", "keyevent", str(keycode)]), daemon=True).start()

    def _resize_top_task(self, l, t, r, b):
        def worker():
            try:
                # Find top task ID on display
                out = subprocess.check_output(["adb", "shell", "dumpsys", "activity", "activities"]).decode("utf-8")
                import re
                tasks = re.findall(r'Task\{([a-f0-9]+) #(\d+)', out)
                if tasks:
                    task_id = tasks[0][1]
                    print(f"Resizing task #{task_id} to {l} {t} {r} {b}")
                    subprocess.call(["adb", "shell", "am", "task", "resize", task_id, str(l), str(t), str(r), str(b)])
            except Exception as e:
                print("Resize error:", e)
        threading.Thread(target=worker, daemon=True).start()

    def _start_display_detector(self):
        def loop():
            while not self.target_display:
                try:
                    out = subprocess.check_output(["adb", "shell", "dumpsys", "display"], stderr=subprocess.DEVNULL).decode("utf-8")
                    import re
                    matches = re.findall(r'mDisplayId=([1-9][0-9]*)', out)
                    if matches:
                        self.target_display = matches[0]
                        print("Setting display to Freeform mode:", self.target_display)
                        # Switch display to Freeform mode (5)
                        subprocess.call(["adb", "shell", "cmd", "window", "set-display-windowing-mode", "-d", self.target_display, "5"])
                        break
                except Exception:
                    pass
                time.sleep(0.5)
        threading.Thread(target=loop, daemon=True).start()

    def _start_battery_clock_loop(self):
        def update_ui():
            # Update clock
            now = time.strftime("%I:%M %p")
            self.lbl_clock.set_text(now)

            # Update battery
            try:
                out = subprocess.check_output(["adb", "shell", "dumpsys", "battery"], stderr=subprocess.DEVNULL).decode("utf-8")
                for line in out.split("\n"):
                    if "level:" in line:
                        lvl = line.split("level:")[1].strip()
                        self.lbl_battery.set_text(f"🔋 {lvl}%")
                        break
            except Exception:
                pass
            return True

        GLib.timeout_add_seconds(5, update_ui)
        update_ui()

    def _load_apps_async(self):
        def worker():
            try:
                out = subprocess.check_output(["adb", "shell", "pm", "list", "packages", "-3"]).decode("utf-8")
                pkgs = [p.replace("package:", "").strip() for p in out.strip().split("\n") if p.strip()]
                sys_apps = ["com.android.settings", "com.android.chrome", "com.google.android.youtube"]
                for s in sys_apps:
                    if s not in pkgs:
                        pkgs.insert(0, s)

                app_list = []
                for pkg in pkgs:
                    name = pkg.split(".")[-1].capitalize()
                    if "gm" in pkg: name = "Gmail"
                    elif "chrome" in pkg: name = "Chrome"
                    elif "chatgpt" in pkg: name = "ChatGPT"
                    elif "youtube" in pkg or "newpipe" in pkg: name = "YouTube"
                    elif "libreoffice" in pkg: name = "LibreOffice"
                    elif "settings" in pkg: name = "Settings"
                    elif "github" in pkg: name = "GitHub"
                    elif "reddit" in pkg: name = "Reddit"
                    elif "perplexity" in pkg: name = "Perplexity"
                    elif "whatsapp" in pkg: name = "WhatsApp"
                    elif "flipkart" in pkg: name = "Flipkart"
                    app_list.append({"pkg": pkg, "name": name})

                app_list.sort(key=lambda x: x["name"])
                self.installed_apps = app_list
            except Exception as e:
                print("Error loading apps:", e)
        threading.Thread(target=worker, daemon=True).start()

    def _toggle_start_menu(self, btn):
        if self.start_popover and self.start_popover.get_visible():
            self.start_popover.hide()
            return

        if not self.start_popover:
            self.start_popover = Gtk.Window()
            self.start_popover.set_app_paintable(True)
            GtkLayerShell.init_for_window(self.start_popover)
            GtkLayerShell.set_layer(self.start_popover, GtkLayerShell.Layer.OVERLAY)
            GtkLayerShell.set_anchor(self.start_popover, GtkLayerShell.Edge.BOTTOM, True)
            GtkLayerShell.set_margin(self.start_popover, GtkLayerShell.Edge.BOTTOM, 68)

            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            box.set_name("start-popup")
            box.set_size_request(420, 480)

            # Search entry
            self.search_entry = Gtk.SearchEntry()
            self.search_entry.set_placeholder_text("Search phone apps...")
            self.search_entry.connect("search-changed", self._on_search_changed)
            box.pack_start(self.search_entry, False, False, 0)

            # Scrollable Apps FlowBox
            scroller = Gtk.ScrolledWindow()
            scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            
            self.flowbox = Gtk.FlowBox()
            self.flowbox.set_valign(Gtk.Align.START)
            self.flowbox.set_max_children_per_line(4)
            self.flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
            scroller.add(self.flowbox)

            box.pack_start(scroller, True, True, 0)
            self.start_popover.add(box)

        self._populate_start_menu()
        self.start_popover.show_all()

    def _on_search_changed(self, entry):
        self._populate_start_menu(entry.get_text())

    def _populate_start_menu(self, query=""):
        for child in self.flowbox.get_children():
            self.flowbox.remove(child)

        filtered = [a for a in self.installed_apps if not query or query.lower() in a["name"].lower() or query.lower() in a["pkg"].lower()]

        for app in filtered:
            btn = Gtk.Button(label=f"📱\n{app['name'][:10]}")
            btn.get_style_context().add_class("dock-btn")
            btn.set_size_request(90, 60)
            btn.connect("clicked", lambda b, p=app["pkg"], n=app["name"]: self._launch_app(p, n))
            self.flowbox.add(btn)

        self.flowbox.show_all()

    def _launch_app(self, pkg, name):
        if self.start_popover:
            self.start_popover.hide()

        def runner():
            try:
                disp = self.target_display if self.target_display else "0"
                # Launch targeting secondary display in Freeform
                subprocess.call([
                    "adb", "shell", "monkey", "--display", str(disp),
                    "-p", pkg, "-c", "android.intent.category.LAUNCHER", "1"
                ])
                GLib.idle_add(lambda: self._add_app_tab(pkg, name))
            except Exception as e:
                print("Launch error:", e)

        threading.Thread(target=runner, daemon=True).start()

    def _add_app_tab(self, pkg, name):
        if pkg in self.active_tabs:
            return

        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        tab_box.get_style_context().add_class("app-tab")

        btn_tab = Gtk.Button(label=f"📱 {name}")
        btn_tab.get_style_context().add_class("dock-btn")
        btn_tab.connect("clicked", lambda b: self._launch_app(pkg, name))
        tab_box.pack_start(btn_tab, False, False, 0)

        btn_x = Gtk.Button(label="✕")
        btn_x.get_style_context().add_class("dock-btn")
        
        def close_tab(b):
            tab_box.destroy()
            if pkg in self.active_tabs:
                del self.active_tabs[pkg]
            threading.Thread(target=lambda: subprocess.call(["adb", "shell", "am", "force-stop", pkg]), daemon=True).start()

        btn_x.connect("clicked", close_tab)
        tab_box.pack_start(btn_x, False, False, 0)

        tab_box.show_all()
        self.tabs_box.pack_start(tab_box, False, False, 0)
        self.active_tabs[pkg] = tab_box

if __name__ == "__main__":
    app = Win11LayerBar()
    Gtk.main()
