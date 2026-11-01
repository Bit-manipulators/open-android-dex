"""Android Dex — Original GTK4 desktop application.

Reimplements the Android Dex functionality (ADB device control, scrcpy
screen mirroring, input injection, volume, URL launcher, window management)
using Python, GTK4, ADB, and scrcpy.

All code is original work written from scratch.
"""

from __future__ import annotations

import sys
from typing import Optional

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")

from gi.repository import Gtk, Gio, Gdk  # noqa: E402

from adb_client import AdbClient, Device
from scrcpy_client import ScrcpyClient
from input_controller import InputController
from volume_control import VolumeControl
from url_launcher import UrlLauncher
from window_manager import WindowManager


APP_ID = "com.example.androiddex"


class DeviceRow(Gtk.ListBoxRow):
    """A single row in the device list."""

    def __init__(self, device: Device) -> None:
        super().__init__()
        self.device = device
        label_text = f"{device.model or 'Android Device'} ({device.serial})"
        if device.state != "device":
            label_text += f" [{device.state}]"
        label = Gtk.Label(label=label_text, halign=Gtk.Align.START)
        label.set_hexpand(True)
        self.set_child(label)
        self.set_tooltip_text(device.serial)


class AndroidDex(Gtk.Application):
    """Main application class."""

    def __init__(self) -> None:
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.adb = AdbClient()
        self.scrcpy = ScrcpyClient()
        self.input = InputController(self.adb)
        self.volume = VolumeControl(self.adb)
        self.urls = UrlLauncher(self.adb)
        self.windows = WindowManager(self.adb)

        self._selected_device: Optional[Device] = None
        self._device_list: Optional[Gtk.ListBox] = None
        self._status_label: Optional[Gtk.Label] = None
        self._connect_btn: Optional[Gtk.Button] = None
        self._mirror_btn: Optional[Gtk.Button] = None
        self._url_entry: Optional[Gtk.Entry] = None

    def do_activate(self) -> None:
        win = self.props.active_window
        if not win:
            win = self._build_window()
        win.present()

    def _build_window(self) -> Gtk.ApplicationWindow:
        window = Gtk.ApplicationWindow(application=self)
        window.set_title("Android Dex")
        window.set_default_size(900, 600)

        # Top bar with title + refresh button
        top_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        top_bar.set_margin_top(6)
        top_bar.set_margin_bottom(6)
        top_bar.set_margin_start(6)
        top_bar.set_margin_end(6)

        title_label = Gtk.Label(label="Android Dex")
        title_label.set_hexpand(True)
        title_label.set_halign(Gtk.Align.START)
        title_label.add_css_class("title")

        refresh_btn = Gtk.Button(label="Refresh Devices")
        refresh_btn.connect("clicked", lambda _: self._refresh_devices())

        top_bar.append(title_label)
        top_bar.append(refresh_btn)

        # Main box
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(6)
        box.set_margin_end(6)
        window.set_child(box)
        box.append(top_bar)

        # Device list
        list_scroll = Gtk.ScrolledWindow()
        list_scroll.set_min_content_width(260)
        list_scroll.set_max_content_width(260)
        self._device_list = Gtk.ListBox()
        self._device_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._device_list.connect("row-selected", self._on_row_selected)
        list_scroll.set_child(self._device_list)
        box.append(list_scroll)

        # Control panel (right side)
        controls = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        controls.set_hexpand(True)
        box.append(controls)

        # Device info
        info_frame = Gtk.Frame(label="Device")
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        info_box.set_margin_top(6)
        info_box.set_margin_bottom(6)
        info_box.set_margin_start(6)
        info_box.set_margin_end(6)
        self._status_label = Gtk.Label(label="No device selected", halign=Gtk.Align.START)
        self._status_label.set_hexpand(True)
        info_box.append(self._status_label)
        info_frame.set_child(info_box)
        controls.append(info_frame)

        # Action buttons grid
        btn_grid = Gtk.Grid()
        btn_grid.set_column_spacing(8)
        btn_grid.set_row_spacing(6)
        btn_grid.set_margin_top(6)
        controls.append(btn_grid)

        self._connect_btn = Gtk.Button(label="Connect")
        self._connect_btn.set_sensitive(False)
        self._connect_btn.connect("clicked", self._on_connect)

        self._mirror_btn = Gtk.Button(label="Mirror Screen")
        self._mirror_btn.set_sensitive(False)
        self._mirror_btn.connect("clicked", self._on_mirror)

        stop_btn = Gtk.Button(label="Stop Mirror")
        stop_btn.set_sensitive(False)
        stop_btn.connect("clicked", lambda _: self.scrcpy.stop())

        home_btn = Gtk.Button(label="Home")
        home_btn.connect("clicked", lambda _: self._send_key(3))

        back_btn = Gtk.Button(label="Back")
        back_btn.connect("clicked", lambda _: self._send_key(4))

        menu_btn = Gtk.Button(label="Menu")
        menu_btn.connect("clicked", lambda _: self._send_key(82))

        vol_up_btn = Gtk.Button(label="Volume Up")
        vol_up_btn.connect("clicked", lambda _: self._volume_up())

        vol_down_btn = Gtk.Button(label="Volume Down")
        vol_down_btn.connect("clicked", lambda _: self._volume_down())

        recent_btn = Gtk.Button(label="Recent Apps")
        recent_btn.connect("clicked", lambda _: self._recent_apps())

        lock_btn = Gtk.Button(label="Lock")
        lock_btn.connect("clicked", lambda _: self._lock())

        btn_grid.attach(self._connect_btn, 0, 0, 1, 1)
        btn_grid.attach(self._mirror_btn, 1, 0, 1, 1)
        btn_grid.attach(stop_btn, 0, 1, 1, 1)
        btn_grid.attach(home_btn, 1, 1, 1, 1)
        btn_grid.attach(back_btn, 0, 2, 1, 1)
        btn_grid.attach(menu_btn, 1, 2, 1, 1)
        btn_grid.attach(vol_up_btn, 0, 3, 1, 1)
        btn_grid.attach(vol_down_btn, 1, 3, 1, 1)
        btn_grid.attach(recent_btn, 0, 4, 1, 1)
        btn_grid.attach(lock_btn, 1, 4, 1, 1)

        # URL launcher
        url_frame = Gtk.Frame(label="Open URL")
        url_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        url_box.set_margin_top(6)
        url_box.set_margin_bottom(6)
        url_box.set_margin_start(6)
        url_box.set_margin_end(6)
        self._url_entry = Gtk.Entry()
        self._url_entry.set_placeholder_text("https://example.com")
        self._url_entry.set_hexpand(True)
        go_btn = Gtk.Button(label="Go")
        go_btn.connect("clicked", self._on_go_url)
        url_box.append(self._url_entry)
        url_box.append(go_btn)
        url_frame.set_child(url_box)
        controls.append(url_frame)

        # Keyboard shortcuts controller
        self._setup_shortcuts(window)

        # Initial refresh
        self._refresh_devices()

        return window

    def _setup_shortcuts(self, window: Gtk.ApplicationWindow) -> None:
        """Register Ctrl+Shift+arrow key shortcuts (Android Dex style)."""
        controller = Gtk.EventControllerKey()
        controller.connect("key-pressed", self._on_key_pressed)
        window.add_controller(controller)

    def _on_key_pressed(
        self, controller: Gtk.EventControllerKey, keyval: int, keycode: int, state: Gdk.ModifierType
    ) -> bool:
        """Handle keyboard shortcuts.

        Ctrl+Shift+Up/Down/Left/Right map to device navigation actions.
        """
        ctrl = bool(state & Gdk.ModifierType.CONTROL_MASK)
        shift = bool(state & Gdk.ModifierType.SHIFT_MASK)

        if not (ctrl and shift):
            return False

        if not self._selected_device:
            return True

        # Gdk keyval constants
        GDK_KEY_Up = 65362
        GDK_KEY_Down = 65364
        GDK_KEY_Left = 65361
        GDK_KEY_Right = 65363

        if keyval == GDK_KEY_Up:
            self.input.send_key(self._selected_device.serial, 19)  # DPAD_UP
            return True
        if keyval == GDK_KEY_Down:
            self.input.send_key(self._selected_device.serial, 20)  # DPAD_DOWN
            return True
        if keyval == GDK_KEY_Left:
            self.input.send_key(self._selected_device.serial, 21)  # DPAD_LEFT
            return True
        if keyval == GDK_KEY_Right:
            self.input.send_key(self._selected_device.serial, 22)  # DPAD_RIGHT
            return True

        return False

    def _refresh_devices(self) -> None:
        if not self._device_list:
            return
        # Clear existing rows (GTK4: iterate via first child + next sibling)
        row = self._device_list.get_first_child()
        while row is not None:
            next_row = row.get_next_sibling()
            self._device_list.remove(row)
            row = next_row

        devices = self.adb.list_devices()
        for dev in devices:
            row = DeviceRow(dev)
            self._device_list.append(row)

        if self._status_label:
            self._status_label.set_text(f"{len(devices)} device(s) found")

    def _on_row_selected(self, listbox: Gtk.ListBox, row: Optional[DeviceRow]) -> None:
        self._selected_device = row.device if row else None
        sensitive = self._selected_device is not None
        if self._connect_btn:
            self._connect_btn.set_sensitive(sensitive)
        if self._mirror_btn:
            self._mirror_btn.set_sensitive(sensitive and self.scrcpy.is_available())
        if self._status_label:
            if self._selected_device:
                self._status_label.set_text(
                    f"Selected: {self._selected_device.model or 'Android'} "
                    f"({self._selected_device.serial})"
                )
            else:
                self._status_label.set_text("No device selected")

    def _send_key(self, keycode: int) -> None:
        if self._selected_device:
            self.input.send_key(self._selected_device.serial, keycode)

    def _volume_up(self) -> None:
        if self._selected_device:
            self.volume.up(self._selected_device.serial)

    def _volume_down(self) -> None:
        if self._selected_device:
            self.volume.down(self._selected_device.serial)

    def _recent_apps(self) -> None:
        if self._selected_device:
            self.windows.recent_apps(self._selected_device.serial)

    def _lock(self) -> None:
        if self._selected_device:
            self.windows.lock(self._selected_device.serial)

    def _on_connect(self, _button: Gtk.Button) -> None:
        if not self._selected_device:
            return
        dev = self._selected_device
        result = self.adb.shell(dev.serial, "echo hello")
        if result.returncode == 0:
            self._status_label.set_text(f"Connected to {dev.serial}")
        else:
            self._status_label.set_text(f"Failed to connect: {result.stderr.strip()}")

    def _on_mirror(self, _button: Gtk.Button) -> None:
        if not self._selected_device:
            return
        try:
            self.scrcpy.start(serial=self._selected_device.serial)
            self._status_label.set_text(f"Mirroring {self._selected_device.serial}...")
        except RuntimeError as exc:
            self._status_label.set_text(str(exc))

    def _on_go_url(self, _button: Gtk.Button) -> None:
        if not self._selected_device:
            return
        url = self._url_entry.get_text().strip() if self._url_entry else ""
        if not url:
            return
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        self.urls.open(self._selected_device.serial, url)
        self._status_label.set_text(f"Opened {url}")


def main() -> int:
    app = AndroidDex()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
