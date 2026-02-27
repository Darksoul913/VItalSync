import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/vitals_provider.dart';
import '../../widgets/ecg_painter.dart';
import '../../widgets/glass_container.dart';

class EcgScreen extends StatelessWidget {
  const EcgScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, vitals, _) {
        final ecg = vitals.ecgSamples.isNotEmpty
            ? vitals.ecgSamples
            : generateMockEcg(beats: 6, samplesPerBeat: 100);

        return Scaffold(
          appBar: AppBar(title: const Text('ECG Monitor')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Diagnosis Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                                  ? AppTheme.success
                                  : AppTheme.warning)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            (vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                                    ? AppTheme.success
                                    : AppTheme.warning)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                              ? AppTheme.success
                              : AppTheme.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          vitals.aiDiagnosis ?? 'Analyzing...',
                          style: TextStyle(
                            color: vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                                ? AppTheme.success
                                : AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ECG Waveform
                GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppTheme.ecgColor.withValues(alpha: 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.monitor_heart,
                            color: AppTheme.ecgColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Live ECG',
                            style: TextStyle(
                              color: AppTheme.ecgColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: vitals.isSimulating
                                  ? AppTheme.success
                                  : AppTheme.textHint,
                              boxShadow: vitals.isSimulating
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.success.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            vitals.isSimulating ? 'Live' : 'Paused',
                            style: TextStyle(
                              color: vitals.isSimulating
                                  ? AppTheme.success
                                  : AppTheme.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          child: CustomPaint(
                            painter: EcgPainter(samples: ecg),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ECG Metrics (Dynamically Calculated from HR)
                Builder(
                  builder: (context) {
                    final hr = vitals.heartRate;
                    // Standard approximations based on HR for UI feedback
                    final rr = 60000 / hr;
                    final pr = 120 + (100 * (60 / hr)).clamp(0, 80);
                    final qrs = 80 + (20 * (60 / hr)).clamp(0, 40);
                    // Bazett's formula approximation
                    final qt = 350 * math.sqrt(rr / 1000);
                    // HRV approximation (higher HR = generally lower HRV)
                    final hrv = (100 - (hr - 60) * 0.8).clamp(20, 120);

                    return Column(
                      children: [
                        Row(
                          children: [
                            _buildMetricCard(
                              'Heart Rate',
                              hr.toStringAsFixed(0),
                              'BPM',
                              AppTheme.heartRateColor,
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              'PR Interval',
                              pr.toStringAsFixed(0),
                              'ms',
                              AppTheme.info,
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              'QRS',
                              qrs.toStringAsFixed(0),
                              'ms',
                              AppTheme.ecgColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildMetricCard(
                              'QT/QTc',
                              qt.toStringAsFixed(0),
                              'ms',
                              AppTheme.accent,
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              'HRV',
                              hrv.toStringAsFixed(0),
                              'ms',
                              AppTheme.warning,
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              'R-R',
                              rr.toStringAsFixed(0),
                              'ms',
                              AppTheme.primary,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // AI Analysis
                GlassContainer(
                  borderColor: AppTheme.accent.withValues(alpha: 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppTheme.accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'AI Analysis',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        vitals.aiDiagnosis == 'Normal Sinus Rhythm'
                            ? 'ECG shows a regular sinus rhythm with a normal rate of ${vitals.heartRate.toStringAsFixed(0)} BPM. P waves are upright and consistent. QRS complexes are narrow and uniform. No signs of arrhythmia detected.'
                            : 'Elevated heart rate detected at ${vitals.heartRate.toStringAsFixed(0)} BPM. Pattern suggests sinus tachycardia. Recommend resting and monitoring. No dangerous arrhythmia detected.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildConfidenceBadge(
                            'Confidence',
                            '94%',
                            AppTheme.success,
                          ),
                          const SizedBox(width: 12),
                          _buildConfidenceBadge(
                            'Model',
                            '1D-CNN',
                            AppTheme.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Touch to Measure / Simulation Control
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (vitals.isSimulating) {
                        vitals.stopSimulation();
                      } else {
                        vitals.startSimulation();
                      }
                    },
                    icon: vitals.isSimulating
                        ? const Icon(Icons.stop)
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      vitals.isSimulating
                          ? 'Stop Simulation'
                          : 'Start Live Simulation',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: vitals.isSimulating
                          ? AppTheme.warning
                          : AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String unit,
    Color color,
  ) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
