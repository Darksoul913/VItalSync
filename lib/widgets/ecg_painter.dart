import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class EcgPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final double strokeWidth;
  final double animationOffset;

  EcgPainter({
    required this.samples,
    this.color = AppTheme.ecgColor,
    this.strokeWidth = 2.0,
    this.animationOffset = 0.0,
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

    // Show 3 cycles on screen for better readability, typical of medical monitors
    final visibleCycles = 3.0;
    final xStep = size.width / (samples.length * visibleCycles);

    // Force the vertical baseline (0) to always be exactly in the middle of the graph.
    // The ESP8266 generates values that are mostly positive (peaks ~500) and slightly negative.
    double maxAbs = samples.fold<double>(0, (max, val) => val.abs() > max ? val.abs() : max);
    // Add a bit of padding so spikes don't touch the very edge
    final range = (maxAbs * 1.5).clamp(100.0, double.infinity); 

    // Draw enough points to fill the screen + 1 extra cycle for smooth scrolling off-screen buffer
    final pointsNeeded = (samples.length * visibleCycles).ceil() + samples.length;
    
    for (int i = 0; i < pointsNeeded; i++) {
      // Loop the samples array indefinitely
      final sampleIndex = i % samples.length;
      
      // Calculate X coordinate, shifted left by the animation offset
      final x = (i * xStep) - (animationOffset * xStep);
      
      // Skip points deeply off-screen left, but draw points near the edge to prevent clipping artifacts
      if (x < - (samples.length * xStep)) continue;

      final y = midY - (samples[sampleIndex] / range) * (size.height / 2);

      if (i == 0) { 
        // First point drawn
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
      
      // Stop drawing once we pass the right edge of the screen
      if (x > size.width) break;
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
    return oldDelegate.samples != samples || oldDelegate.animationOffset != animationOffset;
  }
}

/// Widget that wraps ECG painter with smooth streaming animation
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

class _EcgWaveformState extends State<EcgWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1.5-second animation for a very steady, readable sweep speed
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _controller.repeat();
  }

  @override
  void didUpdateWidget(EcgWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.samples != oldWidget.samples) {
      // Intentionally DO NOT reset controller! Let it loop infinitely through the new array for seamless stream!
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // The animation loops from 0.0 to 1.0 over 1.5 seconds.
            // When it reaches 1.0, we want it to have visually scrolled exactly one full array length (e.g., 100 points).
            final offset = _controller.value * widget.samples.length;
            
            return CustomPaint(
              painter: EcgPainter(
                samples: widget.samples.isNotEmpty ? widget.samples : [0.0, 0.0],
                color: widget.color,
                animationOffset: offset,
              ),
              size: Size.infinite,
            );
          },
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
