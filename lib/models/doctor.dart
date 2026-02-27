import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String uid;
  final String name;
  final String specialization;
  final String hospital;
  final String phone;
  final String? profileImageUrl;
  final List<String> patientIds;
  final DateTime createdAt;

  const Doctor({
    required this.uid,
    required this.name,
    required this.specialization,
    required this.hospital,
    required this.phone,
    this.profileImageUrl,
    this.patientIds = const [],
    required this.createdAt,
  });

  factory Doctor.fromMap(Map<String, dynamic> map, String uid) {
    return Doctor(
      uid: uid,
      name: map['name'] ?? '',
      specialization: map['specialization'] ?? '',
      hospital: map['hospital'] ?? '',
      phone: map['phone'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      patientIds: List<String>.from(map['patientIds'] ?? []),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'specialization': specialization,
      'hospital': hospital,
      'phone': phone,
      'role': 'doctor',
      'profileImageUrl': profileImageUrl,
      'patientIds': patientIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
