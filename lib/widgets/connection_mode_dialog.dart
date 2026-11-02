import 'dart:async';
import 'package:flutter/material.dart';
import '../services/adb_service.dart';
import 'qr_code_widget.dart';

class ConnectionModeDialog extends StatefulWidget {
  final VoidCallback? onConnected;

  const ConnectionModeDialog({super.key, this.onConnected});

  static Future<void> show(BuildContext context, {VoidCallback? onConnected}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConnectionModeDialog(onConnected: onConnected),
    );
  }

  @override
  State<ConnectionModeDialog> createState() => _ConnectionModeDialogState();
}

class _ConnectionModeDialogState extends State<ConnectionModeDialog> with SingleTickerProviderStateMixin {
  final _adb = AdbService();

  final _ipController = TextEditingController(text: '192.168.1.');
  final _portController = TextEditingController(text: '5555');
  final _pairPortController = TextEditingController();
  final _pairCodeController = TextEditingController();

  late TabController _tabController;
  Timer? _detectTimer;

  late String _qrPayload;
  late String _pairingPassword;

  bool _isConnecting = false;
  bool _isSwitchingToWireless = false;
  bool _showPairing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  List<String> _wiredDevices = [];
  List<String> _wirelessDevices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pairingPassword = 'dex${(DateTime.now().millisecondsSinceEpoch % 900000) + 100000}';
    _qrPayload = _adb.generateQrPairingPayload(_pairingPassword);
    _refreshDevices();
    _detectTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshDevices());
  }

  void _regenerateQr() {
    setState(() {
      _pairingPassword = 'dex${(DateTime.now().millisecondsSinceEpoch % 900000) + 100000}';
      _qrPayload = _adb.generateQrPairingPayload(_pairingPassword);
    });
  }

  @override
  void dispose() {
    _detectTimer?.cancel();
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    final wired = await _adb.getWiredDevices();
    final wireless = await _adb.getWirelessDevices();

    if (mounted) {
      setState(() {
        _wiredDevices = wired;
        _wirelessDevices = wireless;
      });

      // Auto fill IP from detected wireless device if present
      if (wireless.isNotEmpty && _ipController.text == '192.168.1.') {
        final pref = _adb.getPreferredDevice(wireless);
        if (pref.contains(':') && !pref.contains('._tcp')) {
          final parts = pref.split(':');
          if (parts.length == 2) {
            _ipController.text = parts[0];
            _portController.text = parts[1];
          }
        }
      }

      // Try pre-filling IP from connected wired device if available and input is incomplete
      if (wired.isNotEmpty && _ipController.text == '192.168.1.') {
        _adb.getDeviceWifiIp(wired.first).then((detectedIp) {
          if (detectedIp != null && detectedIp.isNotEmpty && mounted) {
            setState(() {
              _ipController.text = detectedIp;
            });
          }
        });
      }
    }
  }

  Future<void> _handleWiredSelect(String serial) async {
    _adb.selectedDeviceSerial = serial;
    Navigator.of(context).pop();
    widget.onConnected?.call();
  }

  Future<void> _handle1ClickWireless() async {
    if (_wiredDevices.isEmpty) return;

    setState(() {
      _isSwitchingToWireless = true;
      _statusMessage = 'Configuring Wi-Fi debugging on phone...';
      _statusIsError = false;
    });

    final res = await _adb.enableWirelessOverUsb(_wiredDevices.first);

    if (mounted) {
      setState(() {
        _isSwitchingToWireless = false;
        _statusMessage = res;
        _statusIsError = !res.startsWith('SUCCESS');
      });

      if (res.startsWith('SUCCESS')) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onConnected?.call();
        }
      }
    }
  }

  Future<void> _handleDirectConnect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 5555;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to $ip:$port...';
      _statusIsError = false;
    });

    final res = await _adb.connectWirelessDirect(ip, port);

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _statusMessage = res;
        _statusIsError = !res.startsWith('SUCCESS');
      });

      if (res.startsWith('SUCCESS')) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onConnected?.call();
        }
      }
    }
  }

  Future<void> _handlePair() async {
    final ip = _ipController.text.trim();
    final pairPort = int.tryParse(_pairPortController.text.trim());
    final code = _pairCodeController.text.trim();

    if (pairPort == null) {
      setState(() {
        _statusMessage = 'Please enter a valid pairing port';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Pairing with $ip:$pairPort...';
      _statusIsError = false;
    });

    final pairRes = await _adb.pairWireless(ip, pairPort, code);

    if (pairRes.toLowerCase().contains('success')) {
      // After pairing, connect to main wireless port
      final mainPort = int.tryParse(_portController.text.trim()) ?? 5555;
      final connRes = await _adb.connectWirelessDirect(ip, mainPort);
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = connRes;
          _statusIsError = !connRes.startsWith('SUCCESS');
        });
        if (connRes.startsWith('SUCCESS')) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.of(context).pop();
            widget.onConnected?.call();
          }
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = pairRes.isNotEmpty ? pairRes : 'Pairing failed';
          _statusIsError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasWired = _wiredDevices.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 660,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF334155), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.settings_input_antenna_rounded, size: 20, color: Color(0xFF60A5FA)),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Connection Mode',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Connect via USB Cable or Wireless Wi-Fi Debugging',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Live Cable Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasWired ? const Color(0xFF064E3B) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasWired ? const Color(0xFF10B981) : const Color(0xFF475569),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasWired ? Icons.cable_rounded : Icons.usb_off_rounded,
                          size: 13,
                          color: hasWired ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasWired ? 'USB Cable Detected' : 'No Cable Detected',
                          style: TextStyle(
                            color: hasWired ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),

            // Tab Buttons
            Container(
              color: const Color(0xFF0B1120),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                tabs: [
                  Tab(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.usb_rounded, size: 17),
                        const SizedBox(width: 8),
                        const Text('Wired (USB)'),
                        if (hasWired) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 17),
                        const SizedBox(width: 8),
                        const Text('Wireless (QR / Wi-Fi)'),
                        if (_wirelessDevices.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            SizedBox(
              height: 480,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWiredTab(),
                  _buildWirelessTab(),
                ],
              ),
            ),

            // Status message footer (if any)
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _statusIsError ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B),
                child: Row(
                  children: [
                    Icon(
                      _statusIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWiredTab() {
    final hasWired = _wiredDevices.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasWired) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF059669)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF059669).withOpacity(0.3),
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 28, color: Color(0xFF34D399)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adb.deviceModel.isNotEmpty ? _adb.deviceModel : 'Android Device',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'USB Serial: ${_wiredDevices.first} • Ready for 60 FPS DeX',
                          style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Button 1: Connect Wired
            ElevatedButton.icon(
              onPressed: () => _handleWiredSelect(_wiredDevices.first),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start Open Android DeX (Wired USB)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Action Button 2: Switch to Wireless (1-Click)
            OutlinedButton.icon(
              onPressed: _isSwitchingToWireless ? null : _handle1ClickWireless,
              icon: _isSwitchingToWireless
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.wifi_tethering_rounded, size: 16, color: Color(0xFFFBBF24)),
              label: Text(
                _isSwitchingToWireless ? 'Configuring Wireless...' : '⚡ Switch to Wireless Mode (Unplug Cable After)',
                style: const TextStyle(color: Color(0xFFFDE68A)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD97706)),
                backgroundColor: const Color(0xFF78350F).withOpacity(0.2),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF38BDF8)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for USB cable to be plugged in...',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. Connect your phone via USB cable.\n2. Ensure "USB Debugging" is enabled in Developer Options.\n3. The app will automatically detect it instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Switch to Wireless (Wi-Fi) Debugging instead'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF60A5FA)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWirelessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Detected / Active Wireless Device Banner
          if (_wirelessDevices.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF065F46).withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_rounded, size: 20, color: Color(0xFF34D399)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adb.deviceModel.isNotEmpty ? _adb.deviceModel : 'Wireless Android Device',
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Wi-Fi Serial: ${_adb.getPreferredDevice(_wirelessDevices)} • Ready to Launch',
                          style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _handleWiredSelect(_adb.getPreferredDevice(_wirelessDevices)),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 15),
                    label: const Text('Start DeX'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Primary Method: QR Code Pairing Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Pure-Dart QR Code Widget
                Column(
                  children: [
                    QrCodeWidget(
                      data: _qrPayload,
                      size: 150,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0B1120),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _regenerateQr,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF60A5FA)),
                            SizedBox(width: 4),
                            Text('New Code', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Right: Step-by-Step Instructions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          const Text(
                            'Pair with QR Code',
                            style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0369A1).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5)),
                            ),
                            child: const Text('Android 11-16', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 9.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStep(1, 'Open Settings > Developer options > Wireless debugging'),
                      const SizedBox(height: 4),
                      _buildStep(2, 'Turn on Wireless debugging & tap "Pair device with QR code"'),
                      const SizedBox(height: 4),
                      _buildStep(3, 'Scan this QR code with your phone camera'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          'Passcode: $_pairingPassword • Service: OpenAndroidDeX',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Alternative Method: Manual IP/Port & 6-digit Code
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Phone Wi-Fi IP',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    hintText: 'e.g. 192.168.1.42',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _portController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Port',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    hintText: '5555',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isConnecting ? null : _handleDirectConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(_isConnecting ? '...' : 'Connect IP'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Android 11+ 6-digit pairing toggle
          InkWell(
            onTap: () => setState(() => _showPairing = !_showPairing),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showPairing ? '▲ Hide 6-digit code pairing' : '▼ Pair with 6-digit code manually',
                    style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          if (_showPairing) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pairPortController,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Pairing Port (e.g. 39215)',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _pairCodeController,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '6-digit code',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isConnecting ? null : _handlePair,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Pair', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 15,
          height: 15,
          margin: const EdgeInsets.only(top: 1, right: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
          ),
          child: Text(
            '$number',
            style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
          ),
        ),
      ],
    );
  }
}

