import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class EcgPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final double strokeWidth;

  EcgPainter({
    required this.samples,
    this.color = AppTheme.ecgColor,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) {
      _drawFlatLine(canvas, size);
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final glowPath = Path();
    final midY = size.height / 2;

    final xStep = size.width / (samples.length - 1);

    // Normalize samples
    double maxVal = samples.reduce(max);
    double minVal = samples.reduce(min);
    final range = (maxVal - minVal).clamp(0.1, double.infinity);

    for (int i = 0; i < samples.length; i++) {
      final x = i * xStep;
      final normalized = (samples[i] - minVal) / range;
      final y = midY - (normalized - 0.5) * size.height * 0.8;

      if (i == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
    }

    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(path, paint);

    // Grid lines
    _drawGrid(canvas, size);
  }

  void _drawFlatLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    _drawGrid(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.surfaceLight.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines
    for (int i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EcgPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

/// Widget that wraps ECG painter with animation
class EcgWaveform extends StatefulWidget {
  final List<double> samples;
  final double height;
  final Color color;

  const EcgWaveform({
    super.key,
    required this.samples,
    this.height = 200,
    this.color = AppTheme.ecgColor,
  });

  @override
  State<EcgWaveform> createState() => _EcgWaveformState();
}

class _EcgWaveformState extends State<EcgWaveform> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: CustomPaint(
          painter: EcgPainter(samples: widget.samples, color: widget.color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Generate a realistic mock ECG waveform (PQRST)
List<double> generateMockEcg({int beats = 3, int samplesPerBeat = 100}) {
  final samples = <double>[];
  final rng = Random(42);

  for (int beat = 0; beat < beats; beat++) {
    for (int i = 0; i < samplesPerBeat; i++) {
      final t = i / samplesPerBeat;
      double v = 0;

      // P wave
      if (t > 0.05 && t < 0.15) {
        v = 0.15 * sin((t - 0.05) * pi / 0.10);
      }
      // Q wave
      else if (t > 0.18 && t < 0.22) {
        v = -0.1 * sin((t - 0.18) * pi / 0.04);
      }
      // R wave (tall spike)
      else if (t > 0.22 && t < 0.30) {
        v = 1.0 * sin((t - 0.22) * pi / 0.08);
      }
      // S wave
      else if (t > 0.30 && t < 0.35) {
        v = -0.2 * sin((t - 0.30) * pi / 0.05);
      }
      // T wave
      else if (t > 0.45 && t < 0.60) {
        v = 0.25 * sin((t - 0.45) * pi / 0.15);
      }

      // Add subtle noise
      v += (rng.nextDouble() - 0.5) * 0.02;
      samples.add(v);
    }
  }

  return samples;
}
