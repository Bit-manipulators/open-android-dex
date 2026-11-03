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
