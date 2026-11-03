#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check standard Flutter locations if not already in PATH
if ! command -v flutter >/dev/null 2>&1; then
    for candidate in \
        "/home/amit/development/flutter/bin/flutter" \
        "$HOME/development/flutter/bin/flutter" \
        "$HOME/flutter/bin/flutter" \
        "/opt/flutter/bin/flutter" \
        "/usr/local/flutter/bin/flutter"; do
        if [ -x "$candidate" ]; then
            export PATH="$(dirname "$candidate"):$PATH"
            break
        fi
    done
fi

if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Error: 'flutter' command not found in PATH or standard installation locations." >&2
    echo "Please install Flutter SDK (version 3.24+ recommended) and add it to your PATH." >&2
    exit 1
fi

# Ensure Skia backend is preferred for FlPixelBufferTexture stability under Wayland
export FLUTTER_ENGINE_SWITCHES=1
export FLUTTER_ENGINE_SWITCH_1="--no-enable-impeller"

echo "🚀 Building & Launching Open Android Dex (Flutter Desktop)..."
flutter run -d linux
