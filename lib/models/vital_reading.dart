import 'package:cloud_firestore/cloud_firestore.dart';

class VitalReading {
  final double heartRate;
  final double spo2;
  final double temperature;
  final double bpSystolic;
  final double bpDiastolic;
  final bool fallDetected;
  final List<double> ecgSamples;
  final DateTime timestamp;
  final String? aiDiagnosis;

  const VitalReading({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.bpSystolic,
    required this.bpDiastolic,
    this.fallDetected = false,
    this.ecgSamples = const [],
    required this.timestamp,
    this.aiDiagnosis,
  });

  VitalReading copyWith({
    double? heartRate,
    double? spo2,
    double? temperature,
    double? bpSystolic,
    double? bpDiastolic,
    bool? fallDetected,
    List<double>? ecgSamples,
    DateTime? timestamp,
    String? aiDiagnosis,
  }) {
    return VitalReading(
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      temperature: temperature ?? this.temperature,
      bpSystolic: bpSystolic ?? this.bpSystolic,
      bpDiastolic: bpDiastolic ?? this.bpDiastolic,
      fallDetected: fallDetected ?? this.fallDetected,
      ecgSamples: ecgSamples ?? this.ecgSamples,
      timestamp: timestamp ?? this.timestamp,
      aiDiagnosis: aiDiagnosis ?? this.aiDiagnosis,
    );
  }

  factory VitalReading.fromMap(Map<String, dynamic> map) {
    return VitalReading(
      heartRate: (map['heartRate'] ?? 0).toDouble(),
      spo2: (map['spo2'] ?? 0).toDouble(),
      temperature: (map['temperature'] ?? 0).toDouble(),
      bpSystolic: (map['bpSystolic'] ?? 0).toDouble(),
      bpDiastolic: (map['bpDiastolic'] ?? 0).toDouble(),
      fallDetected: map['fallDetected'] ?? false,
      ecgSamples:
          (map['ecgSamples'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              (map['timestamp'] ?? 0).toInt(),
            ),
      aiDiagnosis: map['aiDiagnosis'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heartRate': heartRate,
      'spo2': spo2,
      'temperature': temperature,
      'bpSystolic': bpSystolic,
      'bpDiastolic': bpDiastolic,
      'fallDetected': fallDetected,
      'ecgSamples': ecgSamples,
      'timestamp': Timestamp.fromDate(timestamp),
      'aiDiagnosis': aiDiagnosis,
    };
  }

  /// Mock reading for demo/testing
  factory VitalReading.mock() {
    return VitalReading(
      heartRate: 72,
      spo2: 98,
      temperature: 36.6,
      bpSystolic: 120,
      bpDiastolic: 80,
      fallDetected: false,
      ecgSamples: [],
      timestamp: DateTime.now(),
      aiDiagnosis: 'Normal Sinus Rhythm',
    );
  }
}
