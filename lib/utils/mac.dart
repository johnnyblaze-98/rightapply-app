// COPILOT TODO (utils/mac.dart):
// - Implement helpers to fetch and normalize a primary MAC/ID:
//   * Desktop: run system commands (Windows `getmac`; macOS `networksetup`/`ifconfig`; Linux `/sys/class/net/*/address`).
//   * Mobile: return a stable fallback (ANDROID_ID / identifierForVendor).
// - Provide: Future<String> getPrimaryMacOrId(), String normMac(String s), String maskId(String s)
// - Handle errors gracefully; return "unknown" if not found.

import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';

Future<String> getPrimaryMacOrId() async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run('getmac', ['/fo', 'csv', '/nh']);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout.toString()).toList();
        for (final line in lines) {
          final parts = line.split(',');
          if (parts.isNotEmpty) {
            final mac = parts[0].replaceAll('"', '');
            if (mac.length >= 11 && !mac.contains('00-00-00-00-00-00')) {
              return normMac(mac);
            }
          }
        }
      }
    } else if (Platform.isMacOS) {
      final result = await Process.run('networksetup', ['-listallhardwareports']);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout.toString()).toList();
        String? mac;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('Ethernet Address:')) {
            mac = lines[i].split(':').last.trim();
            break;
          }
        }
        if (mac != null && mac.isNotEmpty) return normMac(mac);
      }
      // fallback
      final fallback = await Process.run('ifconfig', ['en0']);
      final match = RegExp(r'ether ([0-9a-f:]{17})').firstMatch(fallback.stdout.toString());
      if (match != null) return normMac(match.group(1)!);
    } else if (Platform.isLinux) {
      final result = await Process.run('cat', ['/sys/class/net/*/address']);
      if (result.exitCode == 0) {
        final mac = LineSplitter.split(result.stdout.toString()).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
        if (mac.isNotEmpty) return normMac(mac);
      }
    } else if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.id;
    } else if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      return info.identifierForVendor ?? 'unknown';
    }
  } catch (_) {}
  return 'unknown';
}

String normMac(String s) {
  final cleaned = s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (cleaned.length != 12) return s;
  return List.generate(6, (i) => cleaned.substring(i * 2, i * 2 + 2).toLowerCase()).join(':');
}

String maskId(String s) {
  if (s.length <= 4) return '*' * s.length;
  return '*' * (s.length - 4) + s.substring(s.length - 4);
}
