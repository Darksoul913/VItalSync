import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/vitals_provider.dart';
import '../../widgets/glass_container.dart';

class VitalsDetailScreen extends StatefulWidget {
  const VitalsDetailScreen({super.key});

  @override
  State<VitalsDetailScreen> createState() => _VitalsDetailScreenState();
}

class _VitalsDetailScreenState extends State<VitalsDetailScreen> {
  String _selectedVital = 'Heart Rate';
  String _selectedPeriod = 'Today';

  final Map<String, Color> _vitalColors = {
    'Heart Rate': AppTheme.heartRateColor,
    'SpO2': AppTheme.spo2Color,
    'Temperature': AppTheme.temperatureColor,
    'Blood Pressure': AppTheme.bpColor,
  };

  final Map<String, String> _vitalUnits = {
    'Heart Rate': 'BPM',
    'SpO2': '%',
    'Temperature': '°C',
    'Blood Pressure': 'mmHg',
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, vitals, _) {
        final stats = vitals.getVitalStats(_selectedVital);
        return Scaffold(
          appBar: AppBar(title: const Text('Vitals History')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVitalSelector(),
                const SizedBox(height: 16),
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                _buildChart(vitals),
                const SizedBox(height: 20),
                _buildStatsSummary(stats),
                const SizedBox(height: 20),
                _buildReadingHistory(vitals),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVitalSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _vitalColors.entries.map((e) {
          final selected = _selectedVital == e.key;
          return GestureDetector(
            onTap: () => setState(() => _selectedVital = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? e.value.withValues(alpha: 0.15)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? e.value : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                e.key,
                style: TextStyle(
                  color: selected ? e.value : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: ['Today', 'Week', 'Month'].map((period) {
        final selected = _selectedPeriod == period;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : AppTheme.card,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                period,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChart(VitalsProvider vitals) {
    final color = _vitalColors[_selectedVital]!;
    final history = vitals.history;

    // Build chart spots from live history
    final spots = <FlSpot>[];
    final count = history.length.clamp(0, 10);
    for (int i = 0; i < count; i++) {
      final r = history[count - 1 - i];
      double val;
      switch (_selectedVital) {
        case 'SpO2':
          val = r.spo2;
          break;
        case 'Temperature':
          val = r.temperature;
          break;
        case 'Blood Pressure':
          val = r.bpSystolic;
          break;
        default:
          val = r.heartRate;
      }
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 72));
    }

    // Dynamic min/max for Y axis
    double minY, maxY;
    switch (_selectedVital) {
      case 'SpO2':
        minY = 88;
        maxY = 102;
        break;
      case 'Temperature':
        minY = 35;
        maxY = 39;
        break;
      case 'Blood Pressure':
        minY = 80;
        maxY = 160;
        break;
      default:
        minY = 50;
        maxY = 120;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 5,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: AppTheme.surfaceLight, strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 3,
                        color: color,
                        strokeWidth: 0,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            minY: minY,
            maxY: maxY,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(Map<String, double> stats) {
    final color = _vitalColors[_selectedVital]!;
    final unit = _vitalUnits[_selectedVital]!;
    final isTemp = _selectedVital == 'Temperature';

    return Row(
      children: [
        _buildStatItem(
          'Average',
          isTemp
              ? stats['avg']!.toStringAsFixed(1)
              : stats['avg']!.toStringAsFixed(0),
          unit,
          color,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          'Min',
          isTemp
              ? stats['min']!.toStringAsFixed(1)
              : stats['min']!.toStringAsFixed(0),
          unit,
          AppTheme.info,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          'Max',
          isTemp
              ? stats['max']!.toStringAsFixed(1)
              : stats['max']!.toStringAsFixed(0),
          unit,
          AppTheme.warning,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingHistory(VitalsProvider vitals) {
    final history = vitals.history.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Readings',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Waiting for data...',
                style: TextStyle(color: AppTheme.textHint),
              ),
            ),
          )
        else
          ...history.map((r) {
            String value;
            IconData icon;
            Color color;

            switch (_selectedVital) {
              case 'SpO2':
                value = '${r.spo2.toStringAsFixed(0)}%';
                icon = Icons.water_drop;
                color = AppTheme.spo2Color;
                break;
              case 'Temperature':
                value = '${r.temperature.toStringAsFixed(1)}°C';
                icon = Icons.thermostat;
                color = AppTheme.temperatureColor;
                break;
              case 'Blood Pressure':
                value =
                    '${r.bpSystolic.toStringAsFixed(0)}/${r.bpDiastolic.toStringAsFixed(0)} mmHg';
                icon = Icons.speed;
                color = AppTheme.bpColor;
                break;
              default:
                value = '${r.heartRate.toStringAsFixed(0)} BPM';
                icon = Icons.favorite;
                color = AppTheme.heartRateColor;
            }

            final elapsed = DateTime.now().difference(r.timestamp);
            final timeStr = elapsed.inSeconds < 10
                ? 'Just now'
                : elapsed.inMinutes < 1
                ? '${elapsed.inSeconds}s ago'
                : '${elapsed.inMinutes}m ago';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
