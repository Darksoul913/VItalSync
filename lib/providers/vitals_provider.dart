import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/vital_reading.dart';
import '../models/alert.dart';
import '../models/patient.dart';
import '../config/constants.dart';
import '../services/arrhythmia_service.dart';
import '../services/tts_service.dart';
import '../services/realtime_db_service.dart';
import '../services/sos_service.dart';
import '../services/vitals_history_service.dart';
import '../services/critical_alert_service.dart';

class VitalsProvider extends ChangeNotifier {
  VitalReading _currentReading = VitalReading.mock();
  final List<VitalReading> _history = [];
  final List<HealthAlert> _alerts = [];
  bool _isSimulating = false;
  bool _deviceConnected = false;
  bool _fallSosTriggered = false;

  // TTS Service
  final TtsService _ttsService = TtsService();

  // SOS Service for auto-SMS and auto-call
  final SosService _sosService = SosService();
  List<EmergencyContact> _emergencyContacts = [];
  DateTime? _lastAutoSmsTime;

  // Critical Alert Service — sustained critical tracking
  final CriticalAlertService _criticalAlertService = CriticalAlertService();
  bool _autoEmergencyDialogPending = false;

  // Firestore history service
  final VitalsHistoryService _historyService = VitalsHistoryService();

  // Reference to current locale (from AuthProvider)
  String _currentLanguage = 'en';

  void updateLanguage(String newLang) {
    if (_currentLanguage != newLang) {
      _currentLanguage = newLang;
      _ttsService.setLanguage(newLang);
    }
  }

  /// Set emergency contacts for auto-SMS and auto-call alerts
  void setEmergencyContacts(List<EmergencyContact> contacts) {
    _emergencyContacts = contacts;
  }

  /// Legacy setter — backward compat
  void setEmergencyPhone(String? phone) {
    if (phone != null && phone.isNotEmpty) {
      // Only set if we don't already have contacts loaded
      if (_emergencyContacts.isEmpty) {
        _emergencyContacts = [
          EmergencyContact(
            name: 'Emergency',
            phone: phone,
            relation: 'Primary',
          ),
        ];
      }
    }
  }

  String _aiInsight =
      'Your heart rate has been stable today. Great cardiovascular health! 🎯';

  final ArrhythmiaService _arrhythmiaService = ArrhythmiaService();
  final List<double> _ecgBuffer = [];

  VitalsProvider() {
    _arrhythmiaService.init();
  }

  // ─── Getters ─────────────────────────────────────────────
  VitalReading get currentReading => _currentReading;
  List<VitalReading> get history => List.unmodifiable(_history);
  List<HealthAlert> get alerts => List.unmodifiable(_alerts);
  bool get isSimulating => _isSimulating;
  bool get deviceConnected => _deviceConnected;
  bool get fallSosTriggered => _fallSosTriggered;
  String get aiInsight => _aiInsight;

  double get heartRate => _currentReading.heartRate;
  double get spo2 => _currentReading.spo2;
  double get temperature => _currentReading.temperature;
  double get systolic => _currentReading.bpSystolic;
  double get diastolic => _currentReading.bpDiastolic;
  List<double> get ecgSamples => _currentReading.ecgSamples;
  bool get fallDetected => _currentReading.fallDetected;
  String? get aiDiagnosis => _currentReading.aiDiagnosis;

