import 'package:cloud_firestore/cloud_firestore.dart';

class HealthAlert {
  final String id;
  final String patientId;
  final String alertCode;
  final String message;
  final String severity; // 'warning', 'critical', 'info'
  final Map<String, dynamic> vitalSnapshot;
  final DateTime timestamp;
  final bool acknowledged;

  const HealthAlert({
    required this.id,
    required this.patientId,
    required this.alertCode,
    required this.message,
    required this.severity,
    required this.vitalSnapshot,
    required this.timestamp,
    this.acknowledged = false,
  });

  factory HealthAlert.fromMap(Map<String, dynamic> map, String id) {
    return HealthAlert(
      id: id,
      patientId: map['patientId'] ?? '',
      alertCode: map['alertCode'] ?? '',
      message: map['message'] ?? '',
      severity: map['severity'] ?? 'info',
      vitalSnapshot: Map<String, dynamic>.from(map['vitalSnapshot'] ?? {}),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      acknowledged: map['acknowledged'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'alertCode': alertCode,
      'message': message,
      'severity': severity,
      'vitalSnapshot': vitalSnapshot,
      'timestamp': Timestamp.fromDate(timestamp),
      'acknowledged': acknowledged,
    };
  }
}
