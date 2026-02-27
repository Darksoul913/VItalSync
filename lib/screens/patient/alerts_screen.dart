import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vitals_provider.dart';
import '../../services/sos_service.dart';
import '../../models/patient.dart';
import '../../widgets/glass_container.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final SosService _sosService = SosService();

  // Emergency contact from Firestore
  Map<String, String>? _emergencyContact;
  bool _contactsLoading = true;

  // SOS countdown state
  bool _sosCountdownActive = false;
  double _sosProgress = 0.0;
  Timer? _sosTimer;
  static const int _sosDurationMs = 3000;
  static const int _sosTickMs = 30;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final auth = context.read<AuthProvider>();
    final contact = await auth.getEmergencyContact();
    if (mounted) {
      setState(() {
        _emergencyContact = contact;
        _contactsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _cancelSos();
    super.dispose();
  }

  void _startSosCountdown() {
    HapticFeedback.heavyImpact();
    setState(() {
      _sosCountdownActive = true;
      _sosProgress = 0.0;
    });

    int elapsed = 0;
    _sosTimer = Timer.periodic(
      const Duration(milliseconds: _sosTickMs),
      (timer) {
        elapsed += _sosTickMs;
        setState(() => _sosProgress = elapsed / _sosDurationMs);

        // Haptic tick every 500ms
        if (elapsed % 500 == 0) HapticFeedback.mediumImpact();

        if (elapsed >= _sosDurationMs) {
          timer.cancel();
          _executeSos();
        }
      },
    );
  }

  void _cancelSos() {
    _sosTimer?.cancel();
    if (mounted) {
      setState(() {
        _sosCountdownActive = false;
        _sosProgress = 0.0;
      });
    }
  }

  Future<void> _executeSos() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _sosCountdownActive = false;
      _sosProgress = 0.0;
    });

    final contact = EmergencyContact(
      name: _emergencyContact?['name'] ?? 'Emergency',
      phone: _emergencyContact?['phone'] ?? '',
      relation: _emergencyContact?['relation'] ?? 'Primary',
    );

    if (contact.phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No emergency contact set. Add one in your profile.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    await _sosService.triggerSos(contact: contact);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚨 SOS Activated — Calling ${contact.name}'),
          backgroundColor: AppTheme.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, vitals, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Alerts & Emergency')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSOSButton(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showContactEditor(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _emergencyContact != null &&
                                      (_emergencyContact!['phone'] ?? '')
                                          .isNotEmpty
                                  ? Icons.edit
                                  : Icons.add,
                              color: AppTheme.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _emergencyContact != null &&
                                      (_emergencyContact!['phone'] ?? '')
                                          .isNotEmpty
                                  ? 'Edit'
                                  : 'Add',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_contactsLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_emergencyContact != null &&
                    (_emergencyContact!['phone'] ?? '').isNotEmpty)
                  _buildContactCard(
                    _emergencyContact!['name'] ?? 'Emergency',
                    _emergencyContact!['phone']!,
                    _emergencyContact!['relation'] ?? 'Contact',
                  )
                else
                  GestureDetector(
                    onTap: () => _showContactEditor(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add,
                              color: AppTheme.primary, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Tap to add emergency contact',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Alerts',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${vitals.alerts.length} total',
                      style: const TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (vitals.alerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.success,
                            size: 40,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No alerts yet',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All vitals are within normal range',
                            style: TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...vitals.alerts.take(15).map((alert) {
                    final elapsed =
                        DateTime.now().difference(alert.timestamp);
                    final timeStr = elapsed.inMinutes < 1
                        ? 'Just now'
                        : elapsed.inMinutes < 60
                            ? '${elapsed.inMinutes}m ago'
                            : '${elapsed.inHours}h ago';

                    return _buildAlertItem(
                      alert.message,
                      alert.severity,
                      timeStr,
                      alert.acknowledged,
                      onAcknowledge: () =>
                          vitals.acknowledgeAlert(alert.id),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSOSButton() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onLongPressStart: (_) => _startSosCountdown(),
            onLongPressEnd: (_) {
              if (_sosCountdownActive) _cancelSos();
            },
            onLongPressCancel: () {
              if (_sosCountdownActive) _cancelSos();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _sosCountdownActive ? 130 : 120,
              height: _sosCountdownActive ? 130 : 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring
                  if (_sosCountdownActive)
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CircularProgressIndicator(
                        value: _sosProgress,
                        strokeWidth: 4,
                        color: Colors.white,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  // Main button
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.dangerGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.danger.withValues(
                            alpha: _sosCountdownActive ? 0.7 : 0.4,
                          ),
                          blurRadius: _sosCountdownActive ? 40 : 30,
                          spreadRadius:
                              _sosCountdownActive ? 10 : 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _sosCountdownActive ? '${(3 - (_sosProgress * 3)).ceil()}' : 'SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _sosCountdownActive
                ? 'Release to cancel'
                : 'Long press to activate emergency',
            style: TextStyle(
              color: _sosCountdownActive
                  ? AppTheme.danger
                  : AppTheme.textHint,
              fontSize: 13,
              fontWeight: _sosCountdownActive
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactEditor() {
    final nameCtrl = TextEditingController(
      text: _emergencyContact?['name'] ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: _emergencyContact?['phone'] ?? '',
    );
    final relationCtrl = TextEditingController(
      text: _emergencyContact?['relation'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emergency Contact',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle:
                      const TextStyle(color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.person,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle:
                      const TextStyle(color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.phone,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Relation (e.g. Mother, Doctor)',
                  labelStyle:
                      const TextStyle(color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.people,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final relation = relationCtrl.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Name and phone are required'),
                          backgroundColor: AppTheme.warning,
                        ),
                      );
                      return;
                    }

                    final auth = context.read<AuthProvider>();
                    final success =
                        await auth.saveEmergencyContact(
                      name: name,
                      phone: phone,
                      relation:
                          relation.isNotEmpty ? relation : 'Primary',
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      if (success) {
                        _loadContacts();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '✅ Emergency contact saved'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Failed to save contact'),
                            backgroundColor: AppTheme.danger,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactCard(String name, String phone, String relation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    relation,
                    style: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon:
                  const Icon(Icons.phone, color: AppTheme.success, size: 22),
              onPressed: () => _sosService.callContact(
                phone.replaceAll(' ', ''),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.message, color: AppTheme.info, size: 22),
              onPressed: () => _sosService.sendSms(
                phone.replaceAll(' ', ''),
                'Hi, this is a message from VitalSync health app.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(
    String message,
    String severity,
    String time,
    bool acknowledged, {
    VoidCallback? onAcknowledge,
  }) {
    Color color;
    IconData icon;
    switch (severity) {
      case 'critical':
        color = AppTheme.danger;
        icon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        color = AppTheme.warning;
        icon = Icons.info_outline;
        break;
      default:
        color = AppTheme.info;
        icon = Icons.notifications_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!acknowledged && onAcknowledge != null)
            GestureDetector(
              onTap: onAcknowledge,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACK',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            const Icon(
              Icons.check_circle_outline,
              color: AppTheme.textHint,
              size: 16,
            ),
        ],
      ),
    );
  }
}
