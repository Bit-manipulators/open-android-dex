import pytest
from app import OpenAndroidDex, AppInfo, AppConfig, WELL_KNOWN_APPS


def test_well_known_apps():
    assert "com.android.chrome" in WELL_KNOWN_APPS
    name, icon, grad = WELL_KNOWN_APPS["com.android.chrome"]
    assert name == "Chrome"
    assert icon == "google-chrome"
    assert grad == 0


def test_resolve_app_meta():
    app = OpenAndroidDex()

    # Known package
    label, icon, color = app._resolve_app_meta("com.android.chrome")
    assert label == "Chrome"
    assert icon == "google-chrome"
    assert color == 0

    # Unknown package
    label, icon, color = app._resolve_app_meta("com.example.foobar")
    assert "Foobar" in label
    assert icon is None
    assert isinstance(color, int)


def test_make_monogram():
    app = OpenAndroidDex()
    assert app._make_monogram("Google Chrome") == "GC"
    assert app._make_monogram("Calculator") == "CA"
    assert app._make_monogram("A") == "A"
    assert app._make_monogram("") == "A"


def test_app_config_load():
    cfg = AppConfig.load()
    assert isinstance(cfg.brand_icons, dict)
    # Check that known brand icons exist in assets
    assert "android" in cfg.brand_icons
    assert "samsung" in cfg.brand_icons


def test_app_demo_mode():
    app = OpenAndroidDex(demo_mode=True)
    assert app.demo_mode is True
    # Test entering demo mode
    app._enter_demo_mode()
    assert app._selected_device is not None
    assert "Demo" in app._selected_device.model
    assert len(app._all_apps) > 5
    # Test demo tile launch without error
    app._launch_tile(app._all_apps[0])
    # Test demo mirror toggle
    app._on_mirror_toggle(None)
    assert app._demo_mirror_active is True
    app._on_mirror_toggle(None)
    assert app._demo_mirror_active is False
    # Test volume / key in demo mode
    app._volume_up()
    app._volume_down()
    app._send_key(3)


def test_app_battery_visualizer_states():
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk

    app = OpenAndroidDex(demo_mode=True)
    box = Gtk.Box()
    box.add_css_class("desk-chip")
    label = Gtk.Label(label="🔋 —")
    box.append(label)
    app._battery_box = box
    app._battery_label = label

    # 1. Demo mode sets charging pulse class and bolt icon
    app._enter_demo_mode()
    assert label.get_text() == "⚡ 94%"
    assert box.has_css_class("desk-chip-charging")
    assert not box.has_css_class("desk-chip-battery-low")


