#!/usr/bin/env python3
"""
Open Android DeX — Dependency Bundler
Downloads and bundles standalone adb and scrcpy binaries for Windows and Linux.
Ensures end users and developers have ready-to-use binaries without manual setup.
"""

import os
import sys
import platform
import urllib.request
import tarfile
import zipfile
import shutil

SCRCPY_VERSION = "v5.0.1"
SCRCPY_BASE_URL = f"https://github.com/Genymobile/scrcpy/releases/download/{SCRCPY_VERSION}"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOWNLOADS_DIR = os.path.join(REPO_ROOT, "build", "downloads")
ASSETS_BIN_DIR = os.path.join(REPO_ROOT, "assets", "bin")

def download_file(url: str, dest_path: str):
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    if os.path.exists(dest_path) and os.path.getsize(dest_path) > 1000:
        print(f"  [cached] {os.path.basename(dest_path)}")
        return
    print(f"  [downloading] {url} -> {dest_path}")
    req = urllib.request.Request(url, headers={"User-Agent": "OpenAndroidDeX/1.0"})
    with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as f:
        shutil.copyfileobj(resp, f)
    print(f"  [completed] {os.path.basename(dest_path)} ({os.path.getsize(dest_path) / (1024*1024):.1f} MB)")

def bundle_linux(target_dir: str = ASSETS_BIN_DIR):
    print("==> Bundling Linux x86_64 dependencies...")
    tar_name = f"scrcpy-linux-x86_64-{SCRCPY_VERSION}.tar.gz"
    tar_path = os.path.join(DOWNLOADS_DIR, tar_name)
    download_file(f"{SCRCPY_BASE_URL}/{tar_name}", tar_path)

    os.makedirs(target_dir, exist_ok=True)
    with tarfile.open(tar_path, "r:gz") as tar:
        for member in tar.getmembers():
            base = os.path.basename(member.name)
            if base in ("adb", "scrcpy", "scrcpy-server"):
                f = tar.extractfile(member)
                if f:
                    out_path = os.path.join(target_dir, base)
                    with open(out_path, "wb") as out:
                        shutil.copyfileobj(f, out)
                    if base in ("adb", "scrcpy"):
                        os.chmod(out_path, 0o755)
                    print(f"  ✅ Extracted {base} -> {out_path}")

def bundle_windows(target_dir: str = ASSETS_BIN_DIR):
    print("==> Bundling Windows x64 dependencies...")
    zip_name = f"scrcpy-win64-{SCRCPY_VERSION}.zip"
    zip_path = os.path.join(DOWNLOADS_DIR, zip_name)
    download_file(f"{SCRCPY_BASE_URL}/{zip_name}", zip_path)

    os.makedirs(target_dir, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as z:
        for name in z.namelist():
            base = os.path.basename(name)
            if not base:
                continue
            # Keep executables, server, and libraries
            if (base.endswith(".exe") or base.endswith(".dll") or base == "scrcpy-server"):
                out_path = os.path.join(target_dir, base)
                with z.open(name) as src, open(out_path, "wb") as dst:
                    shutil.copyfileobj(src, dst)
                print(f"  ✅ Extracted {base} -> {out_path}")

def main():
    os.makedirs(DOWNLOADS_DIR, exist_ok=True)
    os.makedirs(ASSETS_BIN_DIR, exist_ok=True)

    target = sys.argv[1].lower() if len(sys.argv) > 1 else platform.system().lower()

    if target in ("linux", "all"):
        bundle_linux()
    if target in ("windows", "win32", "all"):
        bundle_windows()

    print("\n🎉 Dependencies successfully bundled! Application is ready to use.")

if __name__ == "__main__":
    main()
