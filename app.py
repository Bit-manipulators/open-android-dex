"""Open Android Dex — Clean-room GTK4 desktop application.

An original, from-scratch desktop shell for controlling Android phones
from Linux via ADB and scrcpy, presented as a desktop-style environment
(wallpaper, status bar, app drawer, dock). Built independently; any
similarity in *behavior* to other desktop-phone projects comes from
their public documentation only.

  * Desktop shell: wallpaper, top status bar (clock, battery, volume,
    device picker, search omnibar), app drawer of installed phone apps, bottom dock
  * Sequenced boot flow with progress feedback (start ADB, detect device,
    verify link, confirm mirroring support)
  * Control of the phone (Home, Back, Recent Apps, Lock, Volume, Screenshot,
    Notification shade, DPAD via Ctrl+Shift+Arrow shortcuts)
  * Opening URLs and searching apps from the Omnibar

All code in this repository is original work written from scratch. No
code, strings, assets, binaries, or configuration from any third-party
or closed-source application are used or distributed.
"""

from __future__ import annotations

import datetime
import os
import re
import threading
from dataclasses import dataclass, field
from typing import Callable, List, Optional, Tuple

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Pango", "1.0")

from gi.repository import Gtk, Gio, Gdk, GLib, Pango  # noqa: E402

from adb_client import AdbClient, Device
from scrcpy_client import ScrcpyClient
from input_controller import InputController
from volume_control import VolumeControl
from url_launcher import UrlLauncher
from window_manager import WindowManager
from device_manager import DeviceManager
from boot_manager import BootManager, BootEvent


APP_ID = "io.github.amit.OpenAndroidDex"
APP_NAME = "Open Android Dex"
ASSETS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")

WELL_KNOWN_APPS: dict[str, tuple[str, Optional[str], int]] = {
    # package: (Display Name, Freedesktop System Icon, gradient_color_index)
    "com.android.chrome": ("Chrome", "google-chrome", 0),
    "org.mozilla.firefox": ("Firefox", "firefox", 3),
    "com.android.settings": ("Settings", "preferences-system-symbolic", 11),
    "com.android.messaging": ("Messages", "mail-unread-symbolic", 2),
    "com.android.vending": ("Play Store", "software-properties-symbolic", 4),
    "com.google.android.calculator": ("Calculator", "accessories-calculator-symbolic", 3),
    "com.google.android.contacts": ("Contacts", "contact-new-symbolic", 0),
    "com.google.android.deskclock": ("Clock", "preferences-system-time-symbolic", 1),
    "com.motorola.camera3": ("Camera", "camera-photo-symbolic", 6),
    "org.codeaurora.snapcam": ("Camera", "camera-photo-symbolic", 6),
    "com.google.android.apps.photos": ("Photos", "image-x-generic-symbolic", 5),
    "org.lineageos.glimpse": ("Gallery", "image-x-generic-symbolic", 1),
    "com.google.android.gm": ("Gmail", "mail-unread-symbolic", 9),
    "com.google.android.youtube": ("YouTube", "video-x-generic-symbolic", 9),
    "com.whatsapp": ("WhatsApp", "chat-symbolic", 2),
    "org.telegram.messenger": ("Telegram", "send-to-symbolic", 0),
    "com.openai.chatgpt": ("ChatGPT", None, 7),
    "com.github.android": ("GitHub", None, 11),
    "com.termux": ("Termux", "utilities-terminal-symbolic", 11),
    "com.termux.api": ("Termux API", "utilities-terminal-symbolic", 11),
    "org.videolan.vlc": ("VLC", "video-x-generic-symbolic", 6),
    "com.google.android.apps.maps": ("Maps", "find-location-symbolic", 2),
    "com.spotify.music": ("Spotify", "multimedia-audio-player-symbolic", 2),
    "com.android.documentsui": ("Files", "system-file-manager-symbolic", 0),
    "com.google.android.apps.nbu.files": ("Files", "system-file-manager-symbolic", 0),
    "org.documentfoundation.libreoffice": ("LibreOffice", None, 3),
    "com.canva.editor": ("Canva", None, 8),
    "com.reddit.frontpage": ("Reddit", None, 6),
    "com.ubercab": ("Uber", None, 11),
    "com.olacabs.customer": ("Ola", None, 3),
    "com.pinterest": ("Pinterest", None, 9),
    "com.phonepe.app": ("PhonePe", None, 8),
    "com.linkedin.android": ("LinkedIn", None, 0),
    "com.instagram.android": ("Instagram", "camera-photo-symbolic", 1),
    "ch.protonmail.android": ("Proton Mail", "mail-unread-symbolic", 8),
    "org.schabi.newpipe": ("NewPipe", "video-x-generic-symbolic", 9),
    "com.google.android.apps.docs": ("Docs", None, 0),
    "com.microsoft.office.word": ("Word", None, 0),
    "in.amazon.mShop.android.shopping": ("Amazon", None, 6),
    "com.whereismytrain.android": ("Where is my Train", None, 2),
    "com.x8bit.bitwarden": ("Bitwarden", None, 0),
    "org.fdroid.fdroid": ("F-Droid", None, 7),
    "org.kde.kdeconnect_tp": ("KDE Connect", None, 0),
    "com.digilocker.android": ("DigiLocker", None, 5),
    "com.jpl.jiomart": ("JioMart", None, 6),
    "ai.perplexity.app.android": ("Perplexity", None, 7),
    "com.discord": ("Discord", None, 4),
    "com.anthropic.claude": ("Claude", None, 3),
    "com.google.android.apps.bard": ("Gemini", None, 0),
    "com.google.android.dialer": ("Phone", "call-start-symbolic", 2),
    "com.bigbasket.mobileapp": ("BigBasket", None, 2),
    "com.dts.freefiremax": ("Free Fire MAX", None, 6),
    "com.chalo.crut": ("Chalo", None, 0),
    "com.cashkaro": ("CashKaro", None, 6),
    "com.fampay.in": ("FamPay", None, 3),
    "com.amazon.aws.console.mobile": ("AWS Console", None, 3),
    "com.bitwarden.authenticator": ("Bitwarden 2FA", None, 0),
    "com.google.android.apps.classroom": ("Classroom", None, 2),
}

