import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String uid;
  final String name;
  final int age;
  final String gender;
  final String language;
  final String phone;
  final List<EmergencyContact> emergencyContacts;
  final String? assignedDoctorId;
  final String? profileImageUrl;
  final DateTime createdAt;

  const Patient({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    required this.language,
    required this.phone,
    required this.emergencyContacts,
    this.assignedDoctorId,
    this.profileImageUrl,
    required this.createdAt,
  });

  /// Primary emergency contact (first in the list, for backward compat)
  EmergencyContact? get primaryEmergencyContact =>
      emergencyContacts.isNotEmpty ? emergencyContacts.first : null;

  factory Patient.fromMap(Map<String, dynamic> map, String uid) {
    // Backward compatible: handle both old single-contact and new list format
    List<EmergencyContact> contacts = [];
    if (map['emergencyContacts'] is List) {
      contacts = (map['emergencyContacts'] as List)
          .map((c) => EmergencyContact.fromMap(Map<String, dynamic>.from(c)))
          .toList();
    } else if (map['emergencyContact'] is Map) {
      // Legacy single contact format
      contacts = [
        EmergencyContact.fromMap(
          Map<String, dynamic>.from(map['emergencyContact']),
        ),
      ];
    }

    return Patient(
      uid: uid,
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      language: map['language'] ?? 'en',
      phone: map['phone'] ?? '',
      emergencyContacts: contacts,
      assignedDoctorId: map['assignedDoctorId'],
      profileImageUrl: map['profileImageUrl'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'language': language,
      'phone': phone,
      'role': 'patient',
      'emergencyContacts': emergencyContacts.map((c) => c.toMap()).toList(),
      'assignedDoctorId': assignedDoctorId,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relation: map['relation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'phone': phone, 'relation': relation};
  }
}
