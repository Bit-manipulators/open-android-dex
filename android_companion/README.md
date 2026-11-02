# Open Android DeX — Companion Android Service

This module is a clean-room, open-source companion bridge that runs directly on Android devices to stream real-time events to the **Open Android DeX** desktop shell.

## Features

1. **Real-Time Notification Mirroring (`NotificationService.kt`)**:
   * Uses Android's native `NotificationListenerService` to capture posted/removed notifications without polling.
   * Broadcasts structured JSON events containing app name, package, title, and body.

2. **Foreground TCP Bridge Daemon (`CompanionServer.kt`)**:
   * Runs a lightweight coroutines TCP server on port `8888`.
   * Can be port-forwarded seamlessly via ADB:
     ```bash
     adb forward tcp:8888 tcp:8888
     ```

3. **Zero Polling Overhead**:
   * Instantaneous push notifications instead of repetitive `adb shell` execution.