CSS = b"""
/* Glassmorphism Variables & Base */
window {
    background-color: #0b0f19;
}

/* Top Status Bar */
.desk-topbar {
    background-color: rgba(11, 15, 25, 0.78);
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding: 7px 18px;
}

.desk-brand-badge {
    color: #38bdf8;
    font-weight: 800;
    font-size: 15px;
    letter-spacing: 0.5px;
    margin-right: 6px;
}

/* Connected Device Pill */
.desk-device-pill {
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 16px;
    padding: 3px 12px;
}

.desk-device-pill:hover {
    background-color: rgba(255, 255, 255, 0.12);
    border-color: rgba(255, 255, 255, 0.20);
}

.desk-status-dot-online {
    color: #22c55e;
    font-size: 11px;
}

.desk-status-dot-offline {
    color: #ef4444;
    font-size: 11px;
}

/* Omnibar (Search & URL in Header) */
.desk-omnibar {
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 20px;
    padding: 2px 14px;
    color: #ffffff;
    min-width: 360px;
}

.desk-omnibar:focus-within {
    background-color: rgba(255, 255, 255, 0.14);
    border-color: #38bdf8;
    box-shadow: 0 0 12px rgba(56, 189, 248, 0.32);
}

/* System Tray Chips */
.desk-chip {
    background-color: rgba(255, 255, 255, 0.07);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 14px;
    padding: 3px 10px;
    color: #e2e8f0;
    font-weight: 500;
}

.desk-mirror-pill {
    background-color: rgba(56, 189, 248, 0.14);
    border: 1px solid rgba(56, 189, 248, 0.35);
    border-radius: 14px;
    padding: 3px 12px;
    color: #38bdf8;
    font-weight: 600;
}

.desk-mirror-pill:hover {
    background-color: rgba(56, 189, 248, 0.25);
    color: #ffffff;
}

.desk-mirror-pill-active {
    background-color: rgba(34, 197, 94, 0.22);
    border: 1px solid rgba(34, 197, 94, 0.50);
    border-radius: 14px;
    padding: 3px 12px;
    color: #4ade80;
    font-weight: 600;
}

.desk-mirror-pill-active:hover {
    background-color: rgba(34, 197, 94, 0.35);
}

/* App Drawer Area */
.desk-scroll-area {
    background: transparent;
}

.desk-apps-flow {
    padding: 28px 48px;
}

/* App Tiles */
.desk-tile-btn {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 18px;
    padding: 10px 8px;
    min-width: 96px;
    transition: all 180ms ease-out;
}

.desk-tile-btn:hover {
    background-color: rgba(255, 255, 255, 0.10);
    border-color: rgba(255, 255, 255, 0.18);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
}

.desk-squircle {
    border-radius: 18px;
    border: 1px solid rgba(255, 255, 255, 0.24);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.40);
}

.desk-monogram {
    color: #ffffff;
    font-weight: 800;
    font-size: 20px;
    text-shadow: 0 2px 6px rgba(0, 0, 0, 0.5);
}

.desk-tile-label {
    color: #f1f5f9;
    font-weight: 500;
    font-size: 13px;
    text-shadow: 0 1px 4px rgba(0, 0, 0, 0.85);
    margin-top: 4px;
}

/* Modern Gradient Palettes */
.grad-0 { background-image: linear-gradient(to bottom right, #3b82f6, #06b6d4); }
.grad-1 { background-image: linear-gradient(to bottom right, #8b5cf6, #ec4899); }
.grad-2 { background-image: linear-gradient(to bottom right, #10b981, #06b6d4); }
.grad-3 { background-image: linear-gradient(to bottom right, #f59e0b, #ef4444); }
.grad-4 { background-image: linear-gradient(to bottom right, #6366f1, #a855f7); }
.grad-5 { background-image: linear-gradient(to bottom right, #0ea5e9, #3b82f6); }
.grad-6 { background-image: linear-gradient(to bottom right, #f97316, #f43f5e); }
.grad-7 { background-image: linear-gradient(to bottom right, #14b8a6, #10b981); }
.grad-8 { background-image: linear-gradient(to bottom right, #a855f7, #6366f1); }
.grad-9 { background-image: linear-gradient(to bottom right, #e11d48, #fb7185); }
.grad-10 { background-image: linear-gradient(to bottom right, #0284c7, #38bdf8); }
.grad-11 { background-image: linear-gradient(to bottom right, #475569, #64748b); }

/* Floating Bottom Dock */
.desk-dock-container {
    padding-bottom: 16px;
}

.desk-dock {
    background-color: rgba(15, 23, 42, 0.82);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 24px;
    padding: 6px 14px;
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.55);
}

.desk-dock-btn {
    border-radius: 14px;
    min-width: 44px;
    min-height: 44px;
    padding: 6px;
    background: transparent;
    border: none;
    color: #e2e8f0;
}

.desk-dock-btn:hover {
    background-color: rgba(255, 255, 255, 0.14);
    color: #ffffff;
}

.desk-dock-btn:active {
    background-color: rgba(255, 255, 255, 0.24);
}

.desk-dock-active {
    background-color: rgba(34, 197, 94, 0.22);
    border: 1px solid rgba(34, 197, 94, 0.45);
    color: #4ade80;
}

.desk-dock-separator {
    background-color: rgba(255, 255, 255, 0.14);
    margin: 6px 6px;
    min-width: 1px;
}

/* Boot & Welcome Card */
.desk-card {
    background-color: rgba(15, 23, 42, 0.90);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 24px;
    padding: 36px 44px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, 0.65);
}

.desk-card-title {
    font-size: 22px;
    font-weight: 700;
    color: #ffffff;
}

.desk-primary-btn {
    background: linear-gradient(135deg, #0ea5e9, #3b82f6);
    color: #ffffff;
    font-weight: 600;
    border: none;
    border-radius: 14px;
    padding: 8px 24px;
}

.desk-primary-btn:hover {
    background: linear-gradient(135deg, #38bdf8, #60a5fa);
    box-shadow: 0 4px 16px rgba(56, 189, 248, 0.40);
}

/* Toast Pill */
.desk-toast-pill {
    background-color: rgba(15, 23, 42, 0.92);
    border: 1px solid rgba(56, 189, 248, 0.45);
    border-radius: 20px;
    padding: 8px 20px;
    color: #38bdf8;
    font-weight: 500;
    font-size: 13px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.60);
}
"""


@dataclass
class AppInfo:
    """An installed application on the connected device."""

    package: str
    label: str
    component: Optional[str] = None
    icon_name: Optional[str] = None
    color_index: int = 0
    monogram: str = "A"


class AppTile(Gtk.FlowBoxChild):
    """A clickable modern squircle app tile."""

    def __init__(self, app: AppInfo, on_launch: Callable[[AppInfo], None]) -> None:
        super().__init__()
        self.app = app

        btn = Gtk.Button()
        btn.add_css_class("desk-tile-btn")
        btn.add_css_class("flat")
        btn.set_tooltip_text(f"{app.label}\n{app.package}")
        btn.connect("clicked", lambda _b: on_launch(self.app))

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        content.set_margin_top(4)
        content.set_margin_bottom(4)
        content.set_margin_start(4)
        content.set_margin_end(4)
        content.set_halign(Gtk.Align.CENTER)

        # Squircle container (60x60)
        squircle = Gtk.Frame()
        squircle.set_size_request(60, 60)
        squircle.set_halign(Gtk.Align.CENTER)
        squircle.set_valign(Gtk.Align.CENTER)
        squircle.add_css_class("desk-squircle")
        squircle.add_css_class(f"grad-{app.color_index}")

        if app.icon_name:
            icon_img = Gtk.Image.new_from_icon_name(app.icon_name)
            icon_img.set_pixel_size(30)
            icon_img.set_halign(Gtk.Align.CENTER)
            icon_img.set_valign(Gtk.Align.CENTER)
            squircle.set_child(icon_img)
        else:
            mono = Gtk.Label(label=app.monogram)
            mono.add_css_class("desk-monogram")
            mono.set_halign(Gtk.Align.CENTER)
            mono.set_valign(Gtk.Align.CENTER)
            squircle.set_child(mono)

        content.append(squircle)

        name = Gtk.Label(label=app.label)
        name.add_css_class("desk-tile-label")
        name.set_max_width_chars(12)
        name.set_ellipsize(Pango.EllipsizeMode.END)
        name.set_halign(Gtk.Align.CENTER)
        content.append(name)

        btn.set_child(content)
        self.set_child(btn)


