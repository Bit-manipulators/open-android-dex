#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Open Android DeX — Demo Mode Launcher
# Allows contributors to run and test the desktop shell without a connected phone.
# -----------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

CHOICE="${1:-auto}"

echo "=========================================================="
echo "      🚀 Launching Open Android DeX in Demo Mode          "
echo "  (No physical phone or ADB device connection required!)  "
echo "=========================================================="

if [[ "$CHOICE" == "--gtk" || "$CHOICE" == "gtk" || "$CHOICE" == "python" ]]; then
    echo "Starting Python / GTK4 Desktop Shell in Demo Mode..."
    exec python3 app.py --demo
fi

if [[ "$CHOICE" == "--flutter" || "$CHOICE" == "flutter" ]]; then
    echo "Starting Flutter Compositor in Demo Mode..."
    exec ./run_flutter_dex.sh --demo
fi

# Auto-detect: if flutter is installed, run flutter; otherwise fall back to Python GTK
if command -v flutter >/dev/null 2>&1; then
    echo "Detected Flutter SDK. Launching Flutter Compositor Demo..."
    exec ./run_flutter_dex.sh --demo
else
    echo "Flutter not in PATH. Launching Python / GTK4 Shell Demo..."
    exec python3 app.py --demo
fi

