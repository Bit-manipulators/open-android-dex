import 'dart:async';
import 'dart:io';
import '../models/app_info.dart';
import '../models/notification_item.dart';
import 'icon_extraction_service.dart';

class MdnsServiceEntry {
  final String name;
  final String type;
  final String ip;
  final int port;

  const MdnsServiceEntry({
    required this.name,
    required this.type,
    required this.ip,
    required this.port,
  });
}

class AdbService {
  static final AdbService _instance = AdbService._internal();
  factory AdbService() => _instance;
  AdbService._internal() {
    IconExtractionService().onIconExtracted.listen((serial) {
      if (selectedDeviceSerial == serial && installedApps.isNotEmpty) {
        final extractor = IconExtractionService();
        installedApps = installedApps.map((app) {
          final p = extractor.getCachedIconPath(app.packageName);
          return (p != null) ? app.copyWith(iconPath: p) : app;
        }).toList();
        _deviceStateController.add(true);
      }
    });
  }

  String? selectedDeviceSerial;
  bool isDemoMode = false;
  String deviceModel = 'Searching Device...';
  String deviceBrand = '';
  int batteryLevel = 0;
  bool isCharging = false;
  List<AppInfo> installedApps = [];

  // Extended DeX System States (Volume, Connectivity, Media, Notifications)
  int currentVolume = 14;
  int maxVolume = 25;
  int screenBrightness = 180;
  bool isWifiEnabled = true;
  bool isBluetoothEnabled = false;
  bool isAutoRotate = true;
  bool isDndEnabled = false;
  String currentMediaTitle = 'No Active Track';
  String currentMediaArtist = 'Android Media';
  bool isMediaPlaying = false;
  List<NotificationItem> activeNotifications = [];

  final _deviceStateController = StreamController<bool>.broadcast();
  Stream<bool> get onDeviceStateChanged => _deviceStateController.stream;

  Timer? _pollingTimer;

  void startPolling() {
    _pollDevice();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollDevice());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  bool get isConnected => selectedDeviceSerial != null;
  bool get isWired => selectedDeviceSerial != null && isWiredSerial(selectedDeviceSerial!);
  bool get isWireless => selectedDeviceSerial != null && isWirelessSerial(selectedDeviceSerial!);

  static bool isWiredSerial(String s) {
    return !s.contains(':') && !s.contains('._tcp') && !s.startsWith('adb-');
  }

  static bool isWirelessSerial(String s) {
    return s.contains(':') || s.contains('._tcp') || s.startsWith('adb-');
  }

