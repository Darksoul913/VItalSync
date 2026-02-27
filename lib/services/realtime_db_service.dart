import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/vital_reading.dart';

class RealtimeDbService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Listen to live patient vitals
  /// Maps ESP32 field names → VitalReading model
  Stream<VitalReading?> streamPatientVitals(String patientId) {
    return _db.ref('patients/$patientId/vitals/live').onValue.map((event) {
      if (event.snapshot.value == null) return null;

      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // ─── ESP32 field mapping ───────────────────────────
        // Heart rate: avg_bpm or ecg_bpm (prefer avg_bpm)
        final hr = (data['avg_bpm'] ?? data['ecg_bpm'] ?? data['hr'] ?? 0 as num).toDouble().clamp(0, 300);

        // SpO2: direct match
        final spo2 = ((data['spo2'] as num?)?.toDouble() ?? 0.0).clamp(0, 100);

        // Temperature: temp_c from ESP32, or temp as fallback
        final temp = (data['temp_c'] ?? data['temp'] ?? 0 as num).toDouble().clamp(20, 45);

        // Blood pressure: not from ESP32, use defaults or if available
        final sys = ((data['sys'] as num?)?.toDouble() ?? 120.0).clamp(0, 300);
        final dia = ((data['dia'] as num?)?.toDouble() ?? 80.0).clamp(0, 200);

        // ECG: ecg_filtered or ecg_raw as single value → wrap in list
        final ecgFiltered = (data['ecg_filtered'] as num?)?.toDouble();
        final ecgRaw = (data['ecg_raw'] as num?)?.toDouble();
        List<double> ecgSamples = [];
        if (data['ecg'] is List) {
          ecgSamples = (data['ecg'] as List).map((e) => (e as num).toDouble()).toList();
        } else if (ecgFiltered != null) {
          ecgSamples = [ecgFiltered];
        } else if (ecgRaw != null) {
          ecgSamples = [ecgRaw];
        }

        // Fall detection: check accelerometer magnitude spike
        bool fallDetected = data['fall'] == true;
        if (!fallDetected && data['accel_x'] != null) {
          final ax = (data['accel_x'] as num).toDouble();
          final ay = (data['accel_y'] as num?)?.toDouble() ?? 0;
          final az = (data['accel_z'] as num?)?.toDouble() ?? 0;
          final magnitude = sqrt(ax * ax + ay * ay + az * az);
          // Threshold: normal gravity ~16384, a big spike signals a fall
          fallDetected = magnitude > 25000;
        }

        // Timestamp
        final ts = data['timestamp'];
        DateTime timestamp;
        if (ts is int) {
          // If timestamp < 1 billion, it's likely seconds (ESP32 millis/1000)
          timestamp = ts > 1000000000000
              ? DateTime.fromMillisecondsSinceEpoch(ts)
              : DateTime.fromMillisecondsSinceEpoch(ts * 1000);
        } else {
          timestamp = DateTime.now();
        }

        return VitalReading(
          heartRate: hr.toDouble(),
          spo2: spo2.toDouble(),
          temperature: temp.toDouble(),
          bpSystolic: sys.toDouble(),
          bpDiastolic: dia.toDouble(),
          ecgSamples: ecgSamples,
          fallDetected: fallDetected,
          timestamp: timestamp,
          aiDiagnosis: data['diagnosis'] as String?,
        );
      } catch (e) {
        print('Error parsing RTDB vital reading: $e');
        return null;
      }
    });
  }
}