  // ─── Auto-Emergency Getters ─────────────────────────────
  bool get autoEmergencyDialogPending => _autoEmergencyDialogPending;
  CriticalAlertService get criticalAlertService => _criticalAlertService;
  List<EmergencyContact> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);

  /// Clear the auto-emergency pending flag (user dismissed / cancelled)
  void clearAutoEmergencyPending() {
    _autoEmergencyDialogPending = false;
    _criticalAlertService.resetEmergency();
    notifyListeners();
  }

  /// Execute the auto-emergency (call + SMS all contacts)
  Future<void> executeAutoEmergency() async {
    if (_emergencyContacts.isEmpty) {
      debugPrint('🚨 Auto-emergency: No emergency contacts configured');
      _autoEmergencyDialogPending = false;
      notifyListeners();
      return;
    }

    final summary = _criticalAlertService.getEmergencySummary(_currentReading);
    await _sosService.triggerAutoEmergency(
      contacts: _emergencyContacts,
      emergencySummary: summary,
    );

    _autoEmergencyDialogPending = false;
    notifyListeners();
  }

  // ─── Vital Status Helpers ────────────────────────────────
  String get hrStatus => _getStatus(
    heartRate,
    low: AppConstants.hrLow,
    high: AppConstants.hrHigh,
    critical: AppConstants.hrCritical,
  );

  String get spo2Status {
    if (spo2 < AppConstants.spo2Critical) return 'Critical';
    if (spo2 < AppConstants.spo2Low) return 'Low';
    return 'Normal';
  }

  String get tempStatus => _getStatus(
    temperature,
    low: AppConstants.tempLow,
    high: AppConstants.tempHigh,
    critical: AppConstants.tempCritical,
  );

  String get bpStatus {
    if (systolic > 180 || diastolic > 120) return 'Critical';
    if (systolic > 140 || diastolic > 90) return 'High';
    if (systolic < 90 || diastolic < 60) return 'Low';
    return 'Normal';
  }

  String get overallStatus {
    final statuses = [hrStatus, spo2Status, tempStatus, bpStatus];
    if (statuses.contains('Critical')) return 'Critical';
    if (statuses.contains('High') || statuses.contains('Low')) return 'Warning';
    return 'Normal';
  }

  String _getStatus(
    double value, {
    required double low,
    required double high,
    required double critical,
  }) {
    if (value >= critical) return 'Critical';
    if (value > high) return 'High';
    if (value < low) return 'Low';
    return 'Normal';
  }

  // ─── Realtime Database Connection ─────────────────────────
  final RealtimeDbService _dbService = RealtimeDbService();
  StreamSubscription<VitalReading?>? _vitalsSubscription;
  Timer? _simulationTimer;
  Timer? _stalenessTimer;
  DateTime? _lastRtdbUpdate;
  bool _isLive = false;
  String _patientId = 'demo-user';

  static const int _staleThresholdSecs = 6; // Switch to sim if no data for 6s
  static const int _simIntervalMs = 2000; // Simulation tick every 2s

  bool get isLive => _isLive;
  String get patientId => _patientId;

  /// Set the patient ID for RTDB subscription (call with Firebase Auth UID)
  void setPatientId(String id) {
    _patientId = id;
  }

  void startSimulation() {
    if (_isSimulating) return;
    _isSimulating = true;
    _deviceConnected = true;
    notifyListeners();

    // 1. Subscribe to RTDB for live data
    _vitalsSubscription?.cancel();
    _vitalsSubscription = _dbService
        .streamPatientVitals(_patientId)
        .listen(
          (reading) {
            if (reading != null) {
              _lastRtdbUpdate = DateTime.now();

              // Got live data — stop simulation if running
              if (!_isLive) {
                _isLive = true;
                _simulationTimer?.cancel();
                _simulationTimer = null;
                debugPrint('📡 Switched to LIVE data from MongoDB');
              }

              _processLiveReading(reading);
            }
          },
          onError: (e) {
            debugPrint('RTDB stream error: $e');
          },
        );

    // 2. Start staleness checker — checks every 5s if RTDB data is fresh
    _stalenessTimer?.cancel();
    _stalenessTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkStaleness(),
    );

    // 3. Start simulation immediately (until RTDB data arrives)
    _startSimulationFallback();
  }

  void _checkStaleness() {
    if (_lastRtdbUpdate == null)
      return; // Never received RTDB data, sim is already running

    final staleSecs = DateTime.now().difference(_lastRtdbUpdate!).inSeconds;
    if (staleSecs > _staleThresholdSecs && _isLive) {
      // RTDB went stale → switch to simulation
      _isLive = false;
      debugPrint('⚠️ RTDB stale (${staleSecs}s) — switching to simulation');
      _startSimulationFallback();
      notifyListeners();
    }
  }

  void _startSimulationFallback() {
    if (_simulationTimer != null) return; // Already running
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: _simIntervalMs),
      (_) => _simulateReading(),
    );
  }

  void stopSimulation() {
    _vitalsSubscription?.cancel();
    _simulationTimer?.cancel();
    _stalenessTimer?.cancel();
    _simulationTimer = null;
    _stalenessTimer = null;
    _isSimulating = false;
    _isLive = false;
    _deviceConnected = false;
    _criticalAlertService.resetAll();
    notifyListeners();
  }

  // ─── Simulation Fallback ────────────────────────────────
  void _simulateReading() {
    final r = Random();
    final simulated = VitalReading(
      heartRate: 68 + r.nextDouble() * 20,
      spo2: 95 + r.nextDouble() * 4,
      temperature: 36.2 + r.nextDouble() * 1.2,
      bpSystolic: 110 + r.nextDouble() * 25,
      bpDiastolic: 70 + r.nextDouble() * 15,
      fallDetected: false,
      ecgSamples: List.generate(10, (_) => r.nextDouble() * 0.8 - 0.4),
      timestamp: DateTime.now(),
      aiDiagnosis: 'Normal Sinus Rhythm',
    );
    _processLiveReading(simulated);
  }

  // ─── RTDB Data Processor ─────────────────────────────────
  void _processLiveReading(VitalReading incomingData) {
    // If the data payload from Firebase has ECG data, process it for ML
    if (incomingData.ecgSamples.isNotEmpty) {
      _ecgBuffer.addAll(incomingData.ecgSamples);
      if (_ecgBuffer.length > 750) {
        _ecgBuffer.removeRange(0, _ecgBuffer.length - 375);
      }
    }

    String diagnosis = incomingData.aiDiagnosis ?? 'Normal Sinus Rhythm';

    // Run ML inference on the buffer if we have enough samples (ESP32 may or may not do this itself)
    if (_ecgBuffer.length >= 375 && _arrhythmiaService.isReady) {
      final prediction = _arrhythmiaService.predict(_ecgBuffer);
      if (prediction != null) {
        diagnosis = prediction['label'] as String;

        int classIndex = prediction['classIndex'] as int;
        double confidence = prediction['confidence'] as double;

        if (classIndex > 0 && confidence > 0.6) {
          bool recentAlert = _alerts.any(
            (a) =>
                a.alertCode == 'ALERT_ARRHYTHMIA' &&
                DateTime.now().difference(a.timestamp).inSeconds < 30,
          );

          if (!recentAlert) {
            _addAlert(
              'ALERT_ARRHYTHMIA',
              'Arrhythmia Detected ($diagnosis)',
              'critical',
              confidence,
            );
          }
        }
      }
    }

    // Update the app state with the live data directly from Firebase
    _currentReading = incomingData.copyWith(
      ecgSamples: List.from(_ecgBuffer),
      aiDiagnosis: diagnosis,
      timestamp: DateTime.now(),
    );

    _history.insert(0, _currentReading);
    if (_history.length > 200) _history.removeLast();

    // Check thresholds and generate alerts based on the real data
    _checkAlerts(
      incomingData.heartRate,
      incomingData.spo2,
      incomingData.temperature,
      incomingData.bpSystolic,
    );

    // ── Sustained critical check for auto-emergency ──
    final shouldTrigger = _criticalAlertService.checkReading(incomingData);
    if (shouldTrigger && !_autoEmergencyDialogPending) {
      _autoEmergencyDialogPending = true;
      debugPrint(
        '🚨 Auto-emergency dialog pending — vitals sustained critical',
      );
    }

    _updateInsight(
      incomingData.heartRate,
      incomingData.spo2,
      incomingData.temperature,
    );

    notifyListeners();
    // Note: historical storage is handled automatically by FastAPI
    // when the ESP8266 POSTs to /api/v1/vitals — no duplicate save needed here.
  }

  // ─── Utility Methods ─────────────────────────────────────
  void _checkAlerts(double hr, double spo2, double temp, double systolic) {
    if (hr > AppConstants.hrCritical) {
      _addAlert(
        'ALERT_HR_CRITICAL',
        'Heart rate critically high: ${hr.toInt()} BPM',
        'critical',
        hr,
      );
    } else if (hr > AppConstants.hrHigh) {
      _addAlert(
        'ALERT_HR_HIGH',
        'Heart rate elevated: ${hr.toInt()} BPM',
        'warning',
        hr,
      );
    }

    if (spo2 < AppConstants.spo2Critical) {
      _addAlert(
        'ALERT_SPO2_LOW',
        'SpO2 critically low: ${spo2.toInt()}%',
        'critical',
        spo2,
      );
    }

    if (temp > AppConstants.tempCritical) {
      _addAlert(
        'ALERT_TEMP_HIGH',
        'Temperature critically high: ${temp.toStringAsFixed(1)}°C',
        'critical',
        temp,
      );
    }

    if (_currentReading.fallDetected) {
      _addAlert('ALERT_FALL', 'Fall detected! Are you okay?', 'critical', 0);
      _fallSosTriggered = true;
    }
  }

  void _addAlert(String code, String message, String severity, double value) {
    if (_alerts.any((a) => a.alertCode == code && !a.acknowledged)) return;

    final alert = HealthAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: _patientId,
      alertCode: code,
      message: message,
      severity: severity,
      vitalSnapshot: _currentReading.toMap(),
      timestamp: DateTime.now(),
      acknowledged: false,
    );
    _alerts.insert(0, alert);
    if (_alerts.length > 50) _alerts.removeLast();

    // Trigger voice alert
    _ttsService.speakAlert(code);

    // Auto-send SMS for critical alerts (instant single SMS — separate from sustained auto-emergency)
    if (severity == 'critical' && _emergencyContacts.isNotEmpty) {
      final primaryPhone = _emergencyContacts.first.phone;
      if (primaryPhone.isNotEmpty) {
        final now = DateTime.now();
        // Throttle: max 1 SMS per 60 seconds
        if (_lastAutoSmsTime == null ||
            now.difference(_lastAutoSmsTime!).inSeconds > 60) {
          _lastAutoSmsTime = now;
          _sosService.autoAlertSms(
            phone: primaryPhone,
            alertCode: code,
            alertMessage: message,
            vitalValue: value,
          );
        }
      }
    }
  }

  void acknowledgeAlert(String alertId) {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      final old = _alerts[idx];
      _alerts[idx] = HealthAlert(
        id: old.id,
        patientId: old.patientId,
        alertCode: old.alertCode,
        message: old.message,
        severity: old.severity,
        vitalSnapshot: old.vitalSnapshot,
        timestamp: old.timestamp,
        acknowledged: true,
      );
      notifyListeners();
    }
  }

  /// Clear the fall SOS trigger (called when user dismisses the dialog)
  void clearFallSos() {
    _fallSosTriggered = false;
    notifyListeners();
  }

  void _updateInsight(double hr, double spo2, double temp) {
    if (hr > 100) {
      _aiInsight =
          'Your heart rate is elevated at ${hr.toInt()} BPM. Consider resting and taking deep breaths. 💛';
    } else if (spo2 < 95) {
      _aiInsight =
          'SpO2 is at ${spo2.toInt()}%. Practice deep breathing exercises. 🫁';
    } else if (temp > 37.5) {
      _aiInsight =
          'Temperature is slightly elevated at ${temp.toStringAsFixed(1)}°C. Stay hydrated! 🌡️';
    } else {
      _aiInsight =
          'All vitals are within normal range. You\'re doing great! Keep it up! 💚';
    }
  }

  // ─── History Helpers ─────────────────────────────────────
  List<VitalReading> getTimeRangeHistory(Duration range) {
    final cutoff = DateTime.now().subtract(range);
    return _history.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  Map<String, double> getVitalStats(String vital) {
    if (_history.isEmpty) {
      return {'avg': 0, 'min': 0, 'max': 0};
    }

    final values = _history.map((r) {
      switch (vital) {
        case 'Heart Rate':
          return r.heartRate;
        case 'SpO2':
          return r.spo2;
        case 'Temperature':
          return r.temperature;
        case 'Blood Pressure':
          return r.bpSystolic;
        default:
          return r.heartRate;
      }
    }).toList();

    return {
      'avg': values.reduce((a, b) => a + b) / values.length,
      'min': values.reduce(min),
      'max': values.reduce(max),
    };
  }

  @override
  void dispose() {
    _vitalsSubscription?.cancel();
    _simulationTimer?.cancel();
    _stalenessTimer?.cancel();
    super.dispose();
  }
}
