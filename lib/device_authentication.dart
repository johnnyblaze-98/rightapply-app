import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:ui';
// import 'admin_page.dart';
import 'services/api.dart';
import 'utils/mac.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';


// Single correct implementation below

class DeviceAuthenticationPage extends StatefulWidget {
  final bool testMode;
  const DeviceAuthenticationPage({super.key, this.testMode = false});
  @override
  State<DeviceAuthenticationPage> createState() => _DeviceAuthenticationPageState();
}

class _DeviceAuthenticationPageState extends State<DeviceAuthenticationPage> {
  final String requesterEmail = '<YOUR-EMAIL@EXAMPLE.COM>'; // <-- Set this for registration

  String deviceId = '';
  String deviceModel = 'Fetching...';
  String osVersion = 'Fetching...';
  String platform = 'Fetching...';
  String status = 'Unknown';
  bool isAuthenticated = false;
  bool isLoading = true;
  bool hasRegistered = false;
  String appVersion = '';
  String role = 'user';
  String requestId = '';

  @override
  void initState() {
    super.initState();
    if (!(widget.testMode)) {
      _bootstrap();
    } else {
      // Set fake device info for test
      deviceId = 'test-device-id';
      deviceModel = 'Test Model';
      osVersion = 'Test OS';
      platform = 'TestPlatform';
      status = 'pending';
      isAuthenticated = false;
      isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.devices, color: Color(0xFF1565C0), size: 32),
            const SizedBox(width: 10),
            Text('Device Management', style: TextStyle(color: Color(0xFF222B45), fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.2)),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            color: Color(0xFFF5F7FA),
            child: Stack(
              children: [
                // Subtle geometric design: large faded circles
                Positioned(
                  top: -60,
                  left: -60,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1565C0).withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  right: -40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF5E92F3).withOpacity(0.10),
                    ),
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -50,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF90A4AE).withOpacity(0.09),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Glassmorphism card
          Center(
            child: SingleChildScrollView(
              child: AnimatedOpacity(
                opacity: isLoading ? 0.5 : 1.0,
                duration: Duration(milliseconds: 600),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.08),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: isLoading
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: 30),
                                CircularProgressIndicator(color: Colors.deepPurple),
                                SizedBox(height: 30),
                                Text('Fetching device info...', style: TextStyle(fontSize: 18, color: Colors.deepPurple)),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  isAuthenticated ? Icons.verified : Icons.error_outline,
                                  color: isAuthenticated ? Colors.green : Colors.red,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  isAuthenticated ? 'Device Authenticated' : 'Pending Approval',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isAuthenticated ? Colors.green : (status.contains('Error') ? Colors.red : Colors.orange),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 18),
                                _buildDeviceInfoCard(),
                                SizedBox(height: 28),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        elevation: 0,
                                      ),
                                      onPressed: isLoading ? null : _bootstrap,
                                      icon: Icon(Icons.refresh, color: Colors.white),
                                      label: Text('Refresh Status', style: TextStyle(fontSize: 16, color: Colors.white)),
                                    ),
                                  ],
                                ),
                                if (!isAuthenticated && status == 'pending' && kApiBase.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueGrey,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        elevation: 0,
                                      ),
                                      onPressed: isLoading || hasRegistered ? null : _requestAccess,
                                      icon: Icon(Icons.vpn_key, color: Colors.white),
                                      label: Text(hasRegistered ? 'Request Sent' : 'Request Access', style: TextStyle(fontSize: 16, color: Colors.white)),
                                    ),
                                  ),
                                if (!isAuthenticated && status == 'pending')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Column(
                                      children: [
                                        Text('Scan to approve this device', style: TextStyle(fontSize: 14, color: Colors.deepPurple)),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4)),
                                            ],
                                          ),
                                          child: QrImageView(
                                            data: _qrPayload(),
                                            version: QrVersions.auto,
                                            size: 180,
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SelectableText('Device ID: ' + deviceId, style: TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                if (!isAuthenticated && status == 'pending' && kApiBase.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Text(
                                      'Pending approval (no backend configured)',
                                      style: TextStyle(color: Colors.orange, fontSize: 15),
                                    ),
                                  ),
                                if (status.contains('Error'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: Colors.red, fontSize: 15),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() { isLoading = true; });
    try {
      // Try to load app version
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
      } catch (_) {}

      final macOrId = await getPrimaryMacOrId();
      String model = 'Unknown', os = 'Unknown', plat = 'Unknown';
      // Store device MAC/ID for downstream API calls (login, name lookup)
      try {
        ApiService.setDeviceMac(macOrId);
      } catch (_) {}
      if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        model = android.model;
        os = android.version.release;
        plat = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        model = iosInfo.utsname.machine;
        os = iosInfo.systemVersion;
        plat = 'iOS';
      } else if (Platform.isWindows) {
        final win = await DeviceInfoPlugin().windowsInfo;
        model = win.computerName;
        os = "${win.majorVersion}.${win.minorVersion} (Build ${win.buildNumber})";
        plat = 'Windows';
      } else if (Platform.isMacOS) {
        final mac = await DeviceInfoPlugin().macOsInfo;
        model = mac.model;
        os = "${mac.osRelease} (${mac.kernelVersion})";
        plat = 'macOS';
      } else if (Platform.isLinux) {
        final linux = await DeviceInfoPlugin().linuxInfo;
  model = linux.prettyName;
        os = linux.version ?? '';
        plat = 'Linux';
      }
      if (!mounted) return;
      setState(() {
        deviceId = macOrId;
        deviceModel = model;
        osVersion = os;
        platform = plat;
      });

      // If backend is not configured, skip API calls but keep device info
      if (kApiBase.isEmpty) {
        setState(() {
          isAuthenticated = false;
          status = 'pending';
          isLoading = false;
        });
        return;
      }

      final statusResp = await ApiService.getStatus(deviceId);
      if (!mounted) return;
      if (statusResp['approved'] == true) {
        setState(() {
          isAuthenticated = true;
          status = statusResp['status'] ?? 'approved';
          isLoading = false;
        });
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        });
        return;
      } else {
        setState(() {
          isAuthenticated = false;
          status = statusResp['status'] ?? 'pending';
        });
        // Do not auto-register; user can press Request Access
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = 'Error: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() { isLoading = false; });
    }
  }
  // ...existing code...

  Future<void> _requestAccess() async {
    setState(() { isLoading = true; });
    try {
      final resp = await ApiService.registerDevice(
        mac: deviceId,
        requesterEmail: requesterEmail,
        platform: platform,
        model: deviceModel,
        osVersion: osVersion,
        role: role,
        appVersion: appVersion,
      );
      if (!mounted) return;
      setState(() {
        hasRegistered = true;
        status = (resp['status'] ?? 'pending').toString();
        requestId = (resp['id'] ?? '').toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access request submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() { isLoading = false; });
    }
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.07),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_other, color: Colors.deepPurple, size: 22),
              SizedBox(width: 8),
              Text('Platform:', style: _infoLabelStyle()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2, bottom: 8),
            child: SelectableText(platform, style: _infoValueStyle()),
          ),
          Row(
            children: [
              Icon(Icons.devices, color: Colors.deepPurple, size: 22),
              SizedBox(width: 8),
              Text('Device Model:', style: _infoLabelStyle()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2, bottom: 8),
            child: SelectableText(deviceModel, style: _infoValueStyle()),
          ),
          Row(
            children: [
              Icon(Icons.system_update_alt, color: Colors.deepPurple, size: 22),
              SizedBox(width: 8),
              Text('OS Version:', style: _infoLabelStyle()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2, bottom: 8),
            child: SelectableText(osVersion, style: _infoValueStyle()),
          ),
          Row(
            children: [
              Icon(Icons.confirmation_number, color: Colors.deepPurple, size: 22),
              SizedBox(width: 8),
              Text('Device ID:', style: _infoLabelStyle()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2, bottom: 8),
            child: SelectableText(deviceId, style: _infoValueStyle()),
          ),
          Row(
            children: [
              Icon(Icons.verified, color: isAuthenticated ? Colors.green : Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Status:', style: _infoLabelStyle()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2),
            child: SelectableText(
              status,
              style: _infoValueStyle().copyWith(fontWeight: FontWeight.bold, color: isAuthenticated ? Colors.green : (status.contains('Error') ? Colors.red : Colors.orange)),
            ),
          ),
        ],
      ),
    );
  }

  // Use maskId from utils/mac.dart for masking

  TextStyle _infoLabelStyle() {
    return const TextStyle(fontSize: 15, color: Colors.deepPurple, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  }

  TextStyle _infoValueStyle() {
    return const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500);
  }

  // Compose QR payload for admins to scan.
  String _qrPayload() {
    String safe(String s) => s.replaceAll('\n', ' ').replaceAll('|', ' ');
    final map = <String, String>{
      'mac': deviceId,
      if (requestId.isNotEmpty) 'id': requestId,
      'platform': platform,
      'model': deviceModel,
      'os': osVersion,
      'app': appVersion,
      if (kApiBase.isNotEmpty) 'api': kApiBase,
      'status': status,
      'ts': DateTime.now().toIso8601String(),
    };
    return map.entries.map((e) => '${e.key}=${safe(e.value)}').join('|');
  }
}
