import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vital_reading.dart';

/// Service for saving vitals history to Firestore and fetching summaries.
/// RTDB handles live data. Firestore handles historical storage.
class VitalsHistoryService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  DateTime? _lastSaveTime;
  static const int _saveIntervalSecs = 30; // Save every 30s

  /// Save a reading to Firestore vitals_log (throttled to 1 per 30s)
  Future<void> saveReading(String uid, VitalReading reading) async {
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!).inSeconds < _saveIntervalSecs) {
      return; // Skip — too soon
    }
    _lastSaveTime = now;

    try {
      await _fs.collection('users').doc(uid).collection('vitals_log').add({
        'hr': reading.heartRate,
        'spo2': reading.spo2,
        'temp': reading.temperature,
        'sys': reading.bpSystolic,
        'dia': reading.bpDiastolic,
        'fall': reading.fallDetected,
        'timestamp': FieldValue.serverTimestamp(),
        'epoch_ms': now.millisecondsSinceEpoch,
      });
    } catch (e) {
      // Silently fail — don't break live data flow
      print('VitalsHistory: save failed: $e');
    }
  }

  /// Get daily summary from Firestore
  Future<Map<String, dynamic>?> getDailySummary(String uid, {String? date}) async {
    final targetDate = date ?? _todayString();
    try {
      final doc = await _fs
          .collection('users')
          .doc(uid)
          .collection('daily_summary')
          .doc(targetDate)
          .get();

      if (doc.exists) return doc.data();

      // Auto-generate if not found
      return await generateDailySummary(uid, targetDate);
    } catch (e) {
      print('VitalsHistory: getDailySummary failed: $e');
      return null;
    }
  }

  /// Generate daily summary from vitals_log
  Future<Map<String, dynamic>?> generateDailySummary(String uid, String date) async {
    try {
      final dt = DateTime.parse(date);
      final start = DateTime(dt.year, dt.month, dt.day);
      final end = start.add(const Duration(days: 1));

      final snap = await _fs
          .collection('users')
          .doc(uid)
          .collection('vitals_log')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThan: Timestamp.fromDate(end))
          .get();

      if (snap.docs.isEmpty) return null;

      final hrs = <double>[];
      final spo2s = <double>[];
      final temps = <double>[];
      final syss = <double>[];
      final dias = <double>[];
      int alertCount = 0;
      int criticalCount = 0;

      for (final doc in snap.docs) {
        final d = doc.data();
        final hr = (d['hr'] as num?)?.toDouble() ?? 0;
        final sp = (d['spo2'] as num?)?.toDouble() ?? 0;
        final tp = (d['temp'] as num?)?.toDouble() ?? 0;
        final sy = (d['sys'] as num?)?.toDouble() ?? 0;
        final di = (d['dia'] as num?)?.toDouble() ?? 0;

        if (hr > 0) hrs.add(hr);
        if (sp > 0) spo2s.add(sp);
        if (tp > 0) temps.add(tp);
        if (sy > 0) syss.add(sy);
        if (di > 0) dias.add(di);

        if (hr > 95) alertCount++;
        if (hr > 150 || sp < 88) criticalCount++;
      }

      Map<String, double> stats(List<double> vals) {
        if (vals.isEmpty) return {'avg': 0, 'min': 0, 'max': 0};
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        vals.sort();
        return {
          'avg': double.parse(avg.toStringAsFixed(1)),
          'min': vals.first,
          'max': vals.last,
        };
      }

      final summary = {
        'date': date,
        'reading_count': snap.docs.length,
        'heart_rate': stats(hrs),
        'spo2': stats(spo2s),
        'temperature': stats(temps),
        'bp_systolic': stats(syss),
        'bp_diastolic': stats(dias),
        'alert_count': alertCount,
        'critical_count': criticalCount,
        'generated_at': FieldValue.serverTimestamp(),
      };

      // Save summary
      await _fs
          .collection('users')
          .doc(uid)
          .collection('daily_summary')
          .doc(date)
          .set(summary);

      return summary;
    } catch (e) {
      print('VitalsHistory: generateDailySummary failed: $e');
      return null;
    }
  }

  /// Get a formatted summary string for the AI chatbot
  Future<String> getSummaryForAI(String uid) async {
    final today = _todayString();
    final summary = await getDailySummary(uid, date: today);

    if (summary == null) {
      return 'No historical data available yet for today.';
    }

    final hr = summary['heart_rate'] as Map<String, dynamic>? ?? {};
    final sp = summary['spo2'] as Map<String, dynamic>? ?? {};
    final tp = summary['temperature'] as Map<String, dynamic>? ?? {};
    final sy = summary['bp_systolic'] as Map<String, dynamic>? ?? {};

    return '''
Today's Health Summary ($today):
- Readings recorded: ${summary['reading_count']}
- Heart Rate: avg ${hr['avg']} BPM (min ${hr['min']}, max ${hr['max']})
- SpO2: avg ${sp['avg']}% (min ${sp['min']}%)
- Temperature: avg ${tp['avg']}°C
- BP: avg ${sy['avg']}/${(summary['bp_diastolic'] as Map?)?['avg'] ?? 0} mmHg
- Alerts: ${summary['alert_count']} (${summary['critical_count']} critical)
''';
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
