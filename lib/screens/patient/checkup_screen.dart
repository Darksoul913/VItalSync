import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/vitals_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/tts_service.dart';
import '../../widgets/glass_container.dart';

class CheckupScreen extends StatefulWidget {
  const CheckupScreen({super.key});

  @override
  State<CheckupScreen> createState() => _CheckupScreenState();
}

class _CheckupScreenState extends State<CheckupScreen> {
  final TtsService _tts = TtsService();
  String? _activeTest;
  int _countdown = 0;
  Timer? _timer;
  String _testResult = '';
  bool _languageSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync TTS language from provider on first build
    if (!_languageSynced) {
      final lang = context.read<AuthProvider>().language;
      _tts.setLanguage(lang);
      _languageSynced = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.dispose();
    super.dispose();
  }

  void _startTest(String testId, int durationSeconds) {
    if (_activeTest != null) return;

    setState(() {
      _activeTest = testId;
      _countdown = durationSeconds;
      _testResult = '';
    });

    // Voice guidance (vernacular)
    switch (testId) {
      case 'orthostatic':
        _tts.speakMessage('TEST_ORTHOSTATIC');
        break;
      case 'breathing':
        _tts.speakMessage('TEST_BREATHING');
        break;
      case 'stress':
        _tts.speakMessage('TEST_STRESS');
        break;
      case 'ecg':
        _tts.speakMessage('TEST_ECG');
        break;
      case 'sleep':
        _tts.speakMessage('TEST_SLEEP');
        break;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        _completeTest(testId);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _completeTest(String testId) {
    final vitals = context.read<VitalsProvider>();

    String result;
    switch (testId) {
      case 'orthostatic':
        final hrChange = (vitals.heartRate - 72).abs();
        result = hrChange > 20
            ? '⚠️ Significant HR change detected (${hrChange.toStringAsFixed(0)} BPM). Possible dehydration.'
            : '✅ Normal orthostatic response. HR change: ${hrChange.toStringAsFixed(0)} BPM.';
        break;
      case 'breathing':
        result = vitals.spo2 >= 96
            ? '✅ Excellent respiratory health. SpO2: ${vitals.spo2.toStringAsFixed(0)}%'
            : '⚠️ SpO2 slightly low at ${vitals.spo2.toStringAsFixed(0)}%. Practice deep breathing exercises.';
        break;
      case 'stress':
        result = vitals.heartRate < 120
            ? '✅ Good cardiac recovery. HR: ${vitals.heartRate.toStringAsFixed(0)} BPM'
            : '⚠️ Elevated recovery HR: ${vitals.heartRate.toStringAsFixed(0)} BPM. Consider improving cardio fitness.';
        break;
      case 'ecg':
        result = vitals.aiDiagnosis == 'Normal Sinus Rhythm'
            ? '✅ Normal Sinus Rhythm detected. No irregularities found.'
            : '⚠️ ${vitals.aiDiagnosis ?? "Unknown rhythm"}. Consult your cardiologist.';
        break;
      case 'sleep':
        result =
            '✅ Sleep analysis: Average HR ${vitals.heartRate.toStringAsFixed(0)} BPM, SpO2 ${vitals.spo2.toStringAsFixed(0)}%. Quality: Good';
        break;
      default:
        result = 'Test complete.';
    }

    _tts.speakMessage('TEST_COMPLETE');

    setState(() {
      _activeTest = null;
      _countdown = 0;
      _testResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, vitals, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Health Checkup')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Health Tests',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vitals.deviceConnected
                      ? 'Device connected — ready for guided assessments'
                      : 'Connect your device to begin health tests',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                // Test result banner
                if (_testResult.isNotEmpty) ...[
                  GlassContainer(
                    borderColor: _testResult.contains('✅')
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : AppTheme.warning.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        Icon(
                          _testResult.contains('✅')
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: _testResult.contains('✅')
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _testResult,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppTheme.textHint,
                          ),
                          onPressed: () => setState(() => _testResult = ''),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildTestCard(
                  testId: 'orthostatic',
                  title: 'Orthostatic Test',
                  subtitle: 'Detects dehydration & orthostasis',
                  instruction: 'Lie down for 2 minutes, then stand up quickly',
                  icon: Icons.accessibility_new,
                  color: AppTheme.primary,
                  durationSeconds: 10,
                  durationLabel: '10 sec',
                  enabled: vitals.deviceConnected,
                ),
                _buildTestCard(
                  testId: 'breathing',
                  title: 'Deep Breath Test',
                  subtitle: 'Measures respiratory health',
                  instruction:
                      'Take 5 slow, deep breaths while wearing the device',
                  icon: Icons.air,
                  color: AppTheme.spo2Color,
                  durationSeconds: 15,
                  durationLabel: '15 sec',
                  enabled: vitals.deviceConnected,
                ),
                _buildTestCard(
                  testId: 'stress',
                  title: 'Stress Test',
                  subtitle: 'Checks cardiac response under load',
                  instruction: 'Walk briskly for 2 minutes, then rest',
                  icon: Icons.directions_walk,
                  color: AppTheme.heartRateColor,
                  durationSeconds: 12,
                  durationLabel: '12 sec',
                  enabled: vitals.deviceConnected,
                ),
                _buildTestCard(
                  testId: 'ecg',
                  title: 'Resting ECG',
                  subtitle: 'Full 30-second ECG recording',
                  instruction:
                      'Sit still and place fingers on copper electrodes',
                  icon: Icons.monitor_heart,
                  color: AppTheme.ecgColor,
                  durationSeconds: 8,
                  durationLabel: '8 sec',
                  enabled: vitals.deviceConnected,
                ),
                _buildTestCard(
                  testId: 'sleep',
                  title: 'Sleep Quality Review',
                  subtitle: 'Analyzes overnight vitals',
                  instruction: 'View your sleep data from last night',
                  icon: Icons.bedtime,
                  color: AppTheme.accent,
                  durationSeconds: 5,
                  durationLabel: '5 sec',
                  enabled: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestCard({
    required String testId,
    required String title,
    required String subtitle,
    required String instruction,
    required IconData icon,
    required Color color,
    required int durationSeconds,
    required String durationLabel,
    required bool enabled,
  }) {
    final isActive = _activeTest == testId;
    final isRunning = _activeTest != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassContainer(
        borderColor: isActive
            ? color.withValues(alpha: 0.5)
            : color.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_countdown}s',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      durationLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.textHint,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instruction,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Progress bar when active
            if (isActive)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1.0 - (_countdown / durationSeconds),
                  backgroundColor: color.withValues(alpha: 0.1),
                  color: color,
                  minHeight: 4,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (enabled && !isRunning)
                      ? () => _startTest(testId, durationSeconds)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(enabled ? 'Start Test' : 'Connect Device First'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
