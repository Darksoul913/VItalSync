import 'package:flutter/foundation.dart';
import '../models/vital_reading.dart';
import '../config/constants.dart';

/// Tracks how long each vital has been in critical state.
/// When any vital stays critical for the sustained duration, triggers auto-emergency.
class CriticalAlertService {
  // Per-vital critical start times (null = not critical)
  DateTime? _hrCriticalStart;
  DateTime? _spo2CriticalStart;
  DateTime? _tempCriticalStart;
  DateTime? _bpCriticalStart;

  // Cooldown tracking
  DateTime? _lastEmergencyTrigger;
  bool _emergencyTriggered = false;

  // Current critical state summary
  final Map<String, Duration> _criticalDurations = {};

  /// Whether auto-emergency was triggered and is active
  bool get emergencyTriggered => _emergencyTriggered;

  /// How many seconds until auto-emergency triggers (for the worst vital), or null if none critical
  int? get secondsUntilEmergency {
    if (_criticalDurations.isEmpty) return null;
    final maxDuration = _criticalDurations.values.reduce(
      (a, b) => a > b ? a : b,
    );
    final remaining =
        AppConstants.criticalSustainedDurationSecs - maxDuration.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Which vitals are currently critical and for how long
  Map<String, Duration> get criticalDurations =>
      Map.unmodifiable(_criticalDurations);

  /// Reset the emergency trigger (called after emergency is handled or cancelled)
  void resetEmergency() {
    _emergencyTriggered = false;
  }

  /// Reset all tracking (called when monitoring stops)
  void resetAll() {
    _hrCriticalStart = null;
    _spo2CriticalStart = null;
    _tempCriticalStart = null;
    _bpCriticalStart = null;
    _criticalDurations.clear();
    _emergencyTriggered = false;
  }

  /// Check a new reading and update critical duration tracking.
  /// Returns true if auto-emergency should be triggered NOW.
  bool checkReading(VitalReading reading) {
    final now = DateTime.now();
    _criticalDurations.clear();

    // ── Heart Rate ──
    if (reading.heartRate > AppConstants.hrCritical ||
        reading.heartRate < AppConstants.hrMin) {
      _hrCriticalStart ??= now;
      _criticalDurations['Heart Rate'] = now.difference(_hrCriticalStart!);
    } else {
      _hrCriticalStart = null;
    }

    // ── SpO2 ──
    if (reading.spo2 < AppConstants.spo2Critical) {
      _spo2CriticalStart ??= now;
      _criticalDurations['SpO2'] = now.difference(_spo2CriticalStart!);
    } else {
      _spo2CriticalStart = null;
    }

    // ── Temperature ──
    if (reading.temperature > AppConstants.tempCritical) {
      _tempCriticalStart ??= now;
      _criticalDurations['Temperature'] = now.difference(_tempCriticalStart!);
    } else {
      _tempCriticalStart = null;
    }

    // ── Blood Pressure ──
    if (reading.bpSystolic > AppConstants.bpSysCritical ||
        reading.bpDiastolic > AppConstants.bpDiaCritical) {
      _bpCriticalStart ??= now;
      _criticalDurations['Blood Pressure'] = now.difference(_bpCriticalStart!);
    } else {
      _bpCriticalStart = null;
    }

    // Check if any vital has been critical long enough
    return shouldTriggerEmergency();
  }

  /// Returns true if any vital has been critical for >= sustained duration
  /// AND cooldown has elapsed since last trigger.
  bool shouldTriggerEmergency() {
    if (_emergencyTriggered) return false;

    // Check cooldown
    if (_lastEmergencyTrigger != null) {
      final cooldownRemaining = DateTime.now()
          .difference(_lastEmergencyTrigger!)
          .inSeconds;
      if (cooldownRemaining < AppConstants.autoEmergencyCooldownSecs) {
        return false;
      }
    }

    // Check if any vital exceeded sustained duration
    for (final entry in _criticalDurations.entries) {
      if (entry.value.inSeconds >= AppConstants.criticalSustainedDurationSecs) {
        debugPrint(
          '🚨 CRITICAL SUSTAINED: ${entry.key} critical for '
          '${entry.value.inSeconds}s — triggering auto-emergency!',
        );
        _emergencyTriggered = true;
        _lastEmergencyTrigger = DateTime.now();
        return true;
      }
    }

    return false;
  }

  /// Build a human-readable summary of which vitals are critical (for SMS body)
  String getEmergencySummary(VitalReading reading) {
    final parts = <String>[];

    if (_criticalDurations.containsKey('Heart Rate')) {
      parts.add(
        'Heart Rate: ${reading.heartRate.toInt()} BPM '
        '(critical for ${_criticalDurations['Heart Rate']!.inSeconds}s)',
      );
    }
    if (_criticalDurations.containsKey('SpO2')) {
      parts.add(
        'SpO2: ${reading.spo2.toInt()}% '
        '(critical for ${_criticalDurations['SpO2']!.inSeconds}s)',
      );
    }
    if (_criticalDurations.containsKey('Temperature')) {
      parts.add(
        'Temperature: ${reading.temperature.toStringAsFixed(1)}°C '
        '(critical for ${_criticalDurations['Temperature']!.inSeconds}s)',
      );
    }
    if (_criticalDurations.containsKey('Blood Pressure')) {
      parts.add(
        'BP: ${reading.bpSystolic.toInt()}/${reading.bpDiastolic.toInt()} mmHg '
        '(critical for ${_criticalDurations['Blood Pressure']!.inSeconds}s)',
      );
    }

    if (parts.isEmpty) return 'Critical vitals detected.';

    return 'EMERGENCY — VitalSync Auto-Alert!\n'
        'Critical vitals sustained for extended period:\n'
        '${parts.join('\n')}\n'
        'Please check on the patient immediately!';
  }
}
