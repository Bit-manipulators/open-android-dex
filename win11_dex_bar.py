#!/usr/bin/env python3
"""
Win11 DeX Taskbar & Navigation Hub
Provides a Windows 11 style centered taskbar with:
- Start Menu (⊞) with phone apps search & launch
- 3 Android Navigation Buttons: Back (◀), Home (●), Recents/Multitask (■)
- Dynamic Active App Tabs
- System Tray (Battery %, Clock, Fullscreen)
Runs 100% on the laptop via ADB with ZERO APKs installed on the phone.
"""

import os
import sys
import subprocess
import threading
import time
import tkinter as tk
from tkinter import ttk

# Dark Windows 11 Palette
BG_COLOR = "#202020"
BG_HOVER = "#2d2d2d"
BG_ACTIVE = "#383838"
ACCENT_BLUE = "#0078d4"
TEXT_COLOR = "#ffffff"
TEXT_MUTED = "#a0a0a0"
BORDER_COLOR = "#2b2b2b"

class Win11DeXBar(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("Win11-DeX-Bar")
        self.configure(bg=BG_COLOR)
        self.overrideredirect(True)  # Borderless dock

        # Screen dimensions
        screen_w = self.winfo_screenwidth()
        screen_h = self.winfo_screenheight()
        bar_w = 980
        bar_h = 56
        bar_x = (screen_w - bar_w) // 2
        bar_y = screen_h - bar_h - 16

        self.geometry(f"{bar_w}x{bar_h}+{bar_x}+{bar_y}")
        self.attributes("-topmost", True)

        self.start_menu_win = None
        self.active_tabs = {}  # {pkg: button_widget}
        self.installed_apps = []
        self.target_display = None

        self._build_ui()
        self._load_apps_async()
        self._start_battery_clock_loop()
        self._start_display_detector()

    def _build_ui(self):
        # Outer container with rounded border feel
        outer = tk.Frame(self, bg=BORDER_COLOR, padx=1, pady=1)
        outer.pack(fill="both", expand=True)

        self.container = tk.Frame(outer, bg=BG_COLOR, padx=12, pady=4)
        self.container.pack(fill="both", expand=True)

        # Left Section: Start Button (⊞)
        self.btn_start = self._create_icon_btn(self.container, "⊞", self._toggle_start_menu, font=("Sans", 16, "bold"), fg=ACCENT_BLUE)
        self.btn_start.pack(side="left", padx=4)

        # Separator
        self._create_separator(self.container).pack(side="left", padx=6, fill="y", pady=6)

        # Middle Section 1: The 3 Android Buttons
        # 1. Back (◀)
        self.btn_back = self._create_icon_btn(self.container, "◀", lambda: self._send_key(4), tip="Back (Esc)")
        self.btn_back.pack(side="left", padx=3)

        # 2. Home (●)
        self.btn_home = self._create_icon_btn(self.container, "●", lambda: self._send_key(3), tip="Home")
        self.btn_home.pack(side="left", padx=3)

        # 3. Recents / Multitasking (■)
        self.btn_recents = self._create_icon_btn(self.container, "■", lambda: self._send_key(187), tip="Recents / App Switcher")
        self.btn_recents.pack(side="left", padx=3)

        # Separator
        self._create_separator(self.container).pack(side="left", padx=6, fill="y", pady=6)

        # Middle Section 2: Active App Tabs Frame
        self.tabs_frame = tk.Frame(self.container, bg=BG_COLOR)
        self.tabs_frame.pack(side="left", fill="both", expand=True, padx=4)

        # Right Section: System Tray (Battery, Time, Fullscreen)
        tray_frame = tk.Frame(self.container, bg=BG_COLOR)
        tray_frame.pack(side="right", padx=4)

        self.lbl_battery = tk.Label(tray_frame, text="🔋 --%", font=("Sans", 10), bg=BG_COLOR, fg=TEXT_MUTED)
        self.lbl_battery.pack(side="left", padx=6)

        self.lbl_clock = tk.Label(tray_frame, text="--:--", font=("Sans", 10, "bold"), bg=BG_COLOR, fg=TEXT_COLOR)
        self.lbl_clock.pack(side="left", padx=6)

        btn_fs = self._create_icon_btn(tray_frame, "⛶", self._toggle_fullscreen, tip="Toggle Fullscreen")
        btn_fs.pack(side="left", padx=4)

        btn_close = self._create_icon_btn(tray_frame, "✕", self._quit_all, tip="Exit DeX Bar", hover_bg="#c42b1c")
        btn_close.pack(side="left", padx=2)

    def _create_icon_btn(self, parent, text, command, font=("Sans", 12), fg=TEXT_COLOR, tip="", hover_bg=BG_HOVER):
        lbl = tk.Label(parent, text=text, font=font, bg=BG_COLOR, fg=fg, padx=12, pady=6, cursor="hand2")
        lbl.bind("<Button-1>", lambda e: command())
        lbl.bind("<Enter>", lambda e: lbl.configure(bg=hover_bg))
        lbl.bind("<Leave>", lambda e: lbl.configure(bg=BG_COLOR))
        return lbl

    def _create_separator(self, parent):
        return tk.Frame(parent, width=1, bg=BORDER_COLOR)

    def _send_key(self, keycode):
        def worker():
            try:
                subprocess.call(["adb", "shell", "input", "keyevent", str(keycode)])
            except Exception as e:
                print("Keyevent error:", e)
        threading.Thread(target=worker, daemon=True).start()

    def _toggle_fullscreen(self):
        def worker():
            try:
                subprocess.call(["hyprctl", "dispatch", "fullscreen", "0"])
            except Exception:
                pass
        threading.Thread(target=worker, daemon=True).start()

    def _quit_all(self):
        self.destroy()
        sys.exit(0)

    def _start_display_detector(self):
        def detector():
            while not self.target_display:
                try:
                    out = subprocess.check_output(["adb", "shell", "dumpsys", "display"], stderr=subprocess.DEVNULL).decode("utf-8")
                    import re
                    matches = re.findall(r'mDisplayId=([1-9][0-9]*)', out)
                    if matches:
                        self.target_display = matches[0]
                        print("Win11 Bar attached to Display ID:", self.target_display)
                        break
                except Exception:
                    pass
                time.sleep(1)
        threading.Thread(target=detector, daemon=True).start()

    def _start_battery_clock_loop(self):
        def loop():
            while True:
                # Update Clock
                now = time.strftime("%I:%M %p")
                self.after(0, lambda: self.lbl_clock.config(text=now))

                # Update Battery
                try:
                    out = subprocess.check_output(["adb", "shell", "dumpsys", "battery"], stderr=subprocess.DEVNULL).decode("utf-8")
                    for line in out.split("\n"):
                        if "level:" in line:
                            lvl = line.split("level:")[1].strip()
                            self.after(0, lambda l=lvl: self.lbl_battery.config(text=f"🔋 {l}%"))
                            break
                except Exception:
                    pass
                time.sleep(10)

        threading.Thread(target=loop, daemon=True).start()

    def _load_apps_async(self):
        def worker():
            try:
                # Get third party installed apps
                out = subprocess.check_output(["adb", "shell", "pm", "list", "packages", "-3"]).decode("utf-8")
                pkgs = [p.replace("package:", "").strip() for p in out.strip().split("\n") if p.strip()]
                
                # Add core system apps (Settings, Files, Chrome)
                sys_apps = ["com.android.settings", "com.android.chrome", "com.google.android.apps.photos", "com.google.android.youtube"]
                for sa in sys_apps:
                    if sa not in pkgs:
                        pkgs.insert(0, sa)

                app_list = []
                for pkg in pkgs:
                    # Pretty label: last part of package or well known names
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

                    app_list.append({"pkg": pkg, "name": name})

                app_list.sort(key=lambda x: x["name"])
                self.installed_apps = app_list
            except Exception as e:
                print("Error loading apps:", e)

        threading.Thread(target=worker, daemon=True).start()

    def _toggle_start_menu(self):
        if self.start_menu_win and self.start_menu_win.winfo_exists():
            self.start_menu_win.destroy()
            self.start_menu_win = None
            return

        # Create Windows 11 style Start Menu popup
        sm = tk.Toplevel(self)
        sm.title("Win11-Start-Menu")
        sm.configure(bg=BG_COLOR)
        sm.overrideredirect(True)
        sm.attributes("-topmost", True)

        menu_w = 480
        menu_h = 520
        # Position right above the taskbar
        bx = self.winfo_x() + 40
        by = self.winfo_y() - menu_h - 12
        sm.geometry(f"{menu_w}x{menu_h}+{bx}+{by}")

        outer = tk.Frame(sm, bg=BORDER_COLOR, padx=1, pady=1)
        outer.pack(fill="both", expand=True)

        inner = tk.Frame(outer, bg=BG_COLOR, padx=16, pady=16)
        inner.pack(fill="both", expand=True)

        # Search Bar
        search_frame = tk.Frame(inner, bg=BG_HOVER, padx=8, pady=6)
        search_frame.pack(fill="x", pady=(0, 14))

        tk.Label(search_frame, text="🔍", bg=BG_HOVER, fg=TEXT_MUTED, font=("Sans", 11)).pack(side="left", padx=(0, 6))
        search_var = tk.StringVar()
        search_entry = tk.Entry(search_frame, textvariable=search_var, bg=BG_HOVER, fg=TEXT_COLOR,
                                insertbackground=TEXT_COLOR, relief="flat", font=("Sans", 11))
        search_entry.pack(side="left", fill="x", expand=True)
        search_entry.focus_set()

        # Pinned Header
        tk.Label(inner, text="Pinned Phone Apps", font=("Sans", 10, "bold"), fg=TEXT_MUTED, bg=BG_COLOR).pack(anchor="w", pady=(0, 8))

        # Apps Grid / Scrollable Frame
        canvas = tk.Canvas(inner, bg=BG_COLOR, highlightthickness=0)
        scrollbar = tk.Scrollbar(inner, orient="vertical", command=canvas.yview)
        grid_frame = tk.Frame(canvas, bg=BG_COLOR)

        grid_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=grid_frame, anchor="nw", width=420)
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        def render_apps(query=""):
            for child in grid_frame.winfo_children():
                child.destroy()

            filtered = [a for a in self.installed_apps if not query or query.lower() in a["name"].lower() or query.lower() in a["pkg"].lower()]

            row = 0
            col = 0
            for app in filtered:
                btn_card = tk.Frame(grid_frame, bg=BG_COLOR, padx=6, pady=6, cursor="hand2")
                btn_card.grid(row=row, column=col, padx=4, pady=4, sticky="nsew")

                lbl_icon = tk.Label(btn_card, text="📱", font=("Sans", 18), bg=BG_COLOR, fg=ACCENT_BLUE)
                lbl_icon.pack()

                lbl_name = tk.Label(btn_card, text=app["name"][:12], font=("Sans", 9), bg=BG_COLOR, fg=TEXT_COLOR)
                lbl_name.pack()

                def make_click(p=app["pkg"], n=app["name"]):
                    return lambda e: self._launch_app(p, n)

                btn_card.bind("<Button-1>", make_click())
                lbl_icon.bind("<Button-1>", make_click())
                lbl_name.bind("<Button-1>", make_click())

                def on_enter(c=btn_card): c.configure(bg=BG_HOVER)
                def on_leave(c=btn_card): c.configure(bg=BG_COLOR)
                btn_card.bind("<Enter>", lambda e, c=btn_card: on_enter(c))
                btn_card.bind("<Leave>", lambda e, c=btn_card: on_leave(c))

                col += 1
                if col >= 4:
                    col = 0
                    row += 1

        render_apps()
        search_var.trace_add("write", lambda *args: render_apps(search_var.get()))

        self.start_menu_win = sm

    def _launch_app(self, pkg, name):
        if self.start_menu_win and self.start_menu_win.winfo_exists():
            self.start_menu_win.destroy()
            self.start_menu_win = None

        def runner():
            try:
                # If target display known, launch directly onto it
                if self.target_display:
                    subprocess.call([
                        "adb", "shell", "monkey", "--display", str(self.target_display),
                        "-p", pkg, "-c", "android.intent.category.LAUNCHER", "1"
                    ])
                else:
                    subprocess.call([
                        "adb", "shell", "monkey", "-p", pkg,
                        "-c", "android.intent.category.LAUNCHER", "1"
                    ])
                self.after(0, lambda: self._add_app_tab(pkg, name))
            except Exception as e:
                print(f"Error launching {pkg}: {e}")

        threading.Thread(target=runner, daemon=True).start()

    def _add_app_tab(self, pkg, name):
        if pkg in self.active_tabs:
            return

        tab = tk.Frame(self.tabs_frame, bg=BG_HOVER, padx=8, pady=4, cursor="hand2")
        tab.pack(side="left", padx=3)

        lbl = tk.Label(tab, text=f"📱 {name}", font=("Sans", 10), bg=BG_HOVER, fg=TEXT_COLOR)
        lbl.pack(side="left", padx=(0, 6))

        # Close button for tab
        lbl_x = tk.Label(tab, text="✕", font=("Sans", 9), bg=BG_HOVER, fg=TEXT_MUTED, cursor="hand2")
        lbl_x.pack(side="right")

        def focus_app(e=None):
            self._launch_app(pkg, name)

        def close_tab(e=None):
            tab.destroy()
            if pkg in self.active_tabs:
                del self.active_tabs[pkg]
            # Optional: force stop app on phone
            threading.Thread(target=lambda: subprocess.call(["adb", "shell", "am", "force-stop", pkg]), daemon=True).start()

        tab.bind("<Button-1>", focus_app)
        lbl.bind("<Button-1>", focus_app)
        lbl_x.bind("<Button-1>", close_tab)

        def on_enter(e): tab.configure(bg=BG_ACTIVE); lbl.configure(bg=BG_ACTIVE); lbl_x.configure(bg=BG_ACTIVE)
        def on_leave(e): tab.configure(bg=BG_HOVER); lbl.configure(bg=BG_HOVER); lbl_x.configure(bg=BG_HOVER)
        tab.bind("<Enter>", on_enter)
        tab.bind("<Leave>", on_leave)

        self.active_tabs[pkg] = tab

if __name__ == "__main__":
    app = Win11DeXBar()
    app.mainloop()
