import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vitals_provider.dart';
import '../../widgets/glass_container.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, VitalsProvider>(
      builder: (context, auth, vitals, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                // Profile Header
                _buildProfileHeader(auth),
                const SizedBox(height: 24),

                // Settings
                _buildSectionTitle('Settings'),
                const SizedBox(height: 10),
                _buildSettingsItem(
                  context,
                  Icons.translate,
                  'Language',
                  _languageLabel(auth.language),
                  AppTheme.primary,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.notifications,
                  'Notifications',
                  'On',
                  AppTheme.info,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.record_voice_over,
                  'Voice Alerts',
                  'On',
                  AppTheme.accent,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.dark_mode,
                  'Dark Mode',
                  'On',
                  AppTheme.textSecondary,
                  auth,
                ),
                const SizedBox(height: 20),

                // Health Info
                _buildSectionTitle('Health Profile'),
                const SizedBox(height: 10),
                _buildSettingsItem(
                  context,
                  Icons.medical_information,
                  'Medical History',
                  '',
                  AppTheme.heartRateColor,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.medication,
                  'Medications',
                  '2 Active',
                  AppTheme.warning,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.contact_emergency,
                  'Emergency Contacts',
                  '2',
                  AppTheme.danger,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.person_search,
                  'My Doctor',
                  'Dr. Patil',
                  AppTheme.success,
                  auth,
                ),
                const SizedBox(height: 20),

                // Vitals Summary
                _buildSectionTitle('Current Vitals Summary'),
                const SizedBox(height: 10),
                _buildVitalsSummary(vitals),
                const SizedBox(height: 20),

                // About
                _buildSectionTitle('About'),
                const SizedBox(height: 10),
                _buildSettingsItem(
                  context,
                  Icons.info_outline,
                  'App Version',
                  '1.0.0',
                  AppTheme.textHint,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.privacy_tip,
                  'Privacy Policy',
                  '',
                  AppTheme.textHint,
                  auth,
                ),
                _buildSettingsItem(
                  context,
                  Icons.description,
                  'Terms of Service',
                  '',
                  AppTheme.textHint,
                  auth,
                ),
                const SizedBox(height: 20),

                // Logout
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      auth.logout();
                      vitals.stopSimulation();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout, color: AppTheme.danger),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppTheme.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(AuthProvider auth) {
    final initial = auth.userName.isNotEmpty
        ? auth.userName[0].toUpperCase()
        : '?';
    return GlassContainer(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.userName.isNotEmpty ? auth.userName : 'User',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${auth.role == 'patient' ? 'Patient' : 'Doctor'} • ${_languageLabel(auth.language)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  auth.email.isNotEmpty ? auth.email : 'Not set',
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsSummary(VitalsProvider vitals) {
    return GlassContainer(
      child: Column(
        children: [
          _buildVitalRow(
            'Heart Rate',
            '${vitals.heartRate.toStringAsFixed(0)} BPM',
            vitals.hrStatus,
          ),
          const Divider(height: 16, color: AppTheme.surfaceLight),
          _buildVitalRow(
            'SpO2',
            '${vitals.spo2.toStringAsFixed(0)}%',
            vitals.spo2Status,
          ),
          const Divider(height: 16, color: AppTheme.surfaceLight),
          _buildVitalRow(
            'Temperature',
            '${vitals.temperature.toStringAsFixed(1)}°C',
            vitals.tempStatus,
          ),
          const Divider(height: 16, color: AppTheme.surfaceLight),
          _buildVitalRow(
            'Blood Pressure',
            '${vitals.systolic.toStringAsFixed(0)}/${vitals.diastolic.toStringAsFixed(0)}',
            vitals.bpStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalRow(String label, String value, String status) {
    Color statusColor;
    switch (status) {
      case 'Critical':
        statusColor = AppTheme.danger;
        break;
      case 'High':
      case 'Low':
        statusColor = AppTheme.warning;
        break;
      default:
        statusColor = AppTheme.success;
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
        ),
      ],
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'hi':
        return 'हिंदी';
      case 'mr':
        return 'मराठी';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'kn':
        return 'ಕನ್ನಡ';
      default:
        return 'English';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    IconData icon,
    String title,
    String trailing,
    Color color,
    AuthProvider auth,
  ) {
    return GestureDetector(
      onTap: () {
        if (title == 'Language') {
          _showLanguageDialog(context, auth);
        } else if (title == 'Emergency Contacts') {
          Navigator.pushNamed(context, '/emergency-contacts');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing.isNotEmpty)
              Text(
                trailing,
                style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...[
                {'code': 'en', 'name': 'English'},
                {'code': 'hi', 'name': 'हिंदी (Hindi)'},
                {'code': 'mr', 'name': 'मराठी (Marathi)'},
                {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
                {'code': 'te', 'name': 'తెలుగు (Telugu)'},
                {'code': 'kn', 'name': 'ಕನ್ನಡ (Kannada)'},
              ].map((lang) {
                return ListTile(
                  title: Text(
                    lang['name']!,
                    style: TextStyle(
                      color: auth.language == lang['code']
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      fontWeight: auth.language == lang['code']
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: auth.language == lang['code']
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    auth.setLanguage(lang['code']!);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
