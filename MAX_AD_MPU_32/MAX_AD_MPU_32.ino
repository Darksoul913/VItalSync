#include <Wire.h>
#include "MAX30102.h"
#include "ClinicalValidator.h"
#include "ECG.h"
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>

// ==========================================
// ESP8266 PIN CONFIGURATION
// ==========================================
const int I2C_SDA_PIN = 4;  // GPIO 4 (D2 on NodeMCU)
const int I2C_SCL_PIN = 5;  // GPIO 5 (D1 on NodeMCU)

// ==========================================
// WiFi + Backend Configuration
// ==========================================
const char* WIFI_SSID   = "OP10Pro";       // <-- change this
const char* WIFI_PASS   = "12345678";    // <-- change this
const char* API_URL     = "https://vitalsync-backend-production-0418.up.railway.app/api/v1/vitals";
const char* PATIENT_ID  = "oR7dHQ5kmIMPsO7xY91F4RO6nGx2";

WiFiClientSecure wifiClient;

// --- Sensor Objects ---
MAX30102_Sensor particleSensor;
Adafruit_MPU6050 mpu;
ClinicalValidator clinicalValidator;

// --- Sensor Init Flags ---
bool mpuReady = false;

// MPU6050 Hardware Verification
const uint8_t WHO_AM_I_REG = 0x75;
const uint8_t EXPECTED_ID  = 0x68;

// --- Configuration ---
const unsigned long SAMPLE_RATE_MS = 10;  // 100Hz

// --- PPG / HR Variables ---
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
int  maxBeatAvg = 0;

// 1-Minute Rolling Average
const int  BPM_HISTORY_SIZE = 150;
byte       bpmHistory[BPM_HISTORY_SIZE];
unsigned long bpmTimestamps[BPM_HISTORY_SIZE];
int  bpmHistIdx = 0;
int  rollingBpmAvg1Min = 0;

float lastHr = 0;
bool  wasFingerOn = false;

// --- PTT & BP Variables ---
unsigned long lastRPeakTime = 0;
unsigned long ptt = 0;
bool  waitingForPPGPeak = false;
float sysBP = 0.0;
float diaBP = 0.0;

const float SYSTOLIC_A  = -0.3;
const float SYSTOLIC_B  = 135.0;
const float DIASTOLIC_A = -0.2;
const float DIASTOLIC_B = 90.0;

float sysCalibOffset = 0.0;
float diaCalibOffset = 0.0;

// --- IMU / Fall Detection ---
float lastTemp = 0;
unsigned long lastSampleTime = 0;

float cachedAccX = 0, cachedAccY = 0, cachedAccZ = 0;
float cachedTotalG = 0;

// --- ECG Waveform (generated from HR) ---
int16_t ecgBuf[ECG::SAMPLES];
char    ecgJson[ECG::SAMPLES * 5 + 8];
int     lastEcgHr = 0;

// ==========================================
// I2C Software Reset
// ==========================================
void i2c_reset() {
  pinMode(I2C_SDA_PIN, INPUT_PULLUP);
  pinMode(I2C_SCL_PIN, OUTPUT);
  for (int i = 0; i < 9; i++) {
    digitalWrite(I2C_SCL_PIN, HIGH); delayMicroseconds(5);
    digitalWrite(I2C_SCL_PIN, LOW);  delayMicroseconds(5);
  }
  pinMode(I2C_SDA_PIN, INPUT);
  pinMode(I2C_SCL_PIN, INPUT);
}

// ==========================================
// SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- VitalSync v3.0 ---");

  // Connect WiFi
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long wifiStart = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 15000) {
    delay(500); Serial.print("."); yield();
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\nWiFi connected. IP: "); Serial.println(WiFi.localIP());
    // Required for HTTPS requests to Railway without a certificate
    wifiClient.setInsecure();
  } else {
    Serial.println("\nWiFi failed — running offline (serial only)");
  }

  i2c_reset();
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setClock(100000);

  // Initialize MAX30102
  Serial.println("Initialising MAX30102...");
  if (!particleSensor.begin(Wire, I2C_SDA_PIN, I2C_SCL_PIN)) {
    Serial.println("MAX30102 not found!");
  } else {
    Serial.println("MAX30102 Online");
  }

  delay(500);

  // Initialize MPU6050
  Serial.println("Probing MPU6050...");
  uint8_t mpuAddr = 0;

  for (uint8_t addr = 0x68; addr <= 0x69; addr++) {
    Wire.beginTransmission(addr);
    Wire.write(WHO_AM_I_REG);
    byte error = Wire.endTransmission(false);
    if (error == 0) {
      Wire.requestFrom((uint8_t)addr, (uint8_t)1, (uint8_t)1);
      if (Wire.available() == 1) {
        byte identity = Wire.read();
        if (identity == EXPECTED_ID || identity == 0x70 || identity == 0x71 || identity == 0x73) {
          mpuAddr = addr;
          break;
        }
      }
    }
  }

  if (mpuAddr == 0) {
    Serial.println("MPU6050 not found!");
    mpuReady = false;
  } else {
    if (!mpu.begin(mpuAddr)) {
      Serial.println("MPU6050 Init Failed!");
      mpuReady = false;
    } else {
      mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
      mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
      mpuReady = true;
      Serial.println("MPU6050 Online");
    }
  }

  Serial.println("System Online");
}

