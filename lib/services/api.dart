// COPILOT TODO (services/api.dart):
// - Implement ApiService with static methods and a single const API base:
//     const String kApiBase = 'https://<YOUR-CLOUD-RUN-URL>';
//   Methods:
//     Future<Map<String,dynamic>> getStatus(String deviceId)
//     Future<Map<String,dynamic>> registerDevice({ required String mac, required String requesterEmail, required String platform, String model='', String osVersion='', String reason='New device registration' })
//     Future<List<Map<String,dynamic>>> listPending()
//     Future<bool> decide({ required String requestId, required bool approve, required String decidedBy })
// - Use package:http, JSON encode/decode, and basic error handling.
// - If kApiBase is empty, return safe defaults (approved=false, status='pending') and no-ops for decide/register.

import 'dart:convert';
import 'package:http/http.dart' as http;

// API base URL: override at build time with
//   --dart-define=API_BASE=https://<api-id>.execute-api.<region>.amazonaws.com/Prod
// Falls back to local Express server if not provided.
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:5174',
);

class ApiService {
  static String? _token;
  static String? _deviceMac;

  static void setAuthToken(String? token) {
    _token = token;
  }

  static void setDeviceMac(String mac) {
    _deviceMac = mac;
  }

  static Map<String, String> _headers({bool auth = false}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  static Future<Map<String, dynamic>> getStatus(String deviceId) async {
    if (kApiBase.isEmpty) {
      return {'approved': false, 'status': 'pending'};
    }
    try {
      final res = await http.get(Uri.parse('$kApiBase/device/status/$deviceId'));
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'approved': false, 'status': 'pending'};
  }

  static Future<Map<String, dynamic>> registerDevice({
    required String mac,
    required String requesterEmail,
    required String platform,
    String model = '',
    String osVersion = '',
    String reason = 'New device registration',
    String role = 'user',
    String appVersion = '',
  }) async {
    if (kApiBase.isEmpty) {
      return {'status': 'pending'};
    }
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/device/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mac': mac,
          'requesterEmail': requesterEmail,
          'platform': platform,
          'model': model,
          'osVersion': osVersion,
          'reason': reason,
          'role': role,
          'appVersion': appVersion,
        }),
      );
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'status': 'pending'};
  }

  static Future<List<Map<String, dynamic>>> listPending() async {
    if (kApiBase.isEmpty) {
      return [];
    }
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/device/pending'),
        headers: _headers(auth: true),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> decide({
    required String requestId,
    required bool approve,
    required String decidedBy,
  }) async {
    if (kApiBase.isEmpty) {
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/device/decide'),
        headers: _headers(auth: true),
        body: json.encode({
          'requestId': requestId,
          'approve': approve,
          'decidedBy': decidedBy,
        }),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> authRegister({
    required String username,
    required String password,
    required String name,
  }) async {
    if (kApiBase.isEmpty) return {'success': true, 'user': {'username': username, 'name': name}};
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password, 'name': name}),
      );
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> authLogin({
    required String username,
    required String password,
  }) async {
    if (kApiBase.isEmpty) return {'success': true, 'user': {'username': username}};
    try {
      final body = <String, dynamic>{'username': username, 'password': password};
      if (_deviceMac != null && _deviceMac!.isNotEmpty) {
        body['mac'] = _deviceMac;
      }
      final res = await http.post(
        Uri.parse('$kApiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['success'] == true && data['token'] is String) {
        setAuthToken(data['token'] as String);
      }
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Optional helper: look up a user's display name by username.
  // If the backend doesn't support it, return null gracefully.
  static Future<String?> lookupDisplayName(String username) async {
    if (kApiBase.isEmpty) return null;
    try {
      final uri = Uri.parse('$kApiBase/auth/user/$username').replace(queryParameters: {
        if (_deviceMac != null && _deviceMac!.isNotEmpty) 'mac': _deviceMac!,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['user'] is Map) {
          final u = data['user'] as Map;
          final name = u['name'];
          if (name is String && name.trim().isNotEmpty) return name.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  // Rich lookup for login header/status chips.
  static Future<Map<String, dynamic>> lookupUserInfo(String username) async {
    final result = <String, dynamic>{'name': null, 'allowed': null, 'bound': null};
    if (kApiBase.isEmpty) return result;
    try {
      final uri = Uri.parse('$kApiBase/auth/user/$username').replace(queryParameters: {
        if (_deviceMac != null && _deviceMac!.isNotEmpty) 'mac': _deviceMac!,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map) {
          if (data['user'] is Map) {
            final u = data['user'] as Map;
            final name = u['name'];
            if (name is String && name.trim().isNotEmpty) result['name'] = name.trim();
          }
          if (data.containsKey('allowed')) result['allowed'] = data['allowed'];
          if (data.containsKey('bound')) result['bound'] = data['bound'];
        }
      }
    } catch (_) {}
    return result;
  }

  static Future<List<Map<String, dynamic>>> listUsers() async {
    if (kApiBase.isEmpty) return [];
    try {
      final res = await http.get(Uri.parse('$kApiBase/auth/users'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['users'] is List) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> lookupUserByMac() async {
    if (kApiBase.isEmpty || _deviceMac == null || _deviceMac!.isEmpty) return null;
    try {
      final uri = Uri.parse('$kApiBase/auth/linked').replace(queryParameters: { 'mac': _deviceMac! });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['user'] is Map) {
          return Map<String, dynamic>.from(data);
        }
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return null;
  }
}
