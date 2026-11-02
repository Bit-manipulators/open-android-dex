#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FLUTTER_BIN="/home/amit/development/flutter/bin/flutter"

if [ -x "$FLUTTER_BIN" ]; then
    export PATH="/home/amit/development/flutter/bin:$PATH"
fi

# Ensure Skia backend is preferred for FlPixelBufferTexture stability under Wayland
export FLUTTER_ENGINE_SWITCHES=1
export FLUTTER_ENGINE_SWITCH_1="--no-enable-impeller"

echo "🚀 Building & Launching Open Android Dex (Flutter Desktop)..."
flutter run -d linux
