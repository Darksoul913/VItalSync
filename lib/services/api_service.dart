import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';

/// Centralized HTTP client for all FastAPI backend communication.
/// All vitals history, analytics, and alerts flow through here → MongoDB.
/// Automatically attaches Firebase ID token for RBAC + audit logging.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get _baseUrl => AppConstants.defaultApiBase;

  // ─── Headers (with Firebase Auth token) ────────────────
  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Attach Firebase ID token if user is authenticated
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('ApiService: Failed to get Firebase token: $e');
    }

    return headers;
  }

  // ─── Health Check ──────────────────────────────────────
  Future<bool> isBackendHealthy() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/health'), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      debugPrint('ApiService: health check failed: $e');
      return false;
    }
  }

  // ─── Vitals — Store ────────────────────────────────────
  /// Send a vital reading to FastAPI → MongoDB
  Future<Map<String, dynamic>?> storeVitalReading({
    required String patientId,
    required double heartRate,
    required double spo2,
    required double temperature,
    required double bpSystolic,
    required double bpDiastolic,
    List<double> ecgSamples = const [],
    bool fallDetected = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'patient_id': patientId,
        'heart_rate': heartRate,
        'spo2': spo2,
        'temperature': temperature,
        'bp_systolic': bpSystolic,
        'bp_diastolic': bpDiastolic,
        'ecg_samples': ecgSamples,
        'fall_detected': fallDetected,
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/vitals'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      debugPrint('ApiService: storeVital failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ApiService: storeVital exception: $e');
      return null;
    }
  }

  // ─── Vitals — Read ─────────────────────────────────────
  /// Get latest vitals from MongoDB
  Future<Map<String, dynamic>?> getLatestVitals(String patientId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/vitals/$patientId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getLatestVitals failed: $e');
      return null;
    }
  }

  /// Get vitals history from MongoDB
  Future<Map<String, dynamic>?> getVitalsHistory(
    String patientId, {
    int limit = 100,
    int hours = 24,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/v1/vitals/$patientId/history?limit=$limit&hours=$hours',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getVitalsHistory failed: $e');
      return null;
    }
  }

  // ─── Analytics ─────────────────────────────────────────
  /// Get analytics (avg/min/max/trend) from MongoDB aggregation
  Future<Map<String, dynamic>?> getAnalytics(
    String patientId,
    String vitalType, {
    int periodHours = 24,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'patient_id': patientId,
        'vital_type': vitalType,
        'period_hours': periodHours,
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/analytics'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getAnalytics failed: $e');
      return null;
    }
  }

  /// Get daily summary from MongoDB (cached or generated)
  Future<Map<String, dynamic>?> getDailySummary(
    String patientId, {
    String? date,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$_baseUrl/api/v1/analytics/$patientId/summary';
      if (date != null) url += '?date=$date';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getDailySummary failed: $e');
      return null;
    }
  }

  // ─── Alerts ────────────────────────────────────────────
  /// Get patient alerts from MongoDB
  Future<Map<String, dynamic>?> getAlerts(
    String patientId, {
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/alerts/$patientId?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getAlerts failed: $e');
      return null;
    }
  }

  /// Acknowledge an alert
  Future<bool> acknowledgeAlert(String alertId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/alerts/acknowledge/$alertId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService: acknowledgeAlert failed: $e');
      return false;
    }
  }

  // ─── Audit Log ─────────────────────────────────────────
  /// Get audit trail for a patient (who accessed their data)
  Future<Map<String, dynamic>?> getAuditLog(
    String patientId, {
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/audit/$patientId?limit=$limit'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getAuditLog failed: $e');
      return null;
    }
  }

  // ─── Time Series (for charts) ──────────────────────────
  /// Get time-bucketed data points for chart plotting from MongoDB
  Future<Map<String, dynamic>?> getTimeSeries(
    String patientId,
    String vitalType, {
    int hours = 24,
    int intervalMinutes = 5,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/v1/vitals/$patientId/timeseries'
              '?vital_type=$vitalType&hours=$hours&interval_minutes=$intervalMinutes',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getTimeSeries failed: $e');
      return null;
    }
  }

  // ─── Database Stats ────────────────────────────────────
  /// Get MongoDB stats
  Future<Map<String, dynamic>?> getDatabaseStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/stats'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: getDatabaseStats failed: $e');
      return null;
    }
  }
}
