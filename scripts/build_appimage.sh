#!/usr/bin/env bash
# ==============================================================================
# Open Android DeX — Linux AppImage Packaging Tool
# Produces: Open-Android-DeX-Linux-x86_64.AppImage
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

echo "============================================================"
echo "  🚀 Open Android DeX — AppImage Build Pipeline"
echo "============================================================"

# 1. Locate Flutter SDK
FLUTTER_BIN="flutter"
if ! command -v flutter >/dev/null 2>&1; then
    for candidate in \
        "/home/amit/development/flutter/bin/flutter" \
        "$HOME/development/flutter/bin/flutter" \
        "$HOME/flutter/bin/flutter" \
        "/opt/flutter/bin/flutter"; do
        if [ -x "$candidate" ]; then
            FLUTTER_BIN="$candidate"
            export PATH="$(dirname "$candidate"):$PATH"
            break
        fi
    done
fi

if ! command -v "${FLUTTER_BIN}" >/dev/null 2>&1; then
    echo "❌ Error: Flutter SDK not found. Please install Flutter 3.24+." >&2
    exit 1
fi

# 2. Build Linux Application in Release Mode
echo "==> Building Flutter Linux Release..."
"${FLUTTER_BIN}" build linux --release

BUNDLE_DIR="${REPO_ROOT}/build/linux/x64/release/bundle"
if [ ! -d "${BUNDLE_DIR}" ] || [ ! -f "${BUNDLE_DIR}/open_android_dex" ]; then
    echo "❌ Error: Build bundle not found at ${BUNDLE_DIR}" >&2
    exit 1
fi

# 3. Prepare AppDir Directory Structure
BUILD_DIR="${REPO_ROOT}/build/appimage"
APPDIR="${BUILD_DIR}/AppDir"
OUT_DIR="${REPO_ROOT}/build/release_artifacts"

rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/lib"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${OUT_DIR}"

echo "==> Assembling AppDir files..."
# Copy binary
cp -a "${BUNDLE_DIR}/open_android_dex" "${APPDIR}/usr/bin/open_android_dex"
chmod +x "${APPDIR}/usr/bin/open_android_dex"

# Copy libraries
cp -a "${BUNDLE_DIR}/lib/"* "${APPDIR}/usr/lib/"

# Copy data folder
mkdir -p "${APPDIR}/usr/bin/data"
cp -a "${BUNDLE_DIR}/data/"* "${APPDIR}/usr/bin/data/"

# Create relative symlink so Flutter engine finds libapp.so at $ORIGIN/lib/libapp.so
ln -sfn ../lib "${APPDIR}/usr/bin/lib"

# Copy system dependencies that might vary across distros (FFmpeg & shared libs)
for lib in libavcodec libavformat libswscale libavutil; do
    find /usr/lib /usr/lib64 -name "${lib}*.so*" -exec cp -d {} "${APPDIR}/usr/lib/" \; 2>/dev/null || true
done

# Bundle standalone ADB, scrcpy, and scrcpy-server inside AppImage
echo "==> Bundling portable ADB and scrcpy binaries..."
mkdir -p "${APPDIR}/usr/share/scrcpy"
CACHE_DIR="${REPO_ROOT}/build/downloads"
mkdir -p "${CACHE_DIR}"

SCRCPY_VERSION="v5.0.1"
TARBALL="${CACHE_DIR}/scrcpy-linux-x86_64-${SCRCPY_VERSION}.tar.gz"

# 1. Download official portable prebuilts if not cached
if [ ! -f "${TARBALL}" ]; then
    echo "    Downloading portable scrcpy & adb Linux bundle (${SCRCPY_VERSION})..."
    curl -fsSL -o "${TARBALL}" \
        "https://github.com/Genymobile/scrcpy/releases/download/${SCRCPY_VERSION}/scrcpy-linux-x86_64-${SCRCPY_VERSION}.tar.gz" || true
fi

# 2. Extract into AppDir
if [ -f "${TARBALL}" ]; then
    EXTRACT_DIR="${CACHE_DIR}/scrcpy-linux-${SCRCPY_VERSION}"
    mkdir -p "${EXTRACT_DIR}"
    tar -zxf "${TARBALL}" -C "${EXTRACT_DIR}" --strip-components=1 2>/dev/null || true

    if [ -f "${EXTRACT_DIR}/adb" ]; then
        cp -a "${EXTRACT_DIR}/adb" "${APPDIR}/usr/bin/adb"
        chmod +x "${APPDIR}/usr/bin/adb"
        echo "    ✅ Bundled adb into AppImage"
    fi

    if [ -f "${EXTRACT_DIR}/scrcpy" ]; then
        cp -a "${EXTRACT_DIR}/scrcpy" "${APPDIR}/usr/bin/scrcpy"
        chmod +x "${APPDIR}/usr/bin/scrcpy"
        echo "    ✅ Bundled scrcpy into AppImage"
    fi

    if [ -f "${EXTRACT_DIR}/scrcpy-server" ]; then
        cp -a "${EXTRACT_DIR}/scrcpy-server" "${APPDIR}/usr/share/scrcpy/scrcpy-server"
        cp -a "${EXTRACT_DIR}/scrcpy-server" "${APPDIR}/usr/bin/scrcpy-server"
        echo "    ✅ Bundled scrcpy-server into AppImage"
    fi
fi

# Fallback: Copy from host system if not extracted from bundle
if [ ! -f "${APPDIR}/usr/bin/adb" ] && command -v adb >/dev/null 2>&1; then
    cp -a "$(command -v adb)" "${APPDIR}/usr/bin/adb"
    chmod +x "${APPDIR}/usr/bin/adb"
    echo "    ✅ Copied host adb into AppImage"
