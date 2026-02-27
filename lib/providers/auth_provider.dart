import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _role = 'patient';
  String _language = 'en';
  String? _errorMessage;

  // ─── Getters ─────────────────────────────────────────────
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isLoading => _isLoading;
  String get userId => _auth.currentUser?.uid ?? '';
  String get userName =>
      _auth.currentUser?.displayName ??
      _auth.currentUser?.email?.split('@').first ??
      '';
  String get email => _auth.currentUser?.email ?? '';
  String get role => _role;
  String get language => _language;
  String? get errorMessage => _errorMessage;
  User? get firebaseUser => _auth.currentUser;

  // ─── Email/Password Login ─────────────────────────────────
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Email/Password Registration ──────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String language,
    int? age,
    String? gender,
    String? emergencyName,
    String? emergencyPhone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name
      await credential.user?.updateDisplayName(name);

      _role = role;
      _language = language;

      // Save profile to Firestore (use new list format from the start)
      final initialContacts = <Map<String, String>>[];
      if ((emergencyName ?? '').isNotEmpty ||
          (emergencyPhone ?? '').isNotEmpty) {
        initialContacts.add({
          'name': emergencyName ?? '',
          'phone': emergencyPhone ?? '',
          'relation': 'Primary',
        });
      }

      await _firestore.collection('patients').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'age': age,
        'gender': gender,
        'role': role,
        'language': language,
        'emergencyContacts': initialContacts,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Google Sign-In (placeholder) ─────────────────────────
  Future<void> googleSignIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // TODO: Add google_sign_in package and wire up
    _errorMessage = 'Google Sign-In not yet configured';
    _isLoading = false;
    notifyListeners();
  }

  // ─── Utilities ────────────────────────────────────────────
  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  /// Fetch emergency contacts for the current user from Firestore.
  /// Returns a list of contact maps. Handles both old single-contact and new list format.
  Future<List<Map<String, String>>> getEmergencyContacts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    try {
      final doc = await _firestore.collection('patients').doc(uid).get();
      final data = doc.data();
      if (data == null) return [];

      // New list format
      if (data['emergencyContacts'] is List) {
        return (data['emergencyContacts'] as List).map((c) {
          final map = Map<String, dynamic>.from(c);
          return {
            'name': map['name']?.toString() ?? '',
            'phone': map['phone']?.toString() ?? '',
            'relation': map['relation']?.toString() ?? '',
          };
        }).toList();
      }

      // Legacy single contact format
      if (data['emergencyContact'] is Map) {
        final ec = data['emergencyContact'] as Map<String, dynamic>;
        return [
          {
            'name': ec['name']?.toString() ?? '',
            'phone': ec['phone']?.toString() ?? '',
            'relation': ec['relation']?.toString() ?? '',
          },
        ];
      }
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
    }
    return [];
  }

  /// Legacy getter — returns the first emergency contact (backward compat)
  Future<Map<String, String>?> getEmergencyContact() async {
    final contacts = await getEmergencyContacts();
    return contacts.isNotEmpty ? contacts.first : null;
  }

  /// Save/update all emergency contacts for the current user in Firestore
  Future<bool> saveEmergencyContacts(List<Map<String, String>> contacts) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _firestore.collection('patients').doc(uid).set({
        'emergencyContacts': contacts,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error saving emergency contacts: $e');
      return false;
    }
  }

  /// Legacy saver — saves a single emergency contact (backward compat)
  Future<bool> saveEmergencyContact({
    required String name,
    required String phone,
    String relation = 'Primary',
  }) async {
    // Get existing contacts, update first or add
    final existing = await getEmergencyContacts();
    if (existing.isNotEmpty) {
      existing[0] = {'name': name, 'phone': phone, 'relation': relation};
    } else {
      existing.add({'name': name, 'phone': phone, 'relation': relation});
    }
    return saveEmergencyContacts(existing);
  }

  Future<void> logout() async {
    await _auth.signOut();
    _role = 'patient';
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Error Mapping ────────────────────────────────────────
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      default:
        return 'Authentication error: $code';
    }
  }
}
