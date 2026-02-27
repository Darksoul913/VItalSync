#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --- UUIDs for the Custom VitalSync Service ---
#define SERVICE_UUID           "0000180D-0000-1000-8000-00805f9b34fb" 
#define CHARACTERISTIC_UUID_RX "00002A37-0000-1000-8000-00805f9b34fb" 

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("App Connected via Bluetooth!");
    };
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("App Disconnected...");
        pServer->startAdvertising(); 
    }
};

/*
 *  AD8232 ECG — Calibrated with Adaptive Baseline + BLE (ESP32)
 */

const int ECG_PIN  = 4;
const int LO_PLUS  = 19;
const int LO_MINUS = 18;

// ── Adaptive baseline (slowly follows drift) ────────────────────
float baseline = 0;
const float BASELINE_ALPHA = 0.001;  

// ── Filter ──────────────────────────────────────────────────────
const int FILTER_SIZE = 5;           
int  filterBuf[FILTER_SIZE];
int  filterIdx = 0;
long filterSum  = 0;

// ── BPM ─────────────────────────────────────────────────────────
int   peakThreshold = 20;
unsigned long lastPeakTime = 0;
bool  peakDetected  = false;
float bpm = 0.0;

void setup() {
  Serial.begin(115200);
  delay(10);

  pinMode(LO_PLUS,  INPUT);
  pinMode(LO_MINUS, INPUT);

  for (int i = 0; i < FILTER_SIZE; i++) filterBuf[i] = 0;

  Serial.println("AD8232 ECG — Calibrating...");

  // Quick baseline: average 500 samples (~1 sec)
  long sum = 0;
  for (int i = 0; i < 500; i++) {
    sum += analogRead(ECG_PIN);
    delay(2);
  }
  baseline = sum / 500.0;

  Serial.print("Baseline: ");
  Serial.println((int)baseline);
  
  // ── BLE Setup ─────────────────────────────────────────
  BLEDevice::init("VitalSync-ECG");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pTxCharacteristic = pService->createCharacteristic(
                                      CHARACTERISTIC_UUID_RX,
                                      BLECharacteristic::PROPERTY_NOTIFY
                                  );
  pTxCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("Bluetooth turned on! Waiting for app connection...");
  lastPeakTime = millis();
}

int applyFilter(int val) {
  filterSum -= filterBuf[filterIdx];
  filterBuf[filterIdx] = val;
  filterSum += val;
  filterIdx = (filterIdx + 1) % FILTER_SIZE;
  return (int)(filterSum / FILTER_SIZE);
}

void loop() {
  int raw = analogRead(ECG_PIN);

  // Centre around adaptive baseline
  int centred = raw - (int)baseline;

  // Slowly adapt baseline to follow drift
  baseline = baseline * (1.0 - BASELINE_ALPHA) + raw * BASELINE_ALPHA;

  // Light filter
  int filtered = applyFilter(centred);

  // ── R-Peak Detection ──────────────────────────────────────────
  unsigned long now = millis();
  if (filtered > peakThreshold && !peakDetected) {
    unsigned long interval = now - lastPeakTime;
    if (interval > 300) {
      bpm = 60000.0 / interval;
      lastPeakTime = now;
    }
    peakDetected = true;
  } else if (filtered < peakThreshold / 2) {
    peakDetected = false;
  }

  // ── Leads Off & BLE Transmission ──────────────────────────────
  bool leadsOff = (digitalRead(LO_PLUS) == 1 || digitalRead(LO_MINUS) == 1);

  if (deviceConnected) {
      if (leadsOff) {
          int32_t sensorValue = -999;
          pTxCharacteristic->setValue((uint8_t*)&sensorValue, 4);
          pTxCharacteristic->notify();
      } else {
          // Re-add the baseline so it remains in the 0-4095 range, giving the 
          // Flutter App a perfectly smoothed, drift-free wave to scale!
          int32_t sensorValue = filtered + (int)baseline; 
          pTxCharacteristic->setValue((uint8_t*)&sensorValue, 4);
          pTxCharacteristic->notify();
      }
  }

  // Handle connection state changes gracefully
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); 
      pServer->startAdvertising(); 
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }

  // ── Serial Plotter Output ─────────────────────────────────────
  if (leadsOff) {
      Serial.println(0); // Flatline plotter on leads off
  } else {
      Serial.print(raw);
      Serial.print(",");
      Serial.print(filtered);
      Serial.print(",");
      Serial.println((bpm > 30 && bpm < 220) ? (int)bpm : 0);
  }

  // Sample at roughly 125Hz to perfectly match the ML Model
  delay(8); 
}
