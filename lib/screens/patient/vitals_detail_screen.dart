import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/vitals_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class VitalsDetailScreen extends StatefulWidget {
  const VitalsDetailScreen({super.key});

  @override
  State<VitalsDetailScreen> createState() => _VitalsDetailScreenState();
}

class _VitalsDetailScreenState extends State<VitalsDetailScreen> {
  final ApiService _api = ApiService();
  String _selectedVital = 'Heart Rate';
  String _selectedPeriod = 'Today';

  // MongoDB data
  List<Map<String, dynamic>> _timeSeriesData = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = false;

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

  final Map<String, String> _vitalApiNames = {
    'Heart Rate': 'heart_rate',
    'SpO2': 'spo2',
    'Temperature': 'temperature',
    'Blood Pressure': 'bp_systolic',
  };

  int get _periodHours {
    switch (_selectedPeriod) {
      case 'Week':
        return 168;
      case 'Month':
        return 720;
      default:
        return 24;
    }
  }

  int get _intervalMinutes {
    switch (_selectedPeriod) {
      case 'Week':
        return 60;
      case 'Month':
        return 360;
      default:
        return 5;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final patientId = auth.firebaseUser?.uid ?? 'demo-user';
    final vitalType = _vitalApiNames[_selectedVital] ?? 'heart_rate';

    // Fetch timeseries + analytics in parallel
    final results = await Future.wait([
      _api.getTimeSeries(
        patientId,
        vitalType,
        hours: _periodHours,
        intervalMinutes: _intervalMinutes,
      ),
      _api.getAnalytics(patientId, vitalType, periodHours: _periodHours),
    ]);

    if (mounted) {
      setState(() {
        final tsResult = results[0];
        _timeSeriesData =
            (tsResult?['data_points'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _analytics = results[1];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VitalsProvider>(
      builder: (context, vitals, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Vitals Analytics')),
          body: RefreshIndicator(
            onRefresh: _fetchData,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVitalSelector(),
                  const SizedBox(height: 16),
                  _buildPeriodSelector(),
                  const SizedBox(height: 20),
                  _buildChart(),
                  const SizedBox(height: 20),
                  _buildStatsSummary(),
                  const SizedBox(height: 20),
                  _buildTrendBadge(),
                  const SizedBox(height: 20),
                  _buildReadingCount(),
                ],
              ),
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
            onTap: () {
              setState(() => _selectedVital = e.key);
              _fetchData();
            },
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
            onTap: () {
              setState(() => _selectedPeriod = period);
              _fetchData();
            },
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

  Widget _buildChart() {
    final color = _vitalColors[_selectedVital]!;

    if (_isLoading) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: color, strokeWidth: 2),
          ),
        ),
      );
    }

    // Build chart spots from MongoDB time-series data
    final spots = <FlSpot>[];
    for (int i = 0; i < _timeSeriesData.length; i++) {
      final dp = _timeSeriesData[i];
      final val = (dp['value'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (spots.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.show_chart,
                  color: color.withValues(alpha: 0.3),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No data for this period',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vitals data will appear here once recorded',
                  style: TextStyle(
                    color: AppTheme.textHint.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Dynamic Y-axis range
    double minY, maxY;
    final allValues = spots.map((s) => s.y).toList();
    final dataMin = allValues.reduce((a, b) => a < b ? a : b);
    final dataMax = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (dataMax - dataMin) * 0.15;
    minY = (dataMin - padding).floorToDouble();
    maxY = (dataMax + padding).ceilToDouble();

    // Fallback ranges for specific vitals
    switch (_selectedVital) {
      case 'SpO2':
        minY = minY.clamp(85, 95);
        maxY = maxY.clamp(98, 105);
        break;
      case 'Temperature':
        minY = minY.clamp(34, 36);
        maxY = maxY.clamp(38, 42);
        break;
      default:
        break;
    }

    // Time labels
    String getTimeLabel(int index) {
      if (index < 0 || index >= _timeSeriesData.length) return '';
      final ts = _timeSeriesData[index]['timestamp'] as String?;
      if (ts == null) return '';
      try {
        final dt = DateTime.parse(ts);
        if (_selectedPeriod == 'Today') {
          return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else if (_selectedPeriod == 'Week') {
          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return days[dt.weekday - 1];
        } else {
          return '${dt.day}/${dt.month}';
        }
      } catch (_) {
        return '';
      }
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
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: (spots.length / 5).ceilToDouble().clamp(1, 100),
                  getTitlesWidget: (value, meta) {
                    final label = getTimeLabel(value.toInt());
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
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
                  show: spots.length <= 30,
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
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final label = getTimeLabel(spot.spotIndex);
                    final isTemp = _selectedVital == 'Temperature';
                    return LineTooltipItem(
                      '$label\n${isTemp ? spot.y.toStringAsFixed(1) : spot.y.toStringAsFixed(0)} ${_vitalUnits[_selectedVital]}',
                      TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            minY: minY,
            maxY: maxY,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final color = _vitalColors[_selectedVital]!;
    final unit = _vitalUnits[_selectedVital]!;
    final isTemp = _selectedVital == 'Temperature';

    final avg = (_analytics?['avg'] as num?)?.toDouble() ?? 0;
    final min = (_analytics?['min'] as num?)?.toDouble() ?? 0;
    final max = (_analytics?['max'] as num?)?.toDouble() ?? 0;

    if (_isLoading) {
      return Row(
        children: List.generate(
          3,
          (_) => Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        _buildStatItem(
          'Average',
          isTemp ? avg.toStringAsFixed(1) : avg.toStringAsFixed(0),
          unit,
          color,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          'Min',
          isTemp ? min.toStringAsFixed(1) : min.toStringAsFixed(0),
          unit,
          AppTheme.info,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          'Max',
          isTemp ? max.toStringAsFixed(1) : max.toStringAsFixed(0),
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

  Widget _buildTrendBadge() {
    final trend = _analytics?['trend'] ?? 'no_data';
    final count = (_analytics?['count'] as num?)?.toInt() ?? 0;

    IconData icon;
    Color color;
    String label;

    switch (trend) {
      case 'rising':
        icon = Icons.trending_up;
        color = AppTheme.warning;
        label = 'Rising Trend';
        break;
      case 'falling':
        icon = Icons.trending_down;
        color = AppTheme.info;
        label = 'Falling Trend';
        break;
      case 'stable':
        icon = Icons.trending_flat;
        color = AppTheme.success;
        label = 'Stable';
        break;
      default:
        icon = Icons.show_chart;
        color = AppTheme.textHint;
        label = count == 0 ? 'No Data' : 'Analyzing...';
    }

    return GlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Based on $count readings over $_selectedPeriod',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCount() {
    final count = (_analytics?['count'] as num?)?.toInt() ?? 0;
    final dataPoints = _timeSeriesData.length;

    return GlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storage, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count total readings',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$dataPoints data points on chart • Source: MongoDB',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
