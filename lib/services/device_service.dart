import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';

/// Service for managing ESP8266 device pairing via the FastAPI backend.
/// All device data is stored in MongoDB (no Firebase RTDB).
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  String get _baseUrl => AppConstants.defaultApiBase;

  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('DeviceService: Failed to get Firebase token: $e');
    }
    return headers;
  }

  /// Generate a new device token for pairing.
  /// Returns {device_token, patient_id, device_name} on success.
  Future<Map<String, dynamic>?> pairDevice(String patientId, {String deviceName = 'VitalSync Band'}) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'patient_id': patientId,
        'device_name': deviceName,
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/devices/pair'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('DeviceService: pair failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('DeviceService: pair exception: $e');
      return null;
    }
  }

  /// Get list of paired devices for a patient.
  Future<List<Map<String, dynamic>>> getDevices(String patientId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/devices/$patientId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['devices'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('DeviceService: getDevices failed: $e');
      return [];
    }
  }

  /// Unpair a device by its token.
  Future<bool> unpairDevice(String deviceToken) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/v1/devices/$deviceToken'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('DeviceService: unpair failed: $e');
      return false;
    }
  }

  /// Send config directly to ESP8266 over SoftAP.
  /// The ESP is at 192.168.4.1 when in setup mode.
  Future<bool> sendConfigToEsp({
    required String ssid,
    required String password,
    required String apiUrl,
    required String patientId,
    required String deviceToken,
    String espIp = '192.168.4.1',
  }) async {
    try {
      final body = jsonEncode({
        'ssid': ssid,
        'pass': password,
        'url': apiUrl,
        'pid': patientId,
        'token': deviceToken,
      });

      final response = await http
          .post(
            Uri.parse('http://$espIp/api/setup'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('DeviceService: sendConfigToEsp failed: $e');
      return false;
    }
  }
}
