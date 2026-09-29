#!/usr/bin/env python3
"""
OpenDeX Control Hub
A modern desktop manager for running Android DeX over ADB with freeform window resizing,
multitasking, and app tabs inside a single unified laptop window.
"""

import os
import sys
import subprocess
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TASKBAR_APK = os.path.join(SCRIPT_DIR, "Taskbar-6.2.2.apk")
TASKBAR_PKG = "com.farmerbb.taskbar"

class OpenDeXApp(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("OpenDeX - Android Desktop Hub")
        self.geometry("820x650")
        self.minsize(720, 560)
        self.configure(bg="#181825")  # Catppuccin Mocha Dark

        self.device_connected = False
        self.device_name = "Checking..."
        self.device_android = ""
        self.scrcpy_proc = None

        self._init_styles()
        self._build_ui()
        self._start_device_poller()

    def _init_styles(self):
        style = ttk.Style(self)
        style.theme_use("clam")

        # Configure generic colors
        style.configure(".", background="#181825", foreground="#cdd6f4", font=("Sans", 10))
        style.configure("TFrame", background="#181825")
        style.configure("Card.TFrame", background="#1e1e2e", relief="flat")
        
        style.configure("Header.TLabel", font=("Sans", 18, "bold"), foreground="#89b4fa", background="#181825")
        style.configure("Subheader.TLabel", font=("Sans", 10), foreground="#a6adc8", background="#181825")
        style.configure("Section.TLabel", font=("Sans", 12, "bold"), foreground="#f5c2e7", background="#1e1e2e")
        style.configure("Card.TLabel", font=("Sans", 10), foreground="#cdd6f4", background="#1e1e2e")
        style.configure("StatusGreen.TLabel", font=("Sans", 11, "bold"), foreground="#a6e3a1", background="#1e1e2e")
        style.configure("StatusRed.TLabel", font=("Sans", 11, "bold"), foreground="#f38ba8", background="#1e1e2e")

        style.configure("Primary.TButton", 
                        font=("Sans", 12, "bold"), 
                        background="#89b4fa", 
                        foreground="#11111b", 
                        padding=10, 
                        borderwidth=0)
        style.map("Primary.TButton",
                  background=[("active", "#b4befe"), ("disabled", "#45475a")])

        style.configure("Secondary.TButton", 
                        font=("Sans", 10), 
                        background="#313244", 
                        foreground="#cdd6f4", 
                        padding=6, 
                        borderwidth=0)
        style.map("Secondary.TButton",
                  background=[("active", "#45475a")])

        style.configure("TCombobox", 
                        fieldbackground="#313244", 
                        background="#313244", 
                        foreground="#cdd6f4", 
                        arrowcolor="#89b4fa")

    def _build_ui(self):
        # Top Header Banner
        header_frame = ttk.Frame(self, padding=(24, 16))
        header_frame.pack(fill="x")

        ttk.Label(header_frame, text="💻 OpenDeX Workstation", style="Header.TLabel").pack(anchor="w")
        ttk.Label(header_frame, text="Unified single-window Android desktop with multi-window resizing & multitasking", style="Subheader.TLabel").pack(anchor="w", pady=(2, 0))

        # Main Container (2 columns)
        content_frame = ttk.Frame(self, padding=(24, 0))
        content_frame.pack(fill="both", expand=True)

        left_col = ttk.Frame(content_frame)
        left_col.pack(side="left", fill="both", expand=True, padx=(0, 12))

        right_col = ttk.Frame(content_frame)
        right_col.pack(side="right", fill="both", expand=True, padx=(12, 0))

        # --- LEFT COLUMN: Device Status & Launch Controls ---
        # Card 1: Device Status
        status_card = ttk.Frame(left_col, style="Card.TFrame", padding=16)
        status_card.pack(fill="x", pady=(0, 16))

        ttk.Label(status_card, text="📱 Android Device Connection", style="Section.TLabel").pack(anchor="w", pady=(0, 8))
        self.lbl_status = ttk.Label(status_card, text="Scanning for device...", style="StatusRed.TLabel")
        self.lbl_status.pack(anchor="w")

        self.lbl_device_info = ttk.Label(status_card, text="Connect phone via USB with USB Debugging enabled.", style="Card.TLabel")
        self.lbl_device_info.pack(anchor="w", pady=(4, 8))

        btn_row = ttk.Frame(status_card, style="Card.TFrame")
        btn_row.pack(fill="x")
        ttk.Button(btn_row, text="🔄 Refresh Devices", style="Secondary.TButton", command=self._refresh_device_status).pack(side="left", padx=(0, 8))
        ttk.Button(btn_row, text="📶 Switch to Wireless ADB", style="Secondary.TButton", command=self._setup_wireless_adb).pack(side="left")

        # Card 2: Display & Desktop Settings
        settings_card = ttk.Frame(left_col, style="Card.TFrame", padding=16)
        settings_card.pack(fill="x", pady=(0, 16))

        ttk.Label(settings_card, text="⚙️ Display & UI Density", style="Section.TLabel").pack(anchor="w", pady=(0, 10))

        # Resolution dropdown
        row_res = ttk.Frame(settings_card, style="Card.TFrame")
        row_res.pack(fill="x", pady=4)
        ttk.Label(row_res, text="Resolution:", style="Card.TLabel", width=14).pack(side="left")
        self.res_var = tk.StringVar(value="1920x1080 (Full HD)")
        res_cb = ttk.Combobox(row_res, textvariable=self.res_var, state="readonly", values=[
            "1920x1080 (Full HD)",
            "2560x1440 (2K QHD)",
            "1600x900 (HD+)",
            "1366x768 (Laptop HD)",
            "3840x2160 (4K UHD)"
        ])
        res_cb.pack(side="left", fill="x", expand=True)

        # DPI dropdown
        row_dpi = ttk.Frame(settings_card, style="Card.TFrame")
        row_dpi.pack(fill="x", pady=4)
        ttk.Label(row_dpi, text="UI Scale (DPI):", style="Card.TLabel", width=14).pack(side="left")
        self.dpi_var = tk.StringVar(value="180 (Crisp Desktop)")
        dpi_cb = ttk.Combobox(row_dpi, textvariable=self.dpi_var, state="readonly", values=[
            "160 (Compact PC)",
            "180 (Crisp Desktop)",
            "200 (Comfortable)",
            "220 (Large)",
            "240 (Touch-Friendly)"
        ])
        dpi_cb.pack(side="left", fill="x", expand=True)

        # Flags checkboxes
        self.var_freeform = tk.BooleanVar(value=True)
        self.var_audio = tk.BooleanVar(value=True)
        self.var_taskbar = tk.BooleanVar(value=True)

        chk_frame = ttk.Frame(settings_card, style="Card.TFrame")
        chk_frame.pack(fill="x", pady=(10, 0))

        tk.Checkbutton(chk_frame, text="Enable Freeform Window Resizing", variable=self.var_freeform,
                       bg="#1e1e2e", fg="#cdd6f4", selectcolor="#313244", activebackground="#1e1e2e", activeforeground="#cdd6f4").pack(anchor="w")
        tk.Checkbutton(chk_frame, text="Forward Mobile Audio to Laptop", variable=self.var_audio,
                       bg="#1e1e2e", fg="#cdd6f4", selectcolor="#313244", activebackground="#1e1e2e", activeforeground="#cdd6f4").pack(anchor="w")
        tk.Checkbutton(chk_frame, text="Native Desktop Launcher & Dock", variable=self.var_taskbar,
                       bg="#1e1e2e", fg="#cdd6f4", selectcolor="#313244", activebackground="#1e1e2e", activeforeground="#cdd6f4").pack(anchor="w")

        # Action: Launch OpenDeX
        self.btn_launch = ttk.Button(left_col, text="🚀 Launch OpenDeX (Single Window)", style="Primary.TButton", command=self.launch_dex)
        self.btn_launch.pack(fill="x", pady=(8, 0))

        # --- RIGHT COLUMN: App Launcher & Controls ---
        right_card = ttk.Frame(right_col, style="Card.TFrame", padding=16)
        right_card.pack(fill="both", expand=True, pady=(0, 16))

        ttk.Label(right_card, text="📦 Quick Launch App Tabs", style="Section.TLabel").pack(anchor="w", pady=(0, 6))
        ttk.Label(right_card, text="Click any app below to open it directly into the DeX window:", style="Card.TLabel").pack(anchor="w", pady=(0, 8))

        # Apps search and listbox
        search_frame = ttk.Frame(right_card, style="Card.TFrame")
        search_frame.pack(fill="x", pady=(0, 6))
        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *args: self._filter_apps())
        search_entry = tk.Entry(search_frame, textvariable=self.search_var, bg="#313244", fg="#cdd6f4", insertbackground="#cdd6f4", relief="flat")
        search_entry.pack(side="left", fill="x", expand=True, ipady=4, padx=(0, 6))

        ttk.Button(search_frame, text="Load Apps", style="Secondary.TButton", command=self._load_installed_apps).pack(side="right")

        list_container = ttk.Frame(right_card, style="Card.TFrame")
        list_container.pack(fill="both", expand=True)

        scrollbar = tk.Scrollbar(list_container)
        scrollbar.pack(side="right", fill="y")

        self.app_listbox = tk.Listbox(list_container, bg="#313244", fg="#cdd6f4", selectbackground="#89b4fa", selectforeground="#11111b",
                                      relief="flat", highlightthickness=0, yscrollcommand=scrollbar.set)
        self.app_listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.app_listbox.yview)

        self.app_listbox.bind("<Double-Button-1>", lambda e: self._launch_selected_app())

        btn_app_row = ttk.Frame(right_card, style="Card.TFrame")
        btn_app_row.pack(fill="x", pady=(8, 0))
        ttk.Button(btn_app_row, text="Launch Selected App Tab", style="Secondary.TButton", command=self._launch_selected_app).pack(side="left", fill="x", expand=True)

        self.all_apps = []

        # Bottom Bar: Shortcuts Guide
        footer = ttk.Frame(self, padding=(24, 8), style="Card.TFrame")
        footer.pack(fill="x", side="bottom")
        shortcuts_text = "💡 Controls: Drag edges to resize | Right-click = Back | Middle-click = Home | Alt+f = Fullscreen | Alt+Tab = Switch App Tabs"
        ttk.Label(footer, text=shortcuts_text, style="Card.TLabel", font=("Sans", 9)).pack(anchor="center")

    def _start_device_poller(self):
        t = threading.Thread(target=self._poll_device_loop, daemon=True)
        t.start()

    def _poll_device_loop(self):
        while True:
            self._check_adb()
            time.sleep(3)

    def _check_adb(self):
        try:
            out = subprocess.check_output(["adb", "devices"], stderr=subprocess.STDOUT).decode("utf-8")
            lines = [l for l in out.strip().split("\n")[1:] if l.strip() and not l.startswith("*")]
            if lines and "device" in lines[0]:
                model = subprocess.check_output(["adb", "shell", "getprop", "ro.product.model"]).decode("utf-8").strip()
                version = subprocess.check_output(["adb", "shell", "getprop", "ro.build.version.release"]).decode("utf-8").strip()
                self.device_connected = True
                self.device_name = model
                self.device_android = version
                self.after(0, self._update_device_ui, True)
            else:
                self.device_connected = False
                self.after(0, self._update_device_ui, False)
        except Exception:
            self.device_connected = False
            self.after(0, self._update_device_ui, False)

    def _update_device_ui(self, connected):
        if connected:
            self.lbl_status.config(text="● Device Ready", style="StatusGreen.TLabel")
            self.lbl_device_info.config(text=f"Phone: {self.device_name} (Android {self.device_android})")
            self.btn_launch.config(state="normal")
        else:
            self.lbl_status.config(text="○ No Device Connected", style="StatusRed.TLabel")
            self.lbl_device_info.config(text="Please connect phone via USB with USB Debugging enabled.")

    def _refresh_device_status(self):
        threading.Thread(target=self._check_adb, daemon=True).start()

    def _setup_wireless_adb(self):
        # Dialog to enable wireless ADB
        dialog = tk.Toplevel(self)
        dialog.title("Setup Wireless ADB")
        dialog.geometry("420x240")
        dialog.configure(bg="#181825")

        ttk.Label(dialog, text="📶 Connect Wirelessly", style="Header.TLabel", font=("Sans", 14, "bold")).pack(anchor="w", padx=16, pady=(16, 8))
        ttk.Label(dialog, text="1. Make sure phone & laptop are on the same Wi-Fi.\n2. Phone must be connected via USB once to start TCP/IP mode.", style="Card.TLabel").pack(anchor="w", padx=16)

        entry_frame = ttk.Frame(dialog, padding=16)
        entry_frame.pack(fill="x")
        ttk.Label(entry_frame, text="Phone IP:Port:").pack(side="left")
        ip_entry = tk.Entry(entry_frame, bg="#313244", fg="#cdd6f4", insertbackground="#cdd6f4")
        ip_entry.insert(0, "192.168.1.XX:5555")
        ip_entry.pack(side="left", fill="x", expand=True, padx=(8, 0))

        def enable_tcpip():
            try:
                subprocess.check_call(["adb", "tcpip", "5555"])
                messagebox.showinfo("Success", "TCP/IP mode started on port 5555!\nYou can now unplug USB and enter phone IP to connect.")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to enable TCP/IP: {e}")

        def do_connect():
            target = ip_entry.get().strip()
            try:
                out = subprocess.check_output(["adb", "connect", target]).decode("utf-8")
                messagebox.showinfo("Result", out)
                dialog.destroy()
                self._refresh_device_status()
            except Exception as e:
                messagebox.showerror("Error", f"Connection failed: {e}")

        btn_row = ttk.Frame(dialog, padding=16)
        btn_row.pack(fill="x")
        ttk.Button(btn_row, text="1. Start TCP/IP (USB)", style="Secondary.TButton", command=enable_tcpip).pack(side="left", padx=(0, 8))
        ttk.Button(btn_row, text="2. Connect IP", style="Primary.TButton", command=do_connect).pack(side="right")

    def _load_installed_apps(self):
        if not self.device_connected:
            messagebox.showwarning("Warning", "Please connect a device first.")
            return

        def load_thread():
            try:
                out = subprocess.check_output(["adb", "shell", "pm", "list", "packages", "-3"]).decode("utf-8")
                packages = [p.replace("package:", "").strip() for p in out.strip().split("\n") if p.strip()]
                packages.sort()
                self.all_apps = packages
                self.after(0, self._filter_apps)
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("Error", f"Failed to fetch apps: {e}"))

        threading.Thread(target=load_thread, daemon=True).start()

    def _filter_apps(self):
        query = self.search_var.get().lower().strip()
        self.app_listbox.delete(0, tk.END)
        for app in self.all_apps:
            if not query or query in app.lower():
                self.app_listbox.insert(tk.END, app)

    def _launch_selected_app(self):
        selected = self.app_listbox.curselection()
        if not selected:
            return
        pkg = self.app_listbox.get(selected[0])

        def launch_thread():
            try:
                # Launch monkey intent or package main activity
                subprocess.check_call([
                    "adb", "shell", "monkey", "-p", pkg,
                    "-c", "android.intent.category.LAUNCHER", "1"
                ])
            except Exception as e:
                print(f"Error launching {pkg}: {e}")

        threading.Thread(target=launch_thread, daemon=True).start()

    def launch_dex(self):
        if not self.device_connected:
            messagebox.showwarning("No Device", "Please connect an Android device with USB debugging enabled.")
            return

        res = self.res_var.get().split(" ")[0]
        dpi = self.dpi_var.get().split(" ")[0]

        def runner():
            try:
                # 1. Set global flags
                if self.var_freeform.get():
                    subprocess.call(["adb", "shell", "settings", "put", "global", "enable_freeform_support", "1"])
                    subprocess.call(["adb", "shell", "settings", "put", "global", "force_resizable_activities", "1"])
                    subprocess.call(["adb", "shell", "settings", "put", "global", "force_desktop_mode_on_external_displays", "1"])
                    subprocess.call(["adb", "shell", "setprop", "persist.wm.debug.desktop_mode", "1"])

                # 2. Background watcher: Auto-launch Native Desktop Home on the new display
                def watch_and_launch():
                    for _ in range(30):
                        time.sleep(0.5)
                        try:
                            out = subprocess.check_output(
                                ["adb", "shell", "dumpsys", "display"], stderr=subprocess.DEVNULL
                            ).decode("utf-8")
                            import re
                            matches = re.findall(r'mDisplayId=([1-9][0-9]*)', out)
                            if matches:
                                new_id = matches[0]
                                subprocess.call([
                                    "adb", "shell", "am", "start", "--display", new_id,
                                    "-n", "com.android.launcher3/.secondarydisplay.SecondaryDisplayLauncher"
                                ])
                                break
                        except Exception:
                            pass

                threading.Thread(target=watch_and_launch, daemon=True).start()

                # 3. Apply Hyprland rules if present
                subprocess.call(["hyprctl", "keyword", "windowrulev2", "float,title:^(OpenDeX.*)$"], stderr=subprocess.DEVNULL)
                subprocess.call(["hyprctl", "keyword", "windowrulev2", "size 1600 900,title:^(OpenDeX.*)$"], stderr=subprocess.DEVNULL)
                subprocess.call(["hyprctl", "keyword", "windowrulev2", "float,title:^(Win11-DeX-Bar)$"], stderr=subprocess.DEVNULL)
                subprocess.call(["hyprctl", "keyword", "windowrulev2", "pin,title:^(Win11-DeX-Bar)$"], stderr=subprocess.DEVNULL)

                # 4. Launch Win11 Taskbar
                bar_script = os.path.join(SCRIPT_DIR, "win11_dex_bar.py")
                bar_proc = subprocess.Popen([sys.executable, bar_script])

                # 5. Assemble scrcpy command (Zero APK, 100% Native)
                cmd = [
                    "scrcpy",
                    f"--new-display={res}/{dpi}",
                    "--window-title=OpenDeX Workstation",
                    "--keyboard=sdk",
                    "--mouse=sdk",
                    "--video-bit-rate=12M",
                    "--max-fps=60",
                    "--stay-awake"
                ]

                if not self.var_audio.get():
                    cmd.append("--no-audio")

                print("Running command:", " ".join(cmd))
                self.scrcpy_proc = subprocess.Popen(cmd)
                self.scrcpy_proc.wait()
                bar_proc.terminate()
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("OpenDeX Error", f"Failed to start OpenDeX: {e}"))

        threading.Thread(target=runner, daemon=True).start()

if __name__ == "__main__":
    app = OpenDeXApp()
    app.mainloop()
