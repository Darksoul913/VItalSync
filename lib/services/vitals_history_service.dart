import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/vital_reading.dart';

/// Service for saving vitals history and fetching summaries.
///
/// Architecture:
///   Flutter → ApiService → FastAPI → MongoDB (cold storage)
///   Firebase RTDB remains the source for live vitals streaming.
///
/// This replaces the previous Firestore-based implementation.
class VitalsHistoryService {
  final ApiService _api = ApiService();

  DateTime? _lastSaveTime;
  static const int _saveIntervalSecs = 30; // Save every 30s

  /// Save a reading to MongoDB via FastAPI (throttled to 1 per 30s)
  Future<void> saveReading(String uid, VitalReading reading) async {
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!).inSeconds < _saveIntervalSecs) {
      return; // Skip — too soon
    }
    _lastSaveTime = now;

    try {
      await _api.storeVitalReading(
        patientId: uid,
        heartRate: reading.heartRate,
        spo2: reading.spo2,
        temperature: reading.temperature,
        bpSystolic: reading.bpSystolic,
        bpDiastolic: reading.bpDiastolic,
        ecgSamples: reading.ecgSamples,
        fallDetected: reading.fallDetected,
      );
    } catch (e) {
      // Silently fail — don't break live data flow
      debugPrint('VitalsHistory: save to MongoDB failed: $e');
    }
  }

  /// Get daily summary from MongoDB via FastAPI
  Future<Map<String, dynamic>?> getDailySummary(
    String uid, {
    String? date,
  }) async {
    try {
      return await _api.getDailySummary(uid, date: date);
    } catch (e) {
      debugPrint('VitalsHistory: getDailySummary failed: $e');
      return null;
    }
  }

  /// Get vitals history from MongoDB via FastAPI
  Future<List<Map<String, dynamic>>> getHistory(
    String uid, {
    int limit = 100,
    int hours = 24,
  }) async {
    try {
      final result = await _api.getVitalsHistory(
        uid,
        limit: limit,
        hours: hours,
      );
      if (result != null && result['readings'] is List) {
        return List<Map<String, dynamic>>.from(result['readings']);
      }
      return [];
    } catch (e) {
      debugPrint('VitalsHistory: getHistory failed: $e');
      return [];
    }
  }

  /// Get analytics from MongoDB aggregation pipeline
  Future<Map<String, dynamic>?> getAnalytics(
    String uid,
    String vitalType, {
    int periodHours = 24,
  }) async {
    try {
      return await _api.getAnalytics(uid, vitalType, periodHours: periodHours);
    } catch (e) {
      debugPrint('VitalsHistory: getAnalytics failed: $e');
      return null;
    }
  }

  /// Get a formatted summary string for the AI chatbot
  Future<String> getSummaryForAI(String uid) async {
    final summary = await getDailySummary(uid);

    if (summary == null || summary['reading_count'] == 0) {
      return 'No historical data available yet for today.';
    }

    final hr = summary['heart_rate'] as Map<String, dynamic>? ?? {};
    final sp = summary['spo2'] as Map<String, dynamic>? ?? {};
    final tp = summary['temperature'] as Map<String, dynamic>? ?? {};
    final bp = summary['bp'] as Map<String, dynamic>? ?? {};

    return '''
Today's Health Summary (${summary['date']}):
- Readings recorded: ${summary['reading_count']}
- Heart Rate: avg ${hr['avg']} BPM (min ${hr['min']}, max ${hr['max']})
- SpO2: avg ${sp['avg']}% (min ${sp['min']}%)
- Temperature: avg ${tp['avg']}°C
- BP: avg ${bp['systolic_avg']}/${bp['diastolic_avg']} mmHg
''';
  }
}
