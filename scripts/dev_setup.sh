#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Open Android DeX — Contributor Development Environment Setup Script
# Detects host Linux distribution and installs necessary build dependencies.
# -----------------------------------------------------------------------------

set -e

echo "=========================================================="
echo "    🛠️ Open Android DeX: Development Setup Installer      "
echo "=========================================================="

# Check if running as root
SUDO=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "⚠️ Note: 'sudo' not detected. You may need root privileges to install packages."
    fi
fi

install_ubuntu_debian() {
    echo "📦 Detected Debian / Ubuntu based system."
    $SUDO apt update
    $SUDO apt install -y \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        libgtk-4-dev \
        libgtk-3-dev \
        libglib2.0-dev \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswscale-dev \
        adb \
        scrcpy \
        python3 \
        python3-pip \
        python3-gi \
        python3-gi-cairo \
        gir1.2-gtk-4.0
}

install_arch() {
    echo "📦 Detected Arch Linux / Manjaro system."
    $SUDO pacman -Sy --needed --noconfirm \
        base-devel \
        cmake \
        ninja \
        pkgconf \
        gtk4 \
        gtk3 \
        ffmpeg \
        android-tools \
        scrcpy \
        python \
        python-pip \
        python-gobject
}

install_fedora() {
    echo "📦 Detected Fedora / RHEL system."
    $SUDO dnf install -y \
        gcc-c++ \
        cmake \
        ninja-build \
        pkgconfig \
        gtk4-devel \
        gtk3-devel \
        ffmpeg-devel \
        android-tools \
        scrcpy \
        python3 \
        python3-pip \
        python3-gobject
}

if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian|pop|linuxmint|elementary)
            install_ubuntu_debian
            ;;
        arch|manjaro|endeavouros)
            install_arch
            ;;
        fedora|rhel|centos)
            install_fedora
            ;;
        *)
            if [[ "$ID_LIKE" == *"debian"* || "$ID_LIKE" == *"ubuntu"* ]]; then
                install_ubuntu_debian
            elif [[ "$ID_LIKE" == *"arch"* ]]; then
                install_arch
            elif [[ "$ID_LIKE" == *"fedora"* || "$ID_LIKE" == *"rhel"* ]]; then
                install_fedora
            else
                echo "⚠️ Unrecognized Linux distribution '$ID'. Please ensure GTK4, ADB, scrcpy, FFmpeg, and CMake are installed."
            fi
            ;;
    esac
else
    echo "⚠️ /etc/os-release not found. Please install GTK4, ADB, scrcpy, and CMake manually."
fi

echo ""
echo "----------------------------------------------------------"
echo "🔍 Checking Tooling Status:"
echo "----------------------------------------------------------"

for tool in python3 adb scrcpy cmake ninja; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✅ $tool: $(command -v "$tool")"
    else
        echo "  ❌ $tool: missing"
    fi
done

if command -v flutter >/dev/null 2>&1; then
    echo "  ✅ flutter: $(command -v flutter) ($(flutter --version | head -n 1))"
else
    echo "  ℹ️  flutter: not found in PATH."
    echo "     To develop the Flutter compositor, download Flutter from:"
    echo "     https://docs.flutter.dev/get-started/install/linux/desktop"
fi

echo ""
echo "=========================================================="
echo "  🎉 Environment Setup Check Complete!"
echo "  • Run unit tests:  python3 run_tests.py"
echo "  • Run demo mode:   ./scripts/run_demo.sh"
echo "=========================================================="