  /// Enables simulated Demo Mode for open-source contributors without a physical Android device
  void enableDemoMode() {
    isDemoMode = true;
    selectedDeviceSerial = 'demo-device-pixel8';
    deviceModel = 'Pixel 8 Pro (Demo)';
    deviceBrand = 'Google';
    batteryLevel = 94;
    isCharging = true;
    currentVolume = 18;
    maxVolume = 25;
    isWifiEnabled = true;
    isBluetoothEnabled = true;
    currentMediaTitle = 'Open Android DeX Demo';
    currentMediaArtist = 'Workstation Sound';
    isMediaPlaying = true;
    installedApps = [
      AppInfo.fromPackage('com.android.chrome'),
      AppInfo.fromPackage('com.google.android.calculator'),
      AppInfo.fromPackage('com.android.settings'),
      AppInfo.fromPackage('com.android.documentsui'),
      AppInfo.fromPackage('com.android.messaging'),
      AppInfo.fromPackage('com.android.vending'),
      AppInfo.fromPackage('com.google.android.apps.photos'),
      AppInfo.fromPackage('com.google.android.youtube'),
      AppInfo.fromPackage('com.termux'),
    ];
    activeNotifications = [
      NotificationItem(
        id: 'demo-notif-1',
        packageName: 'com.opendex.system',
        title: 'Open Android DeX Demo Mode',
        body: 'Simulated desktop environment ready! Try dragging and resizing windows.',
        timestamp: DateTime.now(),
      ),
      NotificationItem(
        id: 'demo-notif-2',
        packageName: 'com.github.contributors',
        title: 'Contributors Welcome!',
        body: 'Check docs/GOOD_FIRST_ISSUES.md for issues you can solve today.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
    _deviceStateController.add(true);
  }

  /// Sets immersive status bar policy on Android so apps take up 100% of the window
  Future<void> enableImmersiveStatusBar([String? serial]) async {
    final s = serial ?? selectedDeviceSerial;
    if (s == null || isDemoMode) return;
    try {
      await Process.run('adb', ['-s', s, 'shell', 'settings', 'put', 'global', 'policy_control', 'immersive.status=*']);
    } catch (_) {}
  }

  /// Restores normal status bar policy on Android
  Future<void> disableImmersiveStatusBar([String? serial]) async {
    final s = serial ?? selectedDeviceSerial;
    if (s == null || isDemoMode) return;
    try {
      await Process.run('adb', ['-s', s, 'shell', 'settings', 'delete', 'global', 'policy_control']);
    } catch (_) {}
  }

  /// Detects all wired devices currently connected via USB
  Future<List<String>> getWiredDevices() async {
    final all = await getConnectedDevices();
    return all.where(isWiredSerial).toList();
  }

  /// Detects all wireless devices currently connected via Wi-Fi (IP:Port or mDNS)
  Future<List<String>> getWirelessDevices() async {
    final all = await getConnectedDevices();
    return all.where(isWirelessSerial).toList();
  }

  /// Picks the optimal device serial: prefers wired USB first, then direct IP:Port, then mDNS
  String getPreferredDevice(List<String> devices) {
    if (devices.isEmpty) return '';
    // 1. First priority: True wired USB connection
    final wired = devices.where(isWiredSerial).toList();
    if (wired.isNotEmpty) return wired.first;

    // 2. Second priority: Direct IP:port wireless connection (fastest for scrcpy)
    final ipPorts = devices.where((s) => s.contains(':') && !s.contains('._tcp')).toList();
    if (ipPorts.isNotEmpty) return ipPorts.first;

    // 3. Third priority: mDNS entry
    return devices.first;
  }

  /// Android 11+ AOSP Wireless Debugging QR code payload format
  String generateQrPairingPayload([String? password, String? serviceName]) {
    final pass = password ?? ((DateTime.now().millisecondsSinceEpoch % 900000) + 100000).toString();
    final sName = serviceName ?? 'OpenAndroidDeX';
    return 'WIFI:T:ADB;S:$sName;P:$pass;;';
  }

  /// Retrieves discovered mDNS wireless debugging services (_adb-tls-pairing and _adb-tls-connect)
  Future<List<MdnsServiceEntry>> getMdnsServices() async {
    final List<MdnsServiceEntry> entries = [];
    try {
      final res = await Process.run('adb', ['mdns', 'services']);
      final lines = (res.stdout as String).split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('List of discovered') || line.startsWith('mdns daemon')) continue;
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final hostPort = parts[2].split(':');
          if (hostPort.length == 2) {
            final port = int.tryParse(hostPort[1]) ?? 0;
            entries.add(MdnsServiceEntry(
              name: parts[0],
              type: parts[1],
              ip: hostPort[0],
              port: port,
            ));
          }
        }
      }
    } catch (_) {}
    return entries;
  }

  /// Attempts to determine the device's local Wi-Fi IP address
  Future<String?> getDeviceWifiIp([String? serial]) async {
    final target = serial ?? selectedDeviceSerial;
    if (target == null) return null;

    // 1. Try getprop dhcp.wlan0.ipaddress
    try {
      final res = await Process.run('adb', ['-s', target, 'shell', 'getprop', 'dhcp.wlan0.ipaddress']);
      final ip = (res.stdout as String).trim();
      if (_isValidIp(ip)) return ip;
    } catch (_) {}

    // 2. Try ip route
    try {
      final res = await Process.run('adb', ['-s', target, 'shell', 'ip', 'route']);
      final out = res.stdout as String;
      final match = RegExp(r'src\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(out);
      if (match != null && _isValidIp(match.group(1)!)) {
        return match.group(1);
      }
    } catch (_) {}

    // 3. Try ip -f inet addr show wlan0
    try {
      final res = await Process.run('adb', ['-s', target, 'shell', 'ip', '-f', 'inet', 'addr', 'show', 'wlan0']);
      final out = res.stdout as String;
      final match = RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(out);
      if (match != null && _isValidIp(match.group(1)!)) {
        return match.group(1);
      }
    } catch (_) {}

    return null;
  }

  bool _isValidIp(String s) {
    final parts = s.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// 1-Click convert a wired USB device into a Wireless Wi-Fi device
  Future<String> enableWirelessOverUsb([String? wiredSerial]) async {
    final serial = wiredSerial ?? selectedDeviceSerial;
    if (serial == null) return 'No USB device selected';

    final ip = await getDeviceWifiIp(serial);
    if (ip == null || ip.isEmpty) {
      return 'Could not detect device Wi-Fi IP. Ensure phone is connected to your local Wi-Fi.';
    }

    try {
      // 1. Switch adbd on phone to TCP mode on port 5555
      final tcpRes = await Process.run('adb', ['-s', serial, 'tcpip', '5555']);
      if (tcpRes.exitCode != 0) {
        return 'Failed to enable TCP mode: ${tcpRes.stderr}';
      }

      await Future.delayed(const Duration(milliseconds: 1200));

      // 2. Connect wirelessly
      final connRes = await Process.run('adb', ['connect', '$ip:5555']);
      final out = (connRes.stdout as String).trim();

      if (out.contains('connected') || out.contains('already connected')) {
        selectedDeviceSerial = '$ip:5555';
        await _pollDevice();
        return 'SUCCESS: Connected wirelessly to $ip:5555! You can now unplug the USB cable.';
      } else {
        return 'ADB connect: $out';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Connect to a device directly over Wi-Fi using IP:Port
  Future<String> connectWirelessDirect(String ip, int port) async {
    final cleanIp = ip.trim();
    if (!_isValidIp(cleanIp)) return 'Invalid IP address format';
    if (port <= 0 || port > 65535) return 'Invalid port (1-65535)';

    try {
      final res = await Process.run('adb', ['connect', '$cleanIp:$port']);
      final out = (res.stdout as String).trim();
      if (out.contains('connected') || out.contains('already connected')) {
        selectedDeviceSerial = '$cleanIp:$port';
        await _pollDevice();
        return 'SUCCESS: Connected wirelessly to $cleanIp:$port';
      }
      return out.isNotEmpty ? out : 'Failed to connect to $cleanIp:$port';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Pair wireless debugging on Android 11+ (adb pair ip:port code)
  Future<String> pairWireless(String ip, int port, String code) async {
    final cleanIp = ip.trim();
    final cleanCode = code.trim();
    try {
      final res = await Process.run('adb', ['pair', '$cleanIp:$port', cleanCode]);
      final out = '${res.stdout}\n${res.stderr}'.trim();
      return out;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> disconnectDevice(String serial) async {
    try {
      if (serial.contains(':')) {
        await Process.run('adb', ['disconnect', serial]);
      }
      if (selectedDeviceSerial == serial) {
        selectedDeviceSerial = null;
      }
      await _pollDevice();
    } catch (_) {}
  }

  Future<void> _pollDevice() async {
    if (isDemoMode) return;
    try {
      final devices = await getConnectedDevices();
      if (devices.isNotEmpty) {
        if (selectedDeviceSerial == null ||
            !devices.contains(selectedDeviceSerial) ||
            selectedDeviceSerial!.contains('._tcp')) {
          selectedDeviceSerial = getPreferredDevice(devices);
        }
        await _updateDeviceInfo();
        await _updateBattery();
        await _updateVolume();
        await _updateConnectivity();
        if (installedApps.isEmpty) {
          await fetchInstalledApps();
        }
        _deviceStateController.add(true);
      } else {
        selectedDeviceSerial = null;
        deviceModel = 'No Device Connected';
        deviceBrand = '';
        _deviceStateController.add(false);
      }
    } catch (_) {
      _deviceStateController.add(false);
    }
  }

  Future<List<String>> getConnectedDevices() async {
    if (isDemoMode) return ['demo-device-pixel8'];
    try {
      final res = await Process.run('adb', ['devices']);
      if (res.exitCode != 0) return [];

      final lines = (res.stdout as String).split('\n');
      final serials = <String>[];
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('List of devices')) continue;
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[1] == 'device') {
          serials.add(parts[0]);
        }
      }
      return serials;
    } catch (_) {
      return [];
    }
  }

  Future<void> _updateDeviceInfo() async {
    if (selectedDeviceSerial == null) return;
    try {
      final modelRes = await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'getprop', 'ro.product.model']);
      final brandRes = await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'getprop', 'ro.product.brand']);
      
      final m = (modelRes.stdout as String).trim();
      final b = (brandRes.stdout as String).trim();

      if (m.isNotEmpty) deviceModel = m;
      if (b.isNotEmpty) deviceBrand = b;
    } catch (_) {}
  }

  Future<void> _updateBattery() async {
    if (selectedDeviceSerial == null) return;
    try {
      final res = await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'dumpsys', 'battery']);
      final output = (res.stdout as String);
      for (var line in output.split('\n')) {
        line = line.trim();
        if (line.startsWith('level:')) {
          batteryLevel = int.tryParse(line.split(':')[1].trim()) ?? batteryLevel;
        } else if (line.startsWith('status:')) {
          // status 2 is charging
          final statusVal = int.tryParse(line.split(':')[1].trim()) ?? 0;
          isCharging = statusVal == 2;
        }
      }
    } catch (_) {}
  }

  Future<void> _updateVolume() async {
    if (selectedDeviceSerial == null) return;
    try {
      final res = await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'media_session', 'volume', '--stream', '3', '--get'
      ]);
      final out = res.stdout as String;
      final m = RegExp(r'volume is (\d+) in range \[(\d+)\.\.(\d+)\]').firstMatch(out);
      if (m != null) {
        currentVolume = int.tryParse(m.group(1)!) ?? currentVolume;
        maxVolume = int.tryParse(m.group(3)!) ?? maxVolume;
      }
    } catch (_) {}
  }

  Future<void> _updateConnectivity() async {
    if (selectedDeviceSerial == null) return;
    try {
      final wifiRes = await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'settings', 'get', 'global', 'wifi_on'
      ]);
      isWifiEnabled = (wifiRes.stdout as String).trim() == '1';

      final btRes = await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'settings', 'get', 'global', 'bluetooth_on'
      ]);
      isBluetoothEnabled = (btRes.stdout as String).trim() == '1';
    } catch (_) {}
  }

  Future<void> updateNotifications() async {
    if (selectedDeviceSerial == null) return;
    try {
      final res = await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'dumpsys', 'notification', '--noredact'
      ]);
      final lines = (res.stdout as String).split('\n');
      final notifs = <NotificationItem>[];
      final seenPackages = <String>{};

      for (var line in lines) {
        final m = RegExp(r'(?:StatusBarNotification|NotificationRecord)\([^:]*:\s*pkg=([^\s]+).*key=([^\s:]+)').firstMatch(line);
        if (m != null) {
          final pkg = m.group(1)!;
          final key = m.group(2)!;
          if (pkg != 'android' && pkg != 'com.android.systemui' && !seenPackages.contains(pkg)) {
            seenPackages.add(pkg);
            notifs.add(NotificationItem(
              id: key,
              packageName: pkg,
              title: '',
              body: 'Active notification from $pkg',
              timestamp: DateTime.now(),
            ));
          }
        }
      }
      if (notifs.isNotEmpty) {
        activeNotifications = notifs;
      }
    } catch (_) {}
  }

  Future<void> setVolume(int level) async {
    if (selectedDeviceSerial == null) return;
    final clamped = level.clamp(0, maxVolume);
    currentVolume = clamped;
    _deviceStateController.add(true);
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'media_session', 'volume', '--stream', '3', '--set', '$clamped'
      ]);
    } catch (_) {}
  }

  Future<void> toggleWifi() async {
    if (selectedDeviceSerial == null) return;
    final targetState = !isWifiEnabled;
    isWifiEnabled = targetState;
    _deviceStateController.add(true);
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'wifi', 'set-wifi-enabled', targetState ? 'enabled' : 'disabled'
      ]);
    } catch (_) {}
  }

  Future<void> toggleBluetooth() async {
    if (selectedDeviceSerial == null) return;
    final targetState = !isBluetoothEnabled;
    isBluetoothEnabled = targetState;
    _deviceStateController.add(true);
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'bluetooth', targetState ? 'enable' : 'disable'
      ]);
    } catch (_) {}
  }

  Future<void> mediaPlayPause() async {
    if (selectedDeviceSerial == null) return;
    isMediaPlaying = !isMediaPlaying;
    _deviceStateController.add(true);
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'media_session', 'dispatch', 'play-pause'
      ]);
    } catch (_) {}
  }

  Future<void> mediaNext() async {
    if (selectedDeviceSerial == null) return;
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'media_session', 'dispatch', 'next'
      ]);
    } catch (_) {}
  }

  Future<void> mediaPrevious() async {
    if (selectedDeviceSerial == null) return;
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'cmd', 'media_session', 'dispatch', 'previous'
      ]);
    } catch (_) {}
  }

  Future<void> lockScreen() => sendKeyEvent(26);
  Future<void> wakeUp() => sendKeyEvent(224);
  Future<void> takeScreenshot() => sendKeyEvent(120);

  Future<void> setBrightness(int val) async {
    screenBrightness = val.clamp(0, 255);
    _deviceStateController.add(true);
    if (selectedDeviceSerial == null || isDemoMode) return;
    try {
      await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'settings', 'put', 'system', 'screen_brightness', '$screenBrightness']);
    } catch (_) {}
  }

  Future<void> toggleAutoRotate() async {
    isAutoRotate = !isAutoRotate;
    _deviceStateController.add(true);
    if (selectedDeviceSerial == null || isDemoMode) return;
    try {
      await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'settings', 'put', 'system', 'accelerometer_rotation', isAutoRotate ? '1' : '0']);
    } catch (_) {}
  }

  Future<void> toggleDnd() async {
    isDndEnabled = !isDndEnabled;
    _deviceStateController.add(true);
    if (selectedDeviceSerial == null || isDemoMode) return;
    try {
      await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'cmd', 'notification', 'set_dnd_state', isDndEnabled ? 'priority' : 'off']);
    } catch (_) {}
  }

  Future<void> openSettings() async {
    if (selectedDeviceSerial == null || isDemoMode) return;
    try {
      await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'am', 'start', '-a', 'android.settings.SETTINGS']);
    } catch (_) {}
  }


  Future<List<AppInfo>> fetchInstalledApps() async {
    if (selectedDeviceSerial == null) return [];
    try {
      // Get 3rd-party packages
      final res3 = await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'pm', 'list', 'packages', '-3']);
      final packages = <String>{};

      if (res3.exitCode == 0) {
        for (var line in (res3.stdout as String).split('\n')) {
          line = line.trim();
          if (line.startsWith('package:')) {
            packages.add(line.replaceFirst('package:', '').trim());
          }
        }
      }

      // Add common built-in apps if installed
      final commonSysApps = [
        'com.google.android.calculator',
        'com.android.calculator2',
        'com.android.chrome',
        'com.google.android.youtube',
        'com.google.android.apps.photos',
        'com.google.android.gm',
        'com.google.android.apps.maps',
        'com.android.settings',
        'com.google.android.dialer',
        'com.google.android.apps.messaging',
        'com.google.android.deskclock',
        'com.android.camera',
        'com.android.camera2',
      ];

      for (var sys in commonSysApps) {
        final check = await Process.run('adb', ['-s', selectedDeviceSerial!, 'shell', 'pm', 'path', sys]);
        if (check.exitCode == 0 && (check.stdout as String).trim().isNotEmpty) {
          packages.add(sys);
        }
      }

      final extractor = IconExtractionService();
      final apps = packages.map((pkg) {
        final cached = extractor.getCachedIconPath(pkg);
        return AppInfo.fromPackage(pkg, cached);
      }).toList();
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      installedApps = apps;

      // Extract real icons asynchronously in the background
      extractor.extractIconsForDevice(selectedDeviceSerial!, packages.toList());

      return apps;
    } catch (_) {
      return [];
    }
  }

  Future<void> launchAppOnDevice(String packageName) async {
    if (selectedDeviceSerial == null) {
      final devices = await getConnectedDevices();
      if (devices.isNotEmpty) {
        selectedDeviceSerial = devices.first;
      } else {
        return;
      }
    }
    try {
      await Process.run('adb', [
        '-s', selectedDeviceSerial!,
        'shell', 'monkey',
        '-p', packageName,
        '-c', 'android.intent.category.LAUNCHER', '1'
      ]);
    } catch (_) {}
  }

  Future<void> sendKeyEvent(int keyCode, {int? displayId}) async {
    if (selectedDeviceSerial == null) return;
    try {
      final args = ['-s', selectedDeviceSerial!, 'shell', 'input'];
      if (displayId != null) {
        args.addAll(['-d', displayId.toString()]);
      }
      args.addAll(['keyevent', '$keyCode']);
      await Process.run('adb', args);
    } catch (_) {}
  }

  Future<void> goBack({int? displayId}) => sendKeyEvent(4, displayId: displayId);
  Future<void> goHome({int? displayId}) => sendKeyEvent(3, displayId: displayId);
  Future<void> showRecents({int? displayId}) => sendKeyEvent(187, displayId: displayId);
  Future<void> volumeUp({int? displayId}) => sendKeyEvent(24, displayId: displayId);
  Future<void> volumeDown({int? displayId}) => sendKeyEvent(25, displayId: displayId);
  Future<void> powerButton({int? displayId}) => sendKeyEvent(26, displayId: displayId);
}
