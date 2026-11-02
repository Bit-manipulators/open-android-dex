"""Boot sequencer.

Original implementation of a sequenced device-initialization flow:
start ADB, detect or select a device, verify the link, and confirm
screen-mirroring readiness, reporting progress events along the way.
The step order and progress semantics are modeled on behavior
described in public architecture documentation; all code is original.

BootManager emits events from a worker thread. UI callers must marshal
them onto the main loop themselves (e.g. GLib.idle_add).
"""

from __future__ import annotations

import threading
from dataclasses import dataclass, field
from typing import Callable, List, Optional

from adb_client import AdbClient, Device
from scrcpy_client import ScrcpyClient


@dataclass
class BootEvent:
    """One step of the boot sequence."""

    message: str
    progress: float          # 0.0 .. 1.0
    is_error: bool = False
    needs_device_selection: bool = False
    device: Optional[Device] = None
    device_info: dict = field(default_factory=dict)


class BootManager:
    """Runs the initialization sequence in a background thread."""

    BOOT_TIMEOUT_SECONDS = 15.0

    def __init__(self, adb: AdbClient, scrcpy: ScrcpyClient) -> None:
        self.adb = adb
        self.scrcpy = scrcpy
        self._thread: Optional[threading.Thread] = None
        self._cancelled = threading.Event()

    @property
    def running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def cancel(self) -> None:
        """Request cancellation; the current step may still finish."""
        self._cancelled.set()

    def start(self, serial: Optional[str], on_event: Callable[[BootEvent], None]) -> None:
        """Run the full boot sequence. ``on_event`` is called from the thread."""
        if self.running:
            raise RuntimeError("boot sequence already running")

        def target() -> None:
            try:
                self._run(serial, on_event)
            except Exception as exc:  # defensive: never kill the app on boot
                self._emit(
                    on_event,
                    f"Boot failed: {exc}",
                    progress=0.0,
                    is_error=True,
                )

        self._cancelled.clear()
        self._thread = threading.Thread(target=target, daemon=True)
        self._thread.start()

    def _emit(
        self,
        on_event: Callable[[BootEvent], None],
        message: str,
        progress: float,
        is_error: bool = False,
        needs_device_selection: bool = False,
        device: Optional[Device] = None,
        device_info: Optional[dict] = None,
    ) -> None:
        if self._cancelled.is_set():
            return
        on_event(
            BootEvent(
                message=message,
                progress=progress,
                is_error=is_error,
                needs_device_selection=needs_device_selection,
                device=device,
                device_info=device_info or {},
            )
        )

    def _run(self, serial: Optional[str], on_event: Callable[[BootEvent], None]) -> None:
        emit = lambda *a, **kw: self._emit(on_event, *a, **kw)

        # Step 1 — ADB server.
        emit("Starting ADB server…", 0.04)
        if not self.adb.is_available():
            emit("adb not found — install android-tools-adb", 0.10, is_error=True)
            return
        result = self.adb.start_server()
        if result.returncode != 0:
            emit(
                f"Failed to start ADB server: {result.stderr.strip()}",
                0.10,
                is_error=True,
            )
            return

        # Step 2 — device detection / selection.
        emit("Detecting Android devices…", 0.15)
        all_devs = self.adb.list_devices()
        unauthorized = [d for d in all_devs if d.state == "unauthorized"]
        online = [d for d in all_devs if d.state == "device"]

        if not online:
            if unauthorized:
                emit(
                    "Device unauthorized — accept the debugging prompt on the phone",
                    0.15,
                    is_error=True,
                    needs_device_selection=True,
                )
            else:
                emit(
                    "No device found — connect a phone with USB debugging enabled",
                    0.15,
                    is_error=True,
                    needs_device_selection=True,
                )
            return

        if serial:
            chosen = next((d for d in online if d.serial == serial), None)
            if chosen is None:
                emit(
                    f"Selected device {serial} is no longer connected",
                    0.15,
                    is_error=True,
                    needs_device_selection=True,
                )
                return
        elif len(online) == 1:
            chosen = online[0]
        else:
            emit(
                "Multiple devices connected — select one in the device list",
                0.15,
                is_error=True,
                needs_device_selection=True,
            )
            return

        # Step 3 — verify the link (read device identity at shell level).
        emit(f"Verifying link with {chosen.serial}…", 0.40)
        model = self.adb.get_property(chosen.serial, "ro.product.model")
        if not model:
            emit(
                f"Device {chosen.serial} did not respond to shell — reconnect USB",
                0.40,
                is_error=True,
                needs_device_selection=True,
            )
            return

        brand = self.adb.get_property(chosen.serial, "ro.product.brand") or ""
        android = self.adb.get_property(chosen.serial, "ro.build.version.release") or ""
        info = {"model": model, "brand": brand, "android_version": android}

        # Step 4 — confirm mirroring support (scrcpy present on the host).
        emit("Checking screen-mirroring support…", 0.70)
        if not self.scrcpy.is_available():
            emit(
                "scrcpy not found — mirroring disabled (install scrcpy)",
                0.70,
                is_error=True,
            )
            return

        # Step 5 — ready.
        emit(
            f"System ready — {brand} {model} (Android {android})".strip(),
            1.00,
            device=chosen,
            device_info=info,
        )