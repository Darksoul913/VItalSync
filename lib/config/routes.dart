import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/language_select_screen.dart';
import '../screens/patient/vitals_detail_screen.dart';
import '../screens/patient/ecg_screen.dart';
import '../screens/patient/checkup_screen.dart';
import '../screens/patient/chat_screen.dart';
import '../screens/patient/alerts_screen.dart';
import '../screens/patient/profile_screen.dart';
import '../screens/patient/patient_shell.dart';
import '../screens/patient/emergency_contacts_screen.dart';
import '../screens/patient/device_pairing_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String languageSelect = '/language-select';
  static const String patientHome = '/patient';
  static const String vitalsDetail = '/vitals-detail';
  static const String ecg = '/ecg';
  static const String checkup = '/checkup';
  static const String chat = '/chat';
  static const String alerts = '/alerts';
  static const String profile = '/profile';
  static const String emergencyContacts = '/emergency-contacts';
  static const String devices = '/devices';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    languageSelect: (context) => const LanguageSelectScreen(),
    patientHome: (context) => const PatientShell(),
    vitalsDetail: (context) => const VitalsDetailScreen(),
    ecg: (context) => const EcgScreen(),
    checkup: (context) => const CheckupScreen(),
    chat: (context) => const ChatScreen(),
    alerts: (context) => const AlertsScreen(),
    profile: (context) => const ProfileScreen(),
    emergencyContacts: (context) => const EmergencyContactsScreen(),
    devices: (context) => const DevicePairingScreen(),
  };
}