// ==========================================
// MAIN LOOP
// ==========================================
void loop() {
  unsigned long currentTime = millis();

  // =============================================
  // 1. Update PPG Sensor
  // =============================================
  particleSensor.update();
  float hr   = particleSensor.getHeartRate();
  float spo2 = particleSensor.getSpO2();

  if (isnan(hr))   hr   = 0;
  if (isnan(spo2)) spo2 = 0;

  // Heart Rate Averaging + Finger State
  if (hr == 0 && spo2 == 0) {
    if (wasFingerOn) {
      wasFingerOn = false;
      maxBeatAvg = 0;
      rollingBpmAvg1Min = 0;
      lastHr = 0;
      sysBP = 0.0; diaBP = 0.0;
      for (byte x = 0; x < RATE_SIZE; x++) rates[x] = 0;
      for (int i = 0; i < BPM_HISTORY_SIZE; i++) {
        bpmHistory[i] = 0;
        bpmTimestamps[i] = 0;
      }
    }
  } else {
    wasFingerOn = true;

    if (hr > 30 && hr < 220 && hr != lastHr) {
      bool acceptable = !(lastHr > 30 && fabs(hr - lastHr) > 30);

      if (acceptable) {
        rates[rateSpot++] = (byte)constrain(hr, 30, 220);
        rateSpot %= RATE_SIZE;
        int tempSum = 0; byte validReadings = 0;
        for (byte x = 0; x < RATE_SIZE; x++) {
          if (rates[x] > 0) { tempSum += rates[x]; validReadings++; }
        }
        if (validReadings > 0) maxBeatAvg = tempSum / validReadings;

        bpmHistory[bpmHistIdx]    = (byte)constrain(hr, 30, 220);
        bpmTimestamps[bpmHistIdx] = currentTime;
        bpmHistIdx = (bpmHistIdx + 1) % BPM_HISTORY_SIZE;

        long rollingSum = 0; int rollingCount = 0;
        for (int i = 0; i < BPM_HISTORY_SIZE; i++) {
          if (bpmTimestamps[i] > 0 && (currentTime - bpmTimestamps[i] <= 60000)) {
            rollingSum += bpmHistory[i]; rollingCount++;
          } else if (bpmTimestamps[i] > 0 && (currentTime - bpmTimestamps[i] > 60000)) {
            bpmTimestamps[i] = 0; bpmHistory[i] = 0;
          }
        }
        if (rollingCount > 0) rollingBpmAvg1Min = rollingSum / rollingCount;

        lastHr = hr;
      }
    }
  }

  // =============================================
  // 2. IMU + BP (100Hz)
  // =============================================
  if (currentTime - lastSampleTime >= SAMPLE_RATE_MS) {
    lastSampleTime = currentTime;

    // IMU
    if (mpuReady) {
      sensors_event_t a, g, temp;
      mpu.getEvent(&a, &g, &temp);
      lastTemp   = temp.temperature;
      cachedAccX = a.acceleration.x;
      cachedAccY = a.acceleration.y;
      cachedAccZ = a.acceleration.z;
      cachedTotalG = sqrt(cachedAccX * cachedAccX +
                          cachedAccY * cachedAccY +
                          cachedAccZ * cachedAccZ) / 9.81;

      FallState fs = clinicalValidator.updateFallDetection(cachedTotalG, currentTime);
      if (fs == FALL_CONFIRMED) {
        Serial.println("FALL CONFIRMED!");
      }
    }

    // BP (Estimated from HR since physical ECG is removed and PTT is impossible)
    if (maxBeatAvg > 0) {
      // Baseline 115/75, shifting up/down based on how far HR is from 70
      sysBP = constrain(115.0 + ((maxBeatAvg - 70.0) * 0.45) + sysCalibOffset, 90.0, 180.0);
      diaBP = constrain( 75.0 + ((maxBeatAvg - 70.0) * 0.25) + diaCalibOffset, 60.0, 110.0);
    } else {
      sysBP = 0;
      diaBP = 0;
    }
  }

  // =============================================
  // 3. Telemetry (1 Hz)
  // =============================================
  static unsigned long lastPrintTime = 0;
  if (currentTime - lastPrintTime >= 1000) {
    lastPrintTime = currentTime;

    uint8_t ppgQuality = particleSensor.getSignalQuality();

    ValidatedReading hrResult   = clinicalValidator.validateHR(maxBeatAvg, ppgQuality);
    ValidatedReading spo2Result = clinicalValidator.validateSpO2(spo2, ppgQuality);
    ValidatedReading bpResult   = clinicalValidator.validateBP(sysBP, diaBP, ptt);

    uint8_t mc1     = (spo2Result.confidence < bpResult.confidence) ? spo2Result.confidence : bpResult.confidence;
    uint8_t minConf = (hrResult.confidence   < mc1)                 ? hrResult.confidence   : mc1;

    const char* overallQuality = "HIGH";
    if      (minConf < 30) overallQuality = "BAD";
    else if (minConf < 55) overallQuality = "LOW";
    else if (minConf < 80) overallQuality = "MED";

    FallState fs = clinicalValidator.getFallState();

    // Generate ECG waveform from HR (only when HR changes)
    if (maxBeatAvg > 0 && maxBeatAvg != lastEcgHr) {
      ECG::generateCycle((float)maxBeatAvg, ecgBuf);
      ECG::toJSONArray(ecgBuf, ecgJson, sizeof(ecgJson));
      lastEcgHr = maxBeatAvg;
    }

    // JSON with ECG field
    String json = clinicalValidator.toJSON(
        maxBeatAvg, hrResult.confidence,
        spo2, spo2Result.confidence,
        0, 0,                    // ecgBpm / ecgConf — no AD8232
        sysBP, diaBP, bpResult.confidence,
        lastTemp, fs, overallQuality
    );
    if (maxBeatAvg > 0 && ecgJson[0] != '\0') {
      json.remove(json.length() - 1);
      json += ",\"ecg\":";
      json += ecgJson;
      json += "}";
    }
    Serial.println(json);

    // POST to FastAPI backend → MongoDB (only when we have valid readings)
    if (WiFi.status() == WL_CONNECTED && maxBeatAvg > 0) {
      // Build the payload in the format FastAPI's VitalReading model expects
      String payload = "{";
      payload += "\"patient_id\":\"" + String(PATIENT_ID) + "\",";
      payload += "\"heart_rate\":" + String(maxBeatAvg) + ",";
      payload += "\"spo2\":" + String(spo2, 1) + ",";
      payload += "\"temperature\":" + String(lastTemp, 1) + ",";
      payload += "\"bp_systolic\":" + String(sysBP, 1) + ",";
      payload += "\"bp_diastolic\":" + String(diaBP, 1) + ",";
      payload += "\"fall_detected\":" + String(fs == FALL_CONFIRMED ? "true" : "false") + ",";
      // Include ECG array if generated
      payload += "\"ecg_samples\":";
      payload += (ecgJson[0] != '\0') ? String(ecgJson) : "[]";
      payload += "}";

      HTTPClient http;
      http.begin(wifiClient, API_URL);
      http.addHeader("Content-Type", "application/json");
      int code = http.POST(payload);
      if (code > 0) {
        Serial.print("POST "); Serial.println(code);  // 200 = stored OK
      } else {
        Serial.print("HTTP err: "); Serial.println(http.errorToString(code));
      }
      http.end();
    } else if (WiFi.status() != WL_CONNECTED) {
      // Auto-reconnect attempt (non-blocking)
      WiFi.reconnect();
    }

    // Human-readable summary
    Serial.print("VITALS -> ");
    Serial.print("HR:"); Serial.print(maxBeatAvg);
    Serial.print("["); Serial.print(hrResult.quality); Serial.print("]");
    Serial.print(" SpO2:"); Serial.print(spo2, 1); Serial.print("%");
    Serial.print("["); Serial.print(spo2Result.quality); Serial.print("]");
    Serial.print(" BP:"); Serial.print(sysBP, 0); Serial.print("/"); Serial.print(diaBP, 0);
    Serial.print("["); Serial.print(bpResult.quality); Serial.print("]");
    if (mpuReady) {
      Serial.print(" G:"); Serial.print(cachedTotalG, 2);
    }
    Serial.print(" T:"); Serial.print(lastTemp, 1);
    Serial.println();
  }

  yield();
}