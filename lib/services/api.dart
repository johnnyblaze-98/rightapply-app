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

// For local proxy API (Vite/Express), set to http://localhost:5173
// Leave empty to run fully offline with no API calls
const String kApiBase = 'http://localhost:5173';

class ApiService {
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
      final res = await http.get(Uri.parse('$kApiBase/device/pending'));
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
        headers: {'Content-Type': 'application/json'},
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
}
