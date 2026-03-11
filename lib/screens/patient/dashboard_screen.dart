import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vitals_provider.dart';
import '../../models/patient.dart';
import '../../widgets/vital_card.dart';
import '../../widgets/ecg_painter.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/glass_container.dart';
import '../../services/sos_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _fallDialogShown = false;
  bool _autoEmergencyDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set patient UID for RTDB subscription
      final auth = context.read<AuthProvider>();
      final uid = auth.firebaseUser?.uid ?? 'demo-user';
      context.read<VitalsProvider>().setPatientId(uid);
      context.read<VitalsProvider>().startSimulation();
      // Listen for fall detection and auto-emergency
      context.read<VitalsProvider>().addListener(_onVitalsChanged);
      // Load emergency contacts for auto-SMS and auto-call
      _loadEmergencyContacts();
    });
  }

  Future<void> _loadEmergencyContacts() async {
    final auth = context.read<AuthProvider>();
    final contactMaps = await auth.getEmergencyContacts();
    if (contactMaps.isNotEmpty && mounted) {
      final contacts = contactMaps
          .where((c) => (c['phone'] ?? '').isNotEmpty)
          .map(
            (c) => EmergencyContact(
              name: c['name'] ?? 'Emergency',
              phone: c['phone'] ?? '',
              relation: c['relation'] ?? 'Contact',
            ),
          )
          .toList();
      context.read<VitalsProvider>().setEmergencyContacts(contacts);
    }
    // Request SOS permissions proactively
    final sosService = SosService();
    await sosService.requestSosPermissions();
  }

  @override
  void dispose() {
    // Remove listener safely
    try {
      context.read<VitalsProvider>().removeListener(_onVitalsChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onVitalsChanged() {
    final vitals = context.read<VitalsProvider>();

    // Fall detection SOS
    if (vitals.fallSosTriggered && !_fallDialogShown && mounted) {
      _fallDialogShown = true;
      _showFallSosDialog();
    }

    // Auto-emergency (sustained critical vitals)
    if (vitals.autoEmergencyDialogPending &&
        !_autoEmergencyDialogShown &&
        mounted) {
      _autoEmergencyDialogShown = true;
      _showAutoEmergencyDialog();
    }
  }

  // ─── Auto-Emergency Dialog (sustained critical vitals) ────
  void _showAutoEmergencyDialog() {
    int remaining = 15; // 15-second countdown before auto-call
    Timer? countdownTimer;

    final vitals = context.read<VitalsProvider>();
    final criticalVitals = vitals.criticalAlertService.criticalDurations;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              if (remaining <= 1) {
                timer.cancel();
                Navigator.of(dialogContext).pop();
                _executeAutoEmergency();
                return;
              }
              setDialogState(() => remaining--);
            });

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.emergency,
                      color: AppTheme.danger,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'EMERGENCY ALERT',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Critical vitals sustained — auto-emergency will trigger:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Critical vitals list
                  ...criticalVitals.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            color: AppTheme.danger,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.key} — critical for ${entry.value.inSeconds}s',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Countdown
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Calling & messaging contacts in',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${remaining}s',
                          style: const TextStyle(
                            color: AppTheme.danger,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (15 - remaining) / 15,
                    color: AppTheme.danger,
                    backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),

                  const SizedBox(height: 8),
                  if (vitals.emergencyContacts.isNotEmpty)
                    Text(
                      '📞 ${vitals.emergencyContacts.first.name} will be called\n'
                      '💬 SMS to ${vitals.emergencyContacts.length} contact(s)',
                      style: const TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(dialogContext).pop();
                    _cancelAutoEmergency();
                  },
                  child: const Text(
                    "I'm OK — Cancel",
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(dialogContext).pop();
                    _executeAutoEmergency();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                  ),
                  child: const Text(
                    'Call Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
    });
  }

  Future<void> _executeAutoEmergency() async {
    final vitals = context.read<VitalsProvider>();

    if (vitals.emergencyContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ No emergency contacts set. Go to Profile → Emergency Contacts.',
            ),
            backgroundColor: AppTheme.warning,
          ),
        );
        vitals.clearAutoEmergencyPending();
        _autoEmergencyDialogShown = false;
      }
      return;
    }

    await vitals.executeAutoEmergency();
    if (mounted) {
      _autoEmergencyDialogShown = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🚨 Emergency alert sent to ${vitals.emergencyContacts.length} contact(s)',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _cancelAutoEmergency() {
    context.read<VitalsProvider>().clearAutoEmergencyPending();
    _autoEmergencyDialogShown = false;
  }

  // ─── Fall Detection Dialog ────────────────────────────────
  void _showFallSosDialog() {
    int remaining = 30;
    Timer? countdownTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              if (remaining <= 1) {
                timer.cancel();
                Navigator.of(dialogContext).pop();
                _executeFallSos();
                return;
              }
              setDialogState(() => remaining--);
            });

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.danger,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Fall Detected!',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'A fall has been detected. Emergency contact will be called automatically.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Calling in ${remaining}s',
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (30 - remaining) / 30,
                    color: AppTheme.danger,
                    backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(dialogContext).pop();
                    _cancelFallSos();
                  },
                  child: const Text(
                    "I'm OK",
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(dialogContext).pop();
                    _executeFallSos();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                  ),
                  child: const Text(
                    'Call Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
    });
  }

  Future<void> _executeFallSos() async {
    final sosService = SosService();
    final auth = context.read<AuthProvider>();
    final ec = await auth.getEmergencyContact();

    final contact = EmergencyContact(
      name: ec?['name'] ?? 'Emergency',
      phone: ec?['phone'] ?? '',
      relation: ec?['relation'] ?? 'Primary',
    );

    if (contact.phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No emergency contact set.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        context.read<VitalsProvider>().clearFallSos();
        _fallDialogShown = false;
      }
      return;
    }

    await sosService.triggerSos(
      contact: contact,
      customMessage:
          'FALL DETECTED — VitalSync has detected a fall. Please check on the patient immediately.',
    );
    if (mounted) {
      context.read<VitalsProvider>().clearFallSos();
      _fallDialogShown = false;
    }
  }

  void _cancelFallSos() {
    context.read<VitalsProvider>().clearFallSos();
    _fallDialogShown = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, vitals, _) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(vitals),
                  const SizedBox(height: 16),
                  _buildStatusBanner(vitals),
                  const SizedBox(height: 20),
                  _buildVitalsGrid(vitals),
                  const SizedBox(height: 20),
                  _buildEcgPreview(vitals),
                  const SizedBox(height: 20),
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildInsightCard(vitals),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(VitalsProvider vitals) {
    final auth = context.read<AuthProvider>();
    final name = auth.userName.isNotEmpty ? auth.userName : 'User';
    final initial = name[0].toUpperCase();
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
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
                _getGreeting(),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _buildHeaderIcon(Icons.notifications_outlined),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Icon(icon, color: AppTheme.textSecondary, size: 20),
    );
  }

  Widget _buildStatusBanner(VitalsProvider vitals) {
    final status = vitals.overallStatus;
    String msg;
    String severity;

    switch (status) {
      case 'Critical':
        msg = '⚠️ Critical alert! Check your vitals immediately.';
        severity = 'critical';
        break;
      case 'Warning':
        msg = '⚡ Some vitals need attention. Tap for details.';
        severity = 'warning';
        break;
      default:
        msg = 'All vitals are normal. Keep it up! 💚';
        severity = 'info';
    }

    return AlertBanner(
      message: msg,
      severity: severity,
      onTap: () => Navigator.pushNamed(context, '/alerts'),
    );
  }

  Widget _buildVitalsGrid(VitalsProvider vitals) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            VitalCard(
              title: 'Heart Rate',
              value: vitals.heartRate.toStringAsFixed(0),
              unit: 'BPM',
              icon: Icons.favorite_rounded,
              color: AppTheme.heartRateColor,
              status: vitals.hrStatus,
            ),
            VitalCard(
              title: 'SpO2',
              value: vitals.spo2.toStringAsFixed(0),
              unit: '%',
              icon: Icons.water_drop_rounded,
              color: AppTheme.spo2Color,
              status: vitals.spo2Status,
            ),
            VitalCard(
              title: 'Temperature',
              value: vitals.temperature.toStringAsFixed(1),
              unit: '°C',
              icon: Icons.thermostat_rounded,
              color: AppTheme.temperatureColor,
              status: vitals.tempStatus,
            ),
            VitalCard(
              title: 'Blood Pressure',
              value:
                  '${vitals.systolic.toStringAsFixed(0)}/${vitals.diastolic.toStringAsFixed(0)}',
              unit: 'mmHg',
              icon: Icons.speed_rounded,
              color: AppTheme.bpColor,
              status: vitals.bpStatus,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFallDetectionCard(vitals),
      ],
    );
  }

  Widget _buildFallDetectionCard(VitalsProvider vitals) {
    final bool isFall = vitals.fallDetected;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: (isFall ? AppTheme.danger : AppTheme.accent).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isFall ? [
          BoxShadow(
            color: AppTheme.danger.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isFall ? AppTheme.danger : AppTheme.accent).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFall ? Icons.warning_amber_rounded : Icons.accessibility_new_rounded,
              color: isFall ? AppTheme.danger : AppTheme.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fall Detection (MPU6050)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFall ? 'FALL DETECTED' : 'Active & Monitoring',
                  style: TextStyle(
                    color: isFall ? AppTheme.danger : AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (!isFall)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Normal',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEcgPreview(VitalsProvider vitals) {
    final ecg = vitals.ecgSamples.isNotEmpty
        ? vitals.ecgSamples
        : generateMockEcg(beats: 4, samplesPerBeat: 80);

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart, color: AppTheme.ecgColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ECG Waveform',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                              ? AppTheme.success
                              : AppTheme.warning)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vitals.aiDiagnosis ?? 'Normal Sinus',
                  style: TextStyle(
                    color: vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                        ? AppTheme.success
                        : AppTheme.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EcgWaveform(
            samples: ecg,
            height: 120,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionButton(
              Icons.health_and_safety,
              'SOS',
              AppTheme.danger,
              () => Navigator.pushNamed(context, '/alerts'),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              Icons.medical_information,
              'Checkup',
              AppTheme.primary,
              () => Navigator.pushNamed(context, '/checkup'),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              Icons.smart_toy,
              'AI Chat',
              AppTheme.accent,
              () => Navigator.pushNamed(context, '/chat'),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              Icons.history,
              'History',
              AppTheme.info,
              () => Navigator.pushNamed(context, '/vitals-detail'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(VitalsProvider vitals) {
    return GlassContainer(
      borderColor: AppTheme.accent.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppTheme.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Health Insight',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vitals.aiInsight,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
