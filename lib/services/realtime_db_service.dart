import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vital_reading.dart';
import '../config/constants.dart';

/// Live vitals service — polls MongoDB via FastAPI.
/// Firebase is used for Auth only; RTDB is not used.
///
/// Drop-in replacement for the old Firebase RTDB service:
/// same [streamPatientVitals] signature, same [VitalReading?] output.
class RealtimeDbService {
  final String _baseUrl = AppConstants.defaultApiBase;

  // How often to poll MongoDB for latest reading
  static const Duration _pollInterval = Duration(seconds: 2);

  // ─── Auth Header ──────────────────────────────────────────
  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('RealtimeDbService: failed to get token: $e');
    }
    return headers;
  }

  // ─── Live Polling Stream ──────────────────────────────────
  /// Polls GET /api/v1/vitals/{patientId} every [_pollInterval].
  /// Emits a [VitalReading] on each successful response.
  /// Emits null if the endpoint returns no data or errors (keeps
  /// vitals_provider's staleness logic working unchanged).
  Stream<VitalReading?> streamPatientVitals(String patientId) async* {
    while (true) {
      yield await _fetchLatest(patientId);
      await Future.delayed(_pollInterval);
    }
  }

  // ─── Fetch Latest Reading ─────────────────────────────────
  Future<VitalReading?> _fetchLatest(String patientId) async {
    try {
      final headers = await _headers();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/vitals/$patientId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseReading(data);
    } catch (e) {
      debugPrint('RealtimeDbService: poll failed: $e');
      return null;
    }
  }

  // ─── Parse FastAPI VitalReading → Flutter VitalReading ────
  VitalReading? _parseReading(Map<String, dynamic> data) {
    try {
      // FastAPI field names → Flutter model
      final hr   = (data['heart_rate']    as num?)?.toDouble() ?? 0.0;
      final spo2 = (data['spo2']          as num?)?.toDouble() ?? 0.0;
      final temp = (data['temperature']   as num?)?.toDouble() ?? 0.0;
      final sys  = (data['bp_systolic']   as num?)?.toDouble() ?? 0.0;
      final dia  = (data['bp_diastolic']  as num?)?.toDouble() ?? 0.0;
      final fall = data['fall_detected']  as bool? ?? false;

      // ECG samples — stored as List<num> in MongoDB
      List<double> ecgSamples = [];
      if (data['ecg_samples'] is List) {
        ecgSamples = (data['ecg_samples'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
      }

      // Timestamp — ISO string from MongoDB
      DateTime timestamp;
      final ts = data['timestamp'];
      if (ts is String) {
        timestamp = DateTime.tryParse(ts) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }

      return VitalReading(
        heartRate:   hr.clamp(0, 300),
        spo2:        spo2.clamp(0, 100),
        temperature: temp.clamp(20, 45),
        bpSystolic:  sys.clamp(0, 300),
        bpDiastolic: dia.clamp(0, 200),
        ecgSamples:  ecgSamples,
        fallDetected: fall,
        timestamp:   timestamp,
        aiDiagnosis: data['diagnosis'] as String?,
      );
    } catch (e) {
      debugPrint('RealtimeDbService: parse error: $e');
      return null;
    }
  }
}