fi

if [ ! -f "${APPDIR}/usr/bin/scrcpy" ] && command -v scrcpy >/dev/null 2>&1; then
    cp -a "$(command -v scrcpy)" "${APPDIR}/usr/bin/scrcpy"
    chmod +x "${APPDIR}/usr/bin/scrcpy"
    echo "    ✅ Copied host scrcpy into AppImage"
fi

if [ ! -f "${APPDIR}/usr/share/scrcpy/scrcpy-server" ]; then
    for candidate in /usr/share/scrcpy/scrcpy-server /usr/local/share/scrcpy/scrcpy-server; do
        if [ -f "$candidate" ]; then
            cp -a "$candidate" "${APPDIR}/usr/share/scrcpy/scrcpy-server"
            cp -a "$candidate" "${APPDIR}/usr/bin/scrcpy-server"
            echo "    ✅ Copied host scrcpy-server into AppImage"
            break
        fi
    done
fi

# Copy Icon
if [ -f "${REPO_ROOT}/assets/app_icon.png" ]; then
    cp "${REPO_ROOT}/assets/app_icon.png" "${APPDIR}/open_android_dex.png"
    cp "${REPO_ROOT}/assets/app_icon.png" "${APPDIR}/.DirIcon"
    cp "${REPO_ROOT}/assets/app_icon.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/open_android_dex.png"
fi

# 4. Generate Desktop Entry File
cat > "${APPDIR}/open_android_dex.desktop" << 'EOF'
[Desktop Entry]
Name=Open Android DeX
GenericName=Android Desktop Workstation
Comment=Transform your Android device into a multi-window desktop workstation
Exec=open_android_dex %U
Icon=open_android_dex
Terminal=false
Type=Application
Categories=Utility;System;Development;
StartupWMClass=open_android_dex
Keywords=Android;DeX;Screen;Mirror;ADB;scrcpy;
EOF

cp "${APPDIR}/open_android_dex.desktop" "${APPDIR}/usr/share/applications/"

# 5. Generate AppRun Entrypoint Script
cat > "${APPDIR}/AppRun" << 'EOF'
#!/bin/bash
set -e

# Resolve AppDir root
APPDIR="$(dirname "$(readlink -f "${0}")")"

export APPDIR
export PATH="${APPDIR}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${APPDIR}/usr/lib/open_android_dex:${LD_LIBRARY_PATH:-}"
export XDG_DATA_DIRS="${APPDIR}/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export SCRCPY_SERVER_PATH="${APPDIR}/usr/share/scrcpy/scrcpy-server"
export ADB="${APPDIR}/usr/bin/adb"

# Ensure Skia backend is preferred for FlPixelBufferTexture stability under Wayland
export FLUTTER_ENGINE_SWITCHES=1
export FLUTTER_ENGINE_SWITCH_1="--no-enable-impeller"

# Execute Flutter Desktop compositor with bundled adb and scrcpy
exec "${APPDIR}/usr/bin/open_android_dex" "$@"
EOF

chmod +x "${APPDIR}/AppRun"

# 6. Obtain appimagetool and runtime if not already present
APPIMAGETOOL="${BUILD_DIR}/appimagetool"
RUNTIME_FILE="${BUILD_DIR}/runtime-x86_64"

if [ ! -f "${RUNTIME_FILE}" ]; then
    echo "==> Downloading AppImage runtime..."
    curl -fsSL -o "${RUNTIME_FILE}" \
        "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64" || true
fi

if ! command -v appimagetool >/dev/null 2>&1; then
    if [ ! -f "${APPIMAGETOOL}" ]; then
        echo "==> Downloading appimagetool..."
        curl -fsSL -o "${APPIMAGETOOL}" \
            "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" || \
        curl -fsSL -o "${APPIMAGETOOL}" \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "${APPIMAGETOOL}"
    fi
    TOOL_CMD="${APPIMAGETOOL}"
else
    TOOL_CMD="appimagetool"
fi

# 7. Package AppImage
VERSION="${1:-${APP_VERSION:-${VERSION:-}}}"
if [ -n "${VERSION}" ]; then
    APPIMAGE_NAME="Open-Android-DeX-${VERSION}-Linux-x86_64.AppImage"
else
    APPIMAGE_NAME="Open-Android-DeX-Linux-x86_64.AppImage"
fi
OUTPUT_APPIMAGE="${OUT_DIR}/${APPIMAGE_NAME}"
rm -f "${OUTPUT_APPIMAGE}"

echo "==> Creating AppImage: ${OUTPUT_APPIMAGE}..."
export ARCH="x86_64"

EXTRA_ARGS=()
if [ -f "${RUNTIME_FILE}" ]; then
    EXTRA_ARGS+=(--runtime-file "${RUNTIME_FILE}")
fi

# Use --appimage-extract-and-run in case FUSE is not available in container/CI
if "${TOOL_CMD}" --version >/dev/null 2>&1; then
    "${TOOL_CMD}" "${EXTRA_ARGS[@]}" "${APPDIR}" "${OUTPUT_APPIMAGE}"
else
    "${TOOL_CMD}" --appimage-extract-and-run "${EXTRA_ARGS[@]}" "${APPDIR}" "${OUTPUT_APPIMAGE}"
fi

chmod +x "${OUTPUT_APPIMAGE}"

echo "============================================================"
echo "  ✅ AppImage Successfully Created!"
echo "  Artifact: ${OUTPUT_APPIMAGE}"
echo "  Size:     $(du -h "${OUTPUT_APPIMAGE}" | cut -f1)"
echo "============================================================"