class DeviceRow(Gtk.ListBoxRow):
    """A single row in the device picker popover."""

    def __init__(self, device: Device) -> None:
        super().__init__()
        self.device = device
        label_text = f"{device.model or 'Android Device'} ({device.serial})"
        if device.state != "device":
            label_text += f" [{device.state}]"
        label = Gtk.Label(label=label_text, halign=Gtk.Align.START)
        label.set_margin_top(6)
        label.set_margin_bottom(6)
        label.set_margin_start(8)
        self.set_child(label)


@dataclass
class AppConfig:
    """Presentation assets."""

    brand_icons: dict[str, str] = field(default_factory=dict)

    @classmethod
    def load(cls) -> "AppConfig":
        cfg = cls()
        for fname in (
            "samsung",
            "xiaomi",
            "motorola",
            "oneplus",
            "oppo",
            "vivo",
            "realme",
            "nothing",
            "google",
            "android",
        ):
            path = os.path.join(ASSETS_DIR, f"{fname}.svg")
            if os.path.exists(path):
                cfg.brand_icons[fname] = path
        return cfg


class OpenAndroidDex(Gtk.Application):
    """Clean-room GTK4 desktop application with modern DeX styling."""

    def __init__(self, demo_mode: bool = False) -> None:
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.demo_mode = demo_mode
        self._demo_mirror_active: bool = False
        self.adb = AdbClient()
        self.scrcpy = ScrcpyClient()
        self.input = InputController(self.adb)
        self.volume = VolumeControl(self.adb)
        self.urls = UrlLauncher(self.adb)
        self.windows = WindowManager(self.adb)
        self.devices = DeviceManager(self.adb)
        self.boot = BootManager(self.adb, self.scrcpy)
        self.config = AppConfig.load()

        self._selected_device: Optional[Device] = None
        self._search_query: str = ""
        self._all_apps: List[AppInfo] = []

        # UI references.
        self._topbar_brand: Optional[Gtk.Label] = None
        self._device_pill_box: Optional[Gtk.Box] = None
        self._device_name_label: Optional[Gtk.Label] = None
        self._device_dot: Optional[Gtk.Label] = None
        self._device_brand_icon: Optional[Gtk.Picture] = None

        self._omnibar: Optional[Gtk.SearchEntry] = None
        self._mirror_topbar_btn: Optional[Gtk.Button] = None
        self._clock_label: Optional[Gtk.Label] = None
        self._battery_label: Optional[Gtk.Label] = None

        self._boot_card: Optional[Gtk.Box] = None
        self._boot_title: Optional[Gtk.Label] = None
        self._boot_label: Optional[Gtk.Label] = None
        self._boot_progress: Optional[Gtk.ProgressBar] = None
        self._boot_btn: Optional[Gtk.Button] = None

        self._apps_scroll: Optional[Gtk.ScrolledWindow] = None
        self._apps_flowbox: Optional[Gtk.FlowBox] = None
        self._no_apps_label: Optional[Gtk.Label] = None

        self._dock_buttons: dict[str, Gtk.Button] = {}
        self._mirror_dock_btn: Optional[Gtk.Button] = None

        self._device_rows: Optional[Gtk.ListBox] = None
        self._device_popover: Optional[Gtk.Popover] = None

        self._toast_revealer: Optional[Gtk.Revealer] = None
        self._toast_label: Optional[Gtk.Label] = None
        self._toast_timer: Optional[int] = None

        self._clock_timer: Optional[int] = None
        self._status_timer: Optional[int] = None
        self._icon_theme: Optional[Gtk.IconTheme] = None

    def do_activate(self) -> None:
        win = self.props.active_window
        if not win:
            win = self._build_window()
        if win and hasattr(win, "get_display"):
            display = win.get_display()
            if display:
                self._icon_theme = Gtk.IconTheme.get_for_display(display)
        win.present()
        self._refresh_devices()

        if self._clock_timer is None:
            self._clock_timer = GLib.timeout_add(1000, self._update_clock)
        if self._status_timer is None:
            self._status_timer = GLib.timeout_add(2000, self._periodic_status_check)

        # Automatic boot check on startup: if demo mode, load demo; otherwise auto-boot if device present
        if self.demo_mode:
            GLib.timeout_add(150, self._enter_demo_mode)
        else:
            GLib.timeout_add(300, self._auto_boot_if_available)

    # ------------------------------------------------------------------
    # UI Construction
    # ------------------------------------------------------------------

    def _build_window(self) -> Gtk.ApplicationWindow:
        window = Gtk.ApplicationWindow(application=self)
        window.set_title(APP_NAME)
        window.set_default_size(1360, 780)
        self._apply_css()

        overlay = Gtk.Overlay()
        overlay.set_hexpand(True)
        overlay.set_vexpand(True)
        window.set_child(overlay)

        # Wallpaper layer.
        wallpaper = Gtk.Picture.new_for_filename(
            os.path.join(ASSETS_DIR, "wallpaper_1.svg")
        )
        wallpaper.set_hexpand(True)
        wallpaper.set_vexpand(True)
        wallpaper.set_content_fit(Gtk.ContentFit.COVER)
        overlay.set_child(wallpaper)

        # Shell vertical container.
        shell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        shell.set_hexpand(True)
        shell.set_vexpand(True)
        overlay.add_overlay(shell)

        # 1. Top status bar.
        shell.append(self._build_topbar())

        # 2. Main Desktop Work Area (Boot Card OR Desktop Apps).
        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        center.set_hexpand(True)
        center.set_vexpand(True)
        center.set_valign(Gtk.Align.FILL)
        shell.append(center)

        # Centered boot card.
        self._boot_card = self._build_boot_card()
        center.append(self._boot_card)

        # Scrolled window for desktop apps.
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.set_min_content_height(400)
        scroll.add_css_class("desk-scroll-area")

        self._apps_flowbox = self._build_apps_flowbox()
        scroll.set_child(self._apps_flowbox)
        self._apps_scroll = scroll
        center.append(scroll)
        scroll.set_visible(False)  # Hidden initially until boot completes

        # 3. Bottom floating dock.
        shell.append(self._build_dock())

        # 4. Floating Toast Notification (Overlay top-center).
        self._toast_revealer, self._toast_label = self._build_toast()
        overlay.add_overlay(self._toast_revealer)

        self._setup_shortcuts(window)
        return window

    def _apply_css(self) -> None:
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        display = Gdk.Display.get_default()
        if display:
            Gtk.StyleContext.add_provider_for_display(
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def _build_topbar(self) -> Gtk.Box:
        topbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        topbar.add_css_class("desk-topbar")

        # Left Section: Logo & Device Pill
        left_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        left_box.set_halign(Gtk.Align.START)

        brand = Gtk.Label(label="✦ DEX")
        brand.add_css_class("desk-brand-badge")
        left_box.append(brand)

        # Device Pill
        self._device_pill_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self._device_pill_box.add_css_class("desk-device-pill")

        self._device_dot = Gtk.Label(label="●")
        self._device_dot.add_css_class("desk-status-dot-offline")
        self._device_pill_box.append(self._device_dot)

        self._device_brand_icon = Gtk.Picture()
        self._device_brand_icon.set_size_request(16, 16)
        self._device_brand_icon.set_content_fit(Gtk.ContentFit.CONTAIN)
        self._device_brand_icon.set_visible(False)
        self._device_pill_box.append(self._device_brand_icon)

        self._device_name_label = Gtk.Label(label="No device connected")
        self._device_pill_box.append(self._device_name_label)
        left_box.append(self._device_pill_box)
        topbar.append(left_box)

        # Center Section: Omnibar (Search & URL Launcher)
        center_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        center_box.set_hexpand(True)
        center_box.set_halign(Gtk.Align.CENTER)

        self._omnibar = Gtk.SearchEntry()
        self._omnibar.set_placeholder_text("Search apps or enter URL to browse…")
        self._omnibar.add_css_class("desk-omnibar")
        self._omnibar.set_size_request(400, 36)
        self._omnibar.connect("search-changed", self._on_search_changed)
        self._omnibar.connect("activate", self._on_omnibar_activated)
        center_box.append(self._omnibar)
        topbar.append(center_box)

        # Right Section: System Tray
        right_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        right_box.set_halign(Gtk.Align.END)

        # Screen Mirror Pill
        self._mirror_topbar_btn = Gtk.Button(label="🪟 Mirror")
        self._mirror_topbar_btn.add_css_class("desk-mirror-pill")
        self._mirror_topbar_btn.set_sensitive(False)
        self._mirror_topbar_btn.set_tooltip_text("Toggle scrcpy screen mirroring")
        self._mirror_topbar_btn.connect("clicked", self._on_mirror_toggle)
        right_box.append(self._mirror_topbar_btn)

        # Battery Pill
        battery_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        battery_box.add_css_class("desk-chip")
        self._battery_label = Gtk.Label(label="🔋 —")
        battery_box.append(self._battery_label)
        right_box.append(battery_box)

        # Volume Controls
        vol_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        vol_box.add_css_class("desk-chip")
        vol_down = Gtk.Button.new_from_icon_name("audio-volume-low-symbolic")
        vol_down.add_css_class("flat")
        vol_down.set_tooltip_text("Volume Down")
        vol_down.connect("clicked", lambda _: self._volume_down())
        vol_box.append(vol_down)

        vol_up = Gtk.Button.new_from_icon_name("audio-volume-high-symbolic")
        vol_up.add_css_class("flat")
        vol_up.set_tooltip_text("Volume Up")
        vol_up.connect("clicked", lambda _: self._volume_up())
        vol_box.append(vol_up)
        right_box.append(vol_box)

        # Devices Popover Button
        right_box.append(self._build_devices_menubutton())

        # Clock & Date
        clock_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        clock_box.add_css_class("desk-chip")
        self._clock_label = Gtk.Label(
            label=datetime.datetime.now().strftime("%H:%M")
        )
        clock_box.append(self._clock_label)
        right_box.append(clock_box)

        topbar.append(right_box)
        return topbar

    def _build_devices_menubutton(self) -> Gtk.MenuButton:
        self._device_rows = Gtk.ListBox()
        self._device_rows.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._device_rows.connect("row-selected", self._on_device_row_selected)

        popover_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        popover_box.set_margin_top(10)
        popover_box.set_margin_bottom(10)
        popover_box.set_margin_start(10)
        popover_box.set_margin_end(10)

        header = Gtk.Label(label="Connected Android Devices", halign=Gtk.Align.START)
        header.add_css_class("heading")
        popover_box.append(header)

        popover_box.append(self._device_rows)

        refresh = Gtk.Button(label="Scan for Devices")
        refresh.add_css_class("desk-primary-btn")
        refresh.connect("clicked", lambda _: self._refresh_devices())
        popover_box.append(refresh)

        self._device_popover = Gtk.Popover()
        self._device_popover.set_child(popover_box)

        menu_btn = Gtk.MenuButton()
        menu_btn.set_label("Devices ▾")
        menu_btn.add_css_class("desk-chip")
        menu_btn.set_popover(self._device_popover)
        return menu_btn

    def _build_boot_card(self) -> Gtk.Box:
        wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        wrapper.set_valign(Gtk.Align.CENTER)
        wrapper.set_halign(Gtk.Align.CENTER)
        wrapper.set_hexpand(True)
        wrapper.set_vexpand(True)

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        card.add_css_class("desk-card")
        card.set_size_request(520, -1)

        # Hero Icon
        hero_icon = Gtk.Image.new_from_icon_name("video-display-symbolic")
        hero_icon.set_pixel_size(48)
        hero_icon.add_css_class("desk-brand-badge")
        card.append(hero_icon)

        self._boot_title = Gtk.Label(label="Connect to Android DeX")
        self._boot_title.add_css_class("desk-card-title")
        card.append(self._boot_title)

        self._boot_label = Gtk.Label(
            label="Plug your Android phone in via USB with debugging enabled.",
            wrap=True,
            halign=Gtk.Align.CENTER,
        )
        self._boot_label.set_max_width_chars(44)
        card.append(self._boot_label)

        self._boot_progress = Gtk.ProgressBar()
        self._boot_progress.set_fraction(0.0)
        self._boot_progress.set_margin_top(6)
        self._boot_progress.set_margin_bottom(6)
        card.append(self._boot_progress)

        self._boot_btn = Gtk.Button(label="Connect & Start DeX")
        self._boot_btn.add_css_class("desk-primary-btn")
        self._boot_btn.set_halign(Gtk.Align.CENTER)
        self._boot_btn.connect("clicked", self._on_boot)
        card.append(self._boot_btn)

        demo_btn = Gtk.Button(label="🧪 Explore Demo Mode (No Phone)")
        demo_btn.add_css_class("flat")
        demo_btn.add_css_class("desk-mirror-pill")
        demo_btn.set_halign(Gtk.Align.CENTER)
        demo_btn.set_margin_top(8)
        demo_btn.connect("clicked", lambda _: self._enter_demo_mode())
        card.append(demo_btn)

        wrapper.append(card)
        return wrapper

    def _build_apps_flowbox(self) -> Gtk.FlowBox:
        flow = Gtk.FlowBox()
        flow.set_valign(Gtk.Align.START)
        flow.set_orientation(Gtk.Orientation.HORIZONTAL)
        flow.set_min_children_per_line(4)
        flow.set_max_children_per_line(16)
        flow.set_column_spacing(14)
        flow.set_row_spacing(18)
        flow.add_css_class("desk-apps-flow")
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_activate_on_single_click(True)
        flow.set_filter_func(self._filter_app_tile)
        flow.connect("child-activated", self._on_app_activated)
        return flow

    def _build_dock(self) -> Gtk.Box:
        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        outer.set_halign(Gtk.Align.CENTER)
        outer.set_valign(Gtk.Align.END)
        outer.add_css_class("desk-dock-container")

        dock = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        dock.add_css_class("desk-dock")

        # 1. Apps / Drawer Toggle
        apps_btn = Gtk.Button.new_from_icon_name("view-app-grid-symbolic")
        apps_btn.add_css_class("desk-dock-btn")
        apps_btn.set_tooltip_text("All Apps (Focus Search / Reset Filter)")
        apps_btn.connect("clicked", self._on_apps_dock_clicked)
        dock.append(apps_btn)
        self._dock_buttons["apps"] = apps_btn

        # 2. Screen Mirror (scrcpy)
        self._mirror_dock_btn = Gtk.Button.new_from_icon_name("video-display-symbolic")
        self._mirror_dock_btn.add_css_class("desk-dock-btn")
        self._mirror_dock_btn.set_tooltip_text("Mirror Screen (scrcpy)")
        self._mirror_dock_btn.connect("clicked", self._on_mirror_toggle)
        dock.append(self._mirror_dock_btn)
        self._dock_buttons["mirror"] = self._mirror_dock_btn

        # 3. Default Browser
        browser_btn = Gtk.Button.new_from_icon_name("web-browser-symbolic")
        browser_btn.add_css_class("desk-dock-btn")
        browser_btn.set_tooltip_text("Open Phone Browser")
        browser_btn.connect("clicked", lambda _: self._open_default_browser())
        dock.append(browser_btn)
        self._dock_buttons["browser"] = browser_btn

        # 4. File Manager
        files_btn = Gtk.Button.new_from_icon_name("system-file-manager-symbolic")
        files_btn.add_css_class("desk-dock-btn")
        files_btn.set_tooltip_text("Open Files")
        files_btn.connect("clicked", lambda _: self._open_files())
        dock.append(files_btn)
        self._dock_buttons["files"] = files_btn

        # Divider 1
        sep1 = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        sep1.add_css_class("desk-dock-separator")
        dock.append(sep1)

        # 5. Back Key
        back_btn = Gtk.Button.new_from_icon_name("go-previous-symbolic")
        back_btn.add_css_class("desk-dock-btn")
        back_btn.set_tooltip_text("Back")
        back_btn.connect("clicked", lambda _: self._send_key(4))
        dock.append(back_btn)
        self._dock_buttons["back"] = back_btn

        # 6. Home Key
        home_btn = Gtk.Button.new_from_icon_name("go-home-symbolic")
        home_btn.add_css_class("desk-dock-btn")
        home_btn.set_tooltip_text("Home")
        home_btn.connect("clicked", lambda _: self._send_key(3))
        dock.append(home_btn)
        self._dock_buttons["home"] = home_btn

        # 7. Recent Apps Key
        recents_btn = Gtk.Button.new_from_icon_name("view-grid-symbolic")
        recents_btn.add_css_class("desk-dock-btn")
        recents_btn.set_tooltip_text("Recent Apps")
        recents_btn.connect("clicked", lambda _: self._recent_apps())
        dock.append(recents_btn)
        self._dock_buttons["recents"] = recents_btn

        # Divider 2
        sep2 = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        sep2.add_css_class("desk-dock-separator")
        dock.append(sep2)

        # 8. Screenshot Action
        snap_btn = Gtk.Button.new_from_icon_name("camera-photo-symbolic")
        snap_btn.add_css_class("desk-dock-btn")
        snap_btn.set_tooltip_text("Take Screenshot")
        snap_btn.connect("clicked", lambda _: self._take_screenshot())
        dock.append(snap_btn)
        self._dock_buttons["screenshot"] = snap_btn

        # 9. Notifications Drawer
        notif_btn = Gtk.Button.new_from_icon_name("mail-unread-symbolic")
        notif_btn.add_css_class("desk-dock-btn")
        notif_btn.set_tooltip_text("Notification Shade")
        notif_btn.connect("clicked", lambda _: self._toggle_notifications())
        dock.append(notif_btn)
        self._dock_buttons["notifications"] = notif_btn

        # 10. Lock / Power
        lock_btn = Gtk.Button.new_from_icon_name("system-lock-screen-symbolic")
        lock_btn.add_css_class("desk-dock-btn")
        lock_btn.set_tooltip_text("Lock / Wake Phone")
        lock_btn.connect("clicked", lambda _: self._lock())
        dock.append(lock_btn)
        self._dock_buttons["lock"] = lock_btn

        outer.append(dock)
        self._set_dock_enabled()
        return outer

    def _build_toast(self) -> Tuple[Gtk.Revealer, Gtk.Label]:
        revealer = Gtk.Revealer()
        revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        revealer.set_transition_duration(250)
        revealer.set_halign(Gtk.Align.CENTER)
        revealer.set_valign(Gtk.Align.START)
        revealer.set_margin_top(64)

        label = Gtk.Label(label="")
        label.add_css_class("desk-toast-pill")
        revealer.set_child(label)
        return revealer, label

    def _show_toast(self, message: str) -> None:
        if not self._toast_revealer or not self._toast_label:
            return
        self._toast_label.set_text(message)
        self._toast_revealer.set_reveal_child(True)
        if self._toast_timer is not None:
            GLib.source_remove(self._toast_timer)
        self._toast_timer = GLib.timeout_add(3200, self._hide_toast)

    def _hide_toast(self) -> bool:
        if self._toast_revealer:
            self._toast_revealer.set_reveal_child(False)
        self._toast_timer = None
        return GLib.SOURCE_REMOVE

    # ------------------------------------------------------------------
    # Omnibar (Search & URL Handling)
    # ------------------------------------------------------------------

    def _on_search_changed(self, entry: Gtk.SearchEntry) -> None:
        self._search_query = entry.get_text().strip().lower()
        if self._apps_flowbox:
            self._apps_flowbox.invalidate_filter()

    def _filter_app_tile(self, child: Gtk.FlowBoxChild) -> bool:
        if not self._search_query:
            return True
        if not isinstance(child, AppTile):
            return True
        q = self._search_query
        return q in child.app.label.lower() or q in child.app.package.lower()

    def _on_omnibar_activated(self, entry: Gtk.SearchEntry) -> None:
        text = entry.get_text().strip()
        if not text or not self._selected_device:
            return

        # Check if the query is a URL or domain
        if text.startswith(("http://", "https://")) or ("." in text and " " not in text):
            url = text if text.startswith(("http://", "https://")) else f"https://{text}"
            self._ensure_mirror(title="Browser — Open Android Dex")
            self._bg(self.urls.open, self._selected_device.serial, url)
            self._show_toast(f"🌐 Opening {url} on laptop display…")
            entry.set_text("")
            return

        # Otherwise, launch the first visible matching app
        if self._apps_flowbox:
            child = self._apps_flowbox.get_first_child()
            while child is not None:
                if isinstance(child, AppTile) and self._filter_app_tile(child):
                    self._launch_tile(child.app)
                    entry.set_text("")
                    return
                child = child.get_next_sibling()

    def _on_apps_dock_clicked(self, _button: Gtk.Button) -> None:
        if self._omnibar:
            self._omnibar.set_text("")
            self._omnibar.grab_focus()
        if self._apps_scroll:
            adj = self._apps_scroll.get_vadjustment()
            if adj:
                adj.set_value(0)

    # ------------------------------------------------------------------
    # App Metadata & Monogram Resolver
    # ------------------------------------------------------------------

    def _resolve_app_meta(self, package: str) -> Tuple[str, Optional[str], int]:
        if package in WELL_KNOWN_APPS:
            return WELL_KNOWN_APPS[package]

        # Clean fallback label
        clean = package
        for prefix in (
            "com.google.android.apps.",
            "com.google.android.",
            "com.android.",
            "org.",
            "com.",
            "net.",
            "io.",
            "in.",
            "ai.",
            "ch.",
        ):
            if clean.startswith(prefix):
                clean = clean[len(prefix):]
                break
        parts = re.split(r"[._\-]", clean)
        words = [
            p.capitalize()
            for p in parts
            if p and p.lower() not in ("android", "app", "mobile", "editor", "frontpage")
        ]
        label = " ".join(words[:2]) if words else package.rsplit(".", 1)[-1].title()

        # Deterministic color index based on package hash
        color_idx = abs(hash(package)) % 12
        return label, None, color_idx

    def _make_monogram(self, label: str) -> str:
        words = label.split()
        if len(words) >= 2:
            return (words[0][:1] + words[1][:1]).upper()
        return (label[:2] if len(label) >= 2 else (label[:1] or "A")).upper()

    # ------------------------------------------------------------------
    # Boot Sequence & Device Discovery
    # ------------------------------------------------------------------

    def _enter_demo_mode(self) -> bool:
        """Simulate a fully functioning connected Android environment for contributors."""
        self.demo_mode = True
        self._selected_device = Device(
            serial="demo-pixel8",
            state="device",
            model="Pixel 8 Pro (Demo Mode)",
        )
        self.devices.selected = self._selected_device

        # Transition UI to Desktop workspace
        if self._boot_card:
            self._boot_card.set_visible(False)
        if self._apps_scroll:
            self._apps_scroll.set_visible(True)

        self._update_device_ui({"brand": "Google", "model": "Pixel 8 Pro (Demo)"})
        self._set_dock_enabled()
        self._show_toast("🧪 Demo Mode active — exploring DeX UI without a phone")

        demo_apps = [
            AppInfo(package="com.android.chrome", label="Chrome", icon_name="google-chrome", color_index=0, monogram="C"),
            AppInfo(package="com.android.messaging", label="Messages", icon_name="mail-unread-symbolic", color_index=2, monogram="M"),
            AppInfo(package="com.android.settings", label="Settings", icon_name="preferences-system-symbolic", color_index=11, monogram="S"),
            AppInfo(package="com.google.android.calculator", label="Calculator", icon_name="accessories-calculator-symbolic", color_index=3, monogram="C"),
            AppInfo(package="com.android.vending", label="Play Store", icon_name="software-properties-symbolic", color_index=4, monogram="P"),
            AppInfo(package="com.google.android.apps.photos", label="Photos", icon_name="image-x-generic", color_index=1, monogram="P"),
            AppInfo(package="com.google.android.youtube", label="YouTube", icon_name="video-x-generic", color_index=0, monogram="Y"),
            AppInfo(package="com.spotify.music", label="Spotify", icon_name="audio-x-generic", color_index=2, monogram="S"),
            AppInfo(package="com.google.android.apps.maps", label="Maps", icon_name="mark-location-symbolic", color_index=1, monogram="M"),
            AppInfo(package="com.google.android.calendar", label="Calendar", icon_name="x-office-calendar-symbolic", color_index=3, monogram="C"),
            AppInfo(package="com.android.documentsui", label="Files", icon_name="folder-symbolic", color_index=8, monogram="F"),
            AppInfo(package="com.google.android.deskclock", label="Clock", icon_name="alarm-symbolic", color_index=7, monogram="C"),
            AppInfo(package="com.android.camera2", label="Camera", icon_name="camera-photo-symbolic", color_index=5, monogram="C"),
            AppInfo(package="com.termux", label="Terminal", icon_name="utilities-terminal-symbolic", color_index=9, monogram="T"),
        ]
        self._all_apps = demo_apps
        if self._apps_flowbox:
            self._populate_flowbox(demo_apps)
        if self._battery_label:
            self._battery_label.set_text("⚡ 94%")
        return GLib.SOURCE_REMOVE

    def _auto_boot_if_available(self) -> bool:
        if self.boot.running or self._selected_device:
            return GLib.SOURCE_REMOVE
        dev, needs_selection = self.devices.auto_detect()
        if dev and not needs_selection:
            self._selected_device = dev
            self._on_boot(None)
        return GLib.SOURCE_REMOVE

    def _on_boot(self, _button: Optional[Gtk.Button]) -> None:
        if self.boot.running:
            return
        if self._boot_btn:
            self._boot_btn.set_sensitive(False)
        if self._boot_progress:
            self._boot_progress.set_fraction(0.0)
        serial = self._selected_device.serial if self._selected_device else None
        self.boot.start(serial, self._on_boot_event_thread)

    def _on_boot_event_thread(self, event: BootEvent) -> None:
        GLib.idle_add(self._on_boot_event, event)

    def _on_boot_event(self, event: BootEvent) -> bool:
        if self._boot_label:
            self._boot_label.set_text(event.message)
        if self._boot_progress:
            self._boot_progress.set_fraction(min(1.0, max(0.0, event.progress)))

        if event.needs_device_selection:
            self._refresh_devices()

        if event.progress >= 1.0 and event.device is not None:
            self._selected_device = event.device
            self.devices.selected = event.device

            # Transition UI to Desktop workspace
            if self._boot_card:
                self._boot_card.set_visible(False)
            if self._apps_scroll:
                self._apps_scroll.set_visible(True)

            self._update_device_ui(event.device_info)
            self._set_dock_enabled()
            self._show_toast(f"⚡ Connected to {self._selected_device.model or 'Android Device'}")
            self._bg(self._load_apps)
            self._bg(self._update_battery)

        if not self.boot.running and self._boot_btn:
            self._boot_btn.set_sensitive(True)
        return GLib.SOURCE_REMOVE

    def _update_device_ui(self, info: dict) -> None:
        if not self._selected_device:
            if self._device_name_label:
                self._device_name_label.set_text("No device connected")
            if self._device_dot:
                self._device_dot.remove_css_class("desk-status-dot-online")
                self._device_dot.add_css_class("desk-status-dot-offline")
            if self._device_brand_icon:
                self._device_brand_icon.set_visible(False)
            return

        brand = info.get("brand", "").lower()
        model = info.get("model") or self._selected_device.model or "Android Device"
        name = f"{info.get('brand', '').capitalize()} {model}".strip()

        if self._device_name_label:
            self._device_name_label.set_text(name)
        if self._device_dot:
            self._device_dot.remove_css_class("desk-status-dot-offline")
            self._device_dot.add_css_class("desk-status-dot-online")

        # Show brand icon if available
        if self._device_brand_icon and brand in self.config.brand_icons:
            self._device_brand_icon.set_filename(self.config.brand_icons[brand])
            self._device_brand_icon.set_visible(True)

    # ------------------------------------------------------------------
    # Device Picker
    # ------------------------------------------------------------------

    def _refresh_devices(self) -> None:
        self._bg(self._load_device_rows)

    def _load_device_rows(self) -> None:
        rows = self.adb.list_devices()

        def apply() -> None:
            if not self._device_rows:
                return
            child = self._device_rows.get_first_child()
            while child is not None:
                nxt = child.get_next_sibling()
                self._device_rows.remove(child)
                child = nxt
            for dev in rows:
                self._device_rows.append(DeviceRow(dev))

        GLib.idle_add(apply)

    def _on_device_row_selected(self, box: Gtk.ListBox, row: Optional[DeviceRow]) -> None:
        if row is None:
            return
        if row.device.state == "device":
            self._selected_device = row.device
            self.devices.selected = row.device
            self._on_boot(None)
        if self._device_popover:
            self._device_popover.popdown()

    def _set_dock_enabled(self) -> None:
        enabled = self._selected_device is not None
        for btn in self._dock_buttons.values():
            btn.set_sensitive(enabled)
        if self._mirror_topbar_btn:
            self._mirror_topbar_btn.set_sensitive(enabled and self.scrcpy.is_available())

    # ------------------------------------------------------------------
    # Periodic Status & Timers
    # ------------------------------------------------------------------

    def _update_clock(self) -> bool:
        if self._clock_label:
            now = datetime.datetime.now()
            self._clock_label.set_text(now.strftime("%H:%M  •  %b %-d"))
        return GLib.SOURCE_CONTINUE

    def _periodic_status_check(self) -> bool:
        if self.demo_mode:
            return GLib.SOURCE_CONTINUE
        # Check scrcpy running state and update toggle buttons
        is_mirroring = self.scrcpy.is_running()
        if self._mirror_topbar_btn:
            if is_mirroring:
                self._mirror_topbar_btn.set_label("🟢 Mirroring")
                self._mirror_topbar_btn.remove_css_class("desk-mirror-pill")
                self._mirror_topbar_btn.add_css_class("desk-mirror-pill-active")
            else:
                self._mirror_topbar_btn.set_label("🪟 Mirror")
                self._mirror_topbar_btn.remove_css_class("desk-mirror-pill-active")
                self._mirror_topbar_btn.add_css_class("desk-mirror-pill")

        if self._mirror_dock_btn:
            if is_mirroring:
                self._mirror_dock_btn.add_css_class("desk-dock-active")
            else:
                self._mirror_dock_btn.remove_css_class("desk-dock-active")

        # Periodically refresh battery if device connected
        if self._selected_device:
            self._bg(self._update_battery)
        return GLib.SOURCE_CONTINUE

    def _update_battery(self) -> None:
        if not self._selected_device:
            return
        serial = self._selected_device.serial
        result = self.adb.shell(serial, "dumpsys battery | grep -E 'level:|status:'")
        level_match = re.search(r"level:\s*(\d+)", result.stdout)
        status_match = re.search(r"status:\s*(\d+)", result.stdout)

        def apply() -> bool:
            if not self._battery_label:
                return GLib.SOURCE_REMOVE
            if level_match:
                pct = level_match.group(1)
                is_charging = status_match and status_match.group(1) == "2"
                symbol = "⚡ " if is_charging else "🔋 "
                self._battery_label.set_text(f"{symbol}{pct}%")
            else:
                self._battery_label.set_text("🔋 —")
            return GLib.SOURCE_REMOVE

        GLib.idle_add(apply)

    # ------------------------------------------------------------------
    # App Drawer Loading
    # ------------------------------------------------------------------

    def _load_apps(self) -> None:
        if not self._selected_device:
            return
        serial = self._selected_device.serial

        # Query explicit launcher activities
        activities = self.adb.get_launcher_activities(serial)

        # Query installed 3rd-party packages
        result = self.adb.shell(serial, "pm list packages -3")
        user_pkgs = set(
            line.removeprefix("package:").strip()
            for line in result.stdout.splitlines()
            if line.startswith("package:")
        )

        seen_packages = set()
        apps: List[AppInfo] = []
        theme = getattr(self, "_icon_theme", None)
        if not theme:
            display = Gdk.Display.get_default()
            theme = Gtk.IconTheme.get_for_display(display) if display else None

        # First add launchable activities
        for pkg, act in activities:
            if pkg in seen_packages:
                continue
            seen_packages.add(pkg)
            label, sys_icon, color_idx = self._resolve_app_meta(pkg)
            valid_icon = sys_icon if (sys_icon and theme and theme.has_icon(sys_icon)) else None
            monogram = self._make_monogram(label)
            apps.append(
                AppInfo(
                    package=pkg,
                    label=label,
                    component=f"{pkg}/{act}",
                    icon_name=valid_icon,
                    color_index=color_idx,
                    monogram=monogram,
                )
            )

        # Add remaining user packages
        for pkg in sorted(user_pkgs):
            if pkg in seen_packages:
                continue
            seen_packages.add(pkg)
            label, sys_icon, color_idx = self._resolve_app_meta(pkg)
            valid_icon = sys_icon if (sys_icon and theme.has_icon(sys_icon)) else None
            monogram = self._make_monogram(label)
            apps.append(
                AppInfo(
                    package=pkg,
                    label=label,
                    component=None,
                    icon_name=valid_icon,
                    color_index=color_idx,
                    monogram=monogram,
                )
            )

        apps.sort(key=lambda a: a.label.lower())
        self._all_apps = apps

        def apply() -> bool:
            if not self._apps_flowbox:
                return GLib.SOURCE_REMOVE
            child = self._apps_flowbox.get_first_child()
            while child is not None:
                nxt = child.get_next_sibling()
                self._apps_flowbox.remove(child)
                child = nxt
            for app in self._all_apps:
                self._apps_flowbox.append(AppTile(app, self._launch_tile))
            if self._omnibar:
                self._omnibar.set_placeholder_text(f"Search {len(self._all_apps)} apps or enter URL…")
            return GLib.SOURCE_REMOVE

        GLib.idle_add(apply)

    def _on_app_activated(self, _flow: Gtk.FlowBox, tile: AppTile) -> None:
        self._launch_tile(tile.app)

    def _ensure_mirror(self, start_app: Optional[str] = None, title: Optional[str] = None) -> None:
        """Ensure scrcpy is active on the laptop screen so apps appear on the laptop display."""
        if not self._selected_device:
            return
        if not self.scrcpy.is_running():
            serial = self._selected_device.serial
            win_title = title or f"{self._selected_device.model or 'Android'} — Open Android Dex"
            try:
                self.scrcpy.start(
                    serial=serial,
                    start_app=start_app,
                    window_title=win_title,
                    always_on_top=True,
                )
            except Exception as exc:
                self._show_toast(f"Display launch error: {exc}")

    def _launch_tile(self, app: AppInfo) -> None:
        if self.demo_mode:
            self._show_toast(f"🚀 [Demo Mode] Opened {app.label}")
            return
        if not self._selected_device:
            return
        serial = self._selected_device.serial

        # Ensure scrcpy is running on the laptop display
        if not self.scrcpy.is_running():
            self._ensure_mirror(start_app=app.package, title=f"{app.label} — Open Android Dex")
            self._show_toast(f"🪟 Opening {app.label} on laptop display…")
            return

        # If already mirroring, switch directly to the component
        if app.component:
            self._bg(self.adb.start_component, serial, app.component)
        else:
            self._bg(self._launch, serial, app.package)
        self._show_toast(f"🚀 Switching to {app.label} on laptop display…")

    def _launch(self, serial: str, pkg: str) -> None:
        self.adb.shell(serial, f"monkey -p {pkg} -c android.intent.category.LAUNCHER 1")

    # ------------------------------------------------------------------
    # Actions & Phone Controls
    # ------------------------------------------------------------------

    def _on_mirror_toggle(self, _button: Gtk.Button) -> None:
        if self.demo_mode:
            self._demo_mirror_active = not self._demo_mirror_active
            if self._mirror_topbar_btn:
                if self._demo_mirror_active:
                    self._mirror_topbar_btn.set_label("🟢 Mirroring")
                    self._mirror_topbar_btn.remove_css_class("desk-mirror-pill")
                    self._mirror_topbar_btn.add_css_class("desk-mirror-pill-active")
                else:
                    self._mirror_topbar_btn.set_label("🪟 Mirror")
                    self._mirror_topbar_btn.remove_css_class("desk-mirror-pill-active")
                    self._mirror_topbar_btn.add_css_class("desk-mirror-pill")
            if self._mirror_dock_btn:
                if self._demo_mirror_active:
                    self._mirror_dock_btn.add_css_class("desk-dock-active")
                else:
                    self._mirror_dock_btn.remove_css_class("desk-dock-active")
            state_text = "active (simulated)" if self._demo_mirror_active else "stopped"
            self._show_toast(f"🖥️ [Demo Mode] Display mirror {state_text}")
            return
        if not self._selected_device:
            return
        if self.scrcpy.is_running():
            self.scrcpy.stop()
            self._show_toast("Laptop display mirror stopped")
        else:
            try:
                self.scrcpy.start(
                    serial=self._selected_device.serial,
                    window_title=f"{self._selected_device.model or 'Android'} — Open Android Dex",
                    always_on_top=True,
                )
                self._show_toast(f"🪟 Mirroring {self._selected_device.model or 'Phone'} on laptop display")
            except RuntimeError as exc:
                self._show_toast(f"Mirror failed: {exc}")

    def _open_default_browser(self) -> None:
        if not self._selected_device:
            return
        self._ensure_mirror(title="Browser — Open Android Dex")
        self._bg(self.urls.open, self._selected_device.serial, "https://www.google.com")
        self._show_toast("🌐 Opening Browser on laptop display…")

    def _open_files(self) -> None:
        if not self._selected_device:
            return
        self._ensure_mirror(title="Files — Open Android Dex")
        self._bg(
            self.adb.shell,
            self._selected_device.serial,
            "am start -a android.intent.action.VIEW -t '*/*'",
        )
        self._show_toast("📁 Opening Files on laptop display…")

    def _take_screenshot(self) -> None:
        if not self._selected_device:
            return
        serial = self._selected_device.serial

        def task() -> None:
            data = self.adb.take_screenshot(serial)
            if not data:
                GLib.idle_add(self._show_toast, "❌ Screenshot capture failed")
                return
            save_dir = os.path.expanduser("~/Pictures/Screenshots")
            os.makedirs(save_dir, exist_ok=True)
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            dest = os.path.join(save_dir, f"Dex_{ts}.png")
            with open(dest, "wb") as f:
                f.write(data)
            GLib.idle_add(self._show_toast, f"📸 Screenshot saved to Pictures/Screenshots/Dex_{ts}.png")

        self._bg(task)

    def _toggle_notifications(self) -> None:
        if self.demo_mode:
            self._show_toast("🔔 [Demo Mode] Notifications shade toggled")
            return
        if self._selected_device:
            self._bg(self.windows.notifications, self._selected_device.serial)

    def _volume_up(self) -> None:
        if self.demo_mode:
            self._show_toast("🔊 [Demo Mode] Volume Up")
            return
        if self._selected_device:
            self.volume.up(self._selected_device.serial)
            self._show_toast("🔊 Volume Up")

    def _volume_down(self) -> None:
        if self.demo_mode:
            self._show_toast("🔉 [Demo Mode] Volume Down")
            return
        if self._selected_device:
            self.volume.down(self._selected_device.serial)
            self._show_toast("🔉 Volume Down")

    def _send_key(self, keycode: int) -> None:
        if self.demo_mode:
            key_names = {3: "Home", 4: "Back", 187: "Recent Apps", 26: "Power/Lock"}
            name = key_names.get(keycode, f"Keycode {keycode}")
            self._show_toast(f"📱 [Demo Mode] Action: {name}")
            return
        if self._selected_device:
            self.input.send_key(self._selected_device.serial, keycode)

    def _recent_apps(self) -> None:
        if self.demo_mode:
            self._show_toast("📱 [Demo Mode] Recent Apps overview")
            return
        if self._selected_device:
            self._ensure_mirror()
            self.windows.recent_apps(self._selected_device.serial)

    def _lock(self) -> None:
        if self.demo_mode:
            self._show_toast("🔒 [Demo Mode] Screen Lock toggled")
            return
        if self._selected_device:
            self.windows.lock(self._selected_device.serial)
            self._show_toast("🔒 Screen Lock toggled")

    # ------------------------------------------------------------------
    # Keyboard Shortcuts
    # ------------------------------------------------------------------

    def _setup_shortcuts(self, window: Gtk.ApplicationWindow) -> None:
        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key_pressed)
        window.add_controller(controller)

    def _on_key_pressed(
        self,
        controller: Gtk.EventControllerKey,
        keyval: int,
        keycode: int,
        state: Gdk.ModifierType,
    ) -> bool:
        ctrl = bool(state & Gdk.ModifierType.CONTROL_MASK)
        shift = bool(state & Gdk.ModifierType.SHIFT_MASK)

        # DPAD Navigation via Ctrl+Shift+Arrows
        if ctrl and shift and self._selected_device:
            dpad_map = {
                Gdk.KEY_Up: 19,
                Gdk.KEY_Down: 20,
                Gdk.KEY_Left: 21,
                Gdk.KEY_Right: 22,
            }
            if keyval in dpad_map:
                self.input.send_key(self._selected_device.serial, dpad_map[keyval])
                return True

        # Quick Search focus with Ctrl+F
        if ctrl and keyval in (Gdk.KEY_f, Gdk.KEY_F):
            if self._omnibar:
                self._omnibar.grab_focus()
                return True

        # Back navigation with Escape if not focused in search
        if keyval == Gdk.KEY_Escape:
            if self._omnibar and self._omnibar.has_focus():
                self._omnibar.set_text("")
                return True
            if self._selected_device:
                self._send_key(4)
                return True

        return False

    # ------------------------------------------------------------------
    # Background Worker Helper
    # ------------------------------------------------------------------

    def _bg(self, fn: Callable, *args) -> None:
        def runner() -> None:
            try:
                fn(*args)
            except Exception as exc:
                GLib.idle_add(self._show_toast, f"Error: {exc}")

        threading.Thread(target=runner, daemon=True).start()


def main() -> int:
    import sys
    demo = "--demo" in sys.argv or "--mock" in sys.argv
    app = OpenAndroidDex(demo_mode=demo)
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    raise SystemExit(main())
