class AppConstants {
  AppConstants._();

  // ─── App Info ──────────────────────────────────────────────
  static const String appName = 'VitalSync';
  static const String appTagline = 'Your AI-Powered Health Guardian';
  static const String appVersion = '1.0.0';

  // ─── Vital Thresholds ─────────────────────────────────────
  // Heart Rate (BPM)
  static const double hrLow = 50;
  static const double hrHigh = 95;
  static const double hrCritical = 150;
  static const double hrMin = 30;
  static const double hrMax = 200;

  // SpO2 (%)
  static const double spo2Low = 95;
  static const double spo2Critical = 90;
  static const double spo2Min = 70;
  static const double spo2Max = 100;

  // Temperature (°C)
  static const double tempLow = 35.0;
  static const double tempHigh = 38.0;
  static const double tempCritical = 39.5;
  static const double tempMin = 34.0;
  static const double tempMax = 42.0;

  // Blood Pressure (mmHg)
  static const double bpSysLow = 90;
  static const double bpSysHigh = 140;
  static const double bpSysCritical = 180;
  static const double bpDiaLow = 60;
  static const double bpDiaHigh = 90;
  static const double bpDiaCritical = 120;

  // ─── Alert Error Codes ─────────────────────────────────────
  static const String alertHrHigh = 'ALERT_HR_HIGH';
  static const String alertHrLow = 'ALERT_HR_LOW';
  static const String alertSpo2Low = 'ALERT_SPO2_LOW';
  static const String alertTempHigh = 'ALERT_TEMP_HIGH';
  static const String alertBpHigh = 'ALERT_BP_HIGH';
  static const String alertFall = 'ALERT_FALL';
  static const String alertArrhythmia = 'ALERT_ARRHYTHMIA';

  // ─── Auto-Emergency Thresholds ─────────────────────────────
  static const int criticalSustainedDurationSecs =
      30; // seconds of sustained critical before auto-call
  static const int autoEmergencyCooldownSecs =
      300; // 5-min cooldown between auto-emergency triggers
  static const int maxEmergencyContacts = 3;

  // ─── Supported Languages ───────────────────────────────────
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिंदी',
    'mr': 'मराठी',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'kn': 'ಕನ್ನಡ',
  };

  // ─── Data Pipeline ─────────────────────────────────────────
  static const int batchUploadIntervalMinutes = 15;
  static const int liveUpdateIntervalMs = 1000;
  static const int ecgSamplesPerPacket = 20;

  // ─── Firebase Paths ────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String vitalsCollection = 'vitals';
  static const String alertsCollection = 'alerts';
  static const String prescriptionsCollection = 'prescriptions';
  static const String liveVitalsPath = 'vitals';

  // ─── API ───────────────────────────────────────────────────
  static const String defaultApiBase = 'http://localhost:8000';
  // API keys — provide via --dart-define at build time
  // e.g.: flutter run --dart-define=GEMINI_API_KEY=your_key
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String sarvamApiKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: '',
  );
}
