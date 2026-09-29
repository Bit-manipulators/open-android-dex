#!/usr/bin/env bash
# ==============================================================================
# OpenDeX: Single-Window Android Desktop Experience over ADB
# ==============================================================================
# Creates an independent 1080p virtual desktop display on your phone,
# enables multi-window freeform resizing, and provides a taskbar with app tabs
# inside ONE single laptop window.
# ==============================================================================

set -e

# Default display configuration
RESOLUTION="${OPENDEX_RES:-1920x1080}"
DPI="${OPENDEX_DPI:-180}"
TITLE="OpenDeX Workstation"
TASKBAR_PKG="com.farmerbb.taskbar"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_PATH="${SCRIPT_DIR}/Taskbar-6.2.2.apk"

# Colors for terminal output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}        🚀 OpenDeX - Android Desktop Engine        ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Check prerequisites
if ! command -v adb &>/dev/null; then
    echo -e "${RED}[ERROR] 'adb' is not installed or not in PATH.${NC}"
    exit 1
fi

if ! command -v scrcpy &>/dev/null; then
    echo -e "${RED}[ERROR] 'scrcpy' is not installed or not in PATH.${NC}"
    exit 1
fi

# 2. Check connected ADB devices
echo -e "${YELLOW}[1/4] Checking connected Android devices...${NC}"
DEVICE_COUNT=$(adb devices | grep -v "List of devices attached" | grep -v "^$" | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo -e "${RED}[ERROR] No Android device detected over ADB!${NC}"
    echo -e "  - Plug your phone in via USB with 'USB Debugging' enabled in Developer Options."
    echo -e "  - Or connect wirelessly using: adb connect <phone-ip>:5555"
    exit 1
elif [ "$DEVICE_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}[NOTE] Multiple devices detected. Using default device:${NC}"
    adb devices
fi

DEVICE_MODEL=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
ANDROID_VER=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
echo -e "${GREEN}[OK] Connected: ${DEVICE_MODEL} (Android ${ANDROID_VER})${NC}"

# 3. Enable Android Freeform and Desktop Mode settings
echo -e "${YELLOW}[2/3] Enabling Native Android Freeform & Desktop Mode...${NC}"
adb shell settings put global enable_freeform_support 1 2>/dev/null || true
adb shell settings put global force_resizable_activities 1 2>/dev/null || true
adb shell settings put global force_desktop_mode_on_external_displays 1 2>/dev/null || true
adb shell setprop persist.wm.debug.desktop_mode 1 2>/dev/null || true
echo -e "${GREEN}[OK] Native Desktop flags applied (Zero APKs on phone).${NC}"

# 4. Hyprland Window Management Rules (Prevents tall squished letterboxing)
if command -v hyprctl &>/dev/null; then
    echo -e "${YELLOW}Configuring Hyprland window rules for true 16:9 widescreen...${NC}"
    hyprctl keyword windowrulev2 "float,title:^(OpenDeX.*)$" &>/dev/null || true
    hyprctl keyword windowrulev2 "size 1600 900,title:^(OpenDeX.*)$" &>/dev/null || true
    hyprctl keyword windowrulev2 "center,title:^(OpenDeX.*)$" &>/dev/null || true
    hyprctl keyword windowrulev2 "float,title:^(Win11-DeX-Bar)$" &>/dev/null || true
    hyprctl keyword windowrulev2 "pin,title:^(Win11-DeX-Bar)$" &>/dev/null || true
    hyprctl keyword windowrulev2 "noborder,title:^(Win11-DeX-Bar)$" &>/dev/null || true
fi

# 5. Background watcher: Auto-configure Freeform mode & Native Desktop Home
(
    # Wait for the new display to be created by scrcpy
    for i in {1..30}; do
        sleep 0.5
        NEW_ID=$(adb shell dumpsys display 2>/dev/null | grep -o 'mDisplayId=[1-9][0-9]*' | head -n 1 | cut -d'=' -f2 || true)
        if [ -n "$NEW_ID" ]; then
            echo -e "\n${GREEN}[OK] Secondary Desktop Display detected (ID: $NEW_ID)${NC}"
            echo -e "${YELLOW}Enabling Freeform Multi-Window Mode on display $NEW_ID...${NC}"
            # Force the display into Freeform Windowing Mode (Mode 5)
            adb shell cmd window set-display-windowing-mode -d "$NEW_ID" 5 2>/dev/null || true
            echo -e "${YELLOW}Launching Native Desktop Environment on display $NEW_ID...${NC}"
            adb shell am start --display "$NEW_ID" -n com.android.launcher3/.secondarydisplay.SecondaryDisplayLauncher 2>/dev/null || true
            break
        fi
    done
) &

# 6. Launch Wayland Native Win11 Taskbar with Start Menu, 3 Buttons & App Tabs
python3 "${SCRIPT_DIR}/win11_layer_bar.py" &
BAR_PID=$!
trap "kill $BAR_PID 2>/dev/null || true" EXIT INT TERM

# 7. Launch the Single-Window OpenDeX Session
echo -e "${YELLOW}[3/3] Launching OpenDeX Session in ONE Laptop Window...${NC}"
echo -e "${GREEN}Configuration:${NC} ${RESOLUTION} @ ${DPI} DPI"
echo -e "${GREEN}Controls:${NC}"
echo -e "  - Win11 Bar: [⊞ Start Apps] [◀ Back] [● Home] [■ Recents] + App Tabs"
echo -e "  - Mouse: Point, Click, Drag edges to resize windows, Scroll wheel"
echo -e "  - Right Click: Back / Context menu"
echo -e "  - Middle Click: Home"
echo -e "  - Alt+f: Toggle Fullscreen"
echo -e "${BLUE}====================================================${NC}"

# Run scrcpy with secondary virtual display using stable SDK input mode
scrcpy \
    --new-display="${RESOLUTION}/${DPI}" \
    --window-title="${TITLE}" \
    --keyboard=sdk \
    --mouse=sdk \
    --video-bit-rate=12M \
    --max-fps=60 \
    --stay-awake


