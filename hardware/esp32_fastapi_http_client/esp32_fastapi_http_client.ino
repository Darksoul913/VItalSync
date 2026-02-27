#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// --- WiFi Credentials ---
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// --- API Endpoint (Localhost / Dev Tunnel / Deployed URL) ---
// If running FastAPI locally, use your computer's local IP address (e.g., 192.168.1.X)
const char* serverUrl = "http://192.168.1.100:8000/api/v1/vitals";
const char* patientId = "demo-user";

// --- AD8232 ECG Pins for DOIT ESP32 DEVKIT V1 ---
const int PIN_ECG_OUTPUT = 34; // Analog input for ECG signal
const int PIN_LO_PLUS    = 32; // Leads Off + detection
const int PIN_LO_MINUS   = 33; // Leads Off - detection

// Sampling Variables
// Sampling at ~100Hz for the web app
const int sampleInterval_ms = 10; 
unsigned long lastSampleTime = 0;

// Batching Variables
// We buffer ECG samples to send them together rather than spamming HTTP requests
const int BATCH_SIZE = 100; // Sending 100 samples per request (~1 request/second)
int ecgBuffer[BATCH_SIZE];
int bufferIndex = 0;

void setup() {
  Serial.begin(115200);
  
  // Setup the digital Leads Off detection pins
  pinMode(PIN_LO_PLUS, INPUT);
  pinMode(PIN_LO_MINUS, INPUT);
  
  // Connect to WiFi
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected.");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastSampleTime >= sampleInterval_ms) {
    lastSampleTime = currentMillis;

    int currentEcgValue = 0;

    // Check if the pads have fallen off the body
    if (digitalRead(PIN_LO_PLUS) == 1 || digitalRead(PIN_LO_MINUS) == 1) {
      // Leads Off! Add a 0 value.
      currentEcgValue = 0;
    } else {
      // Leads are securely attached, read the analog ECG voltage (0 to 4095)
      currentEcgValue = analogRead(PIN_ECG_OUTPUT);
    }
    
    // Store in buffer
    ecgBuffer[bufferIndex] = currentEcgValue;
    bufferIndex++;

    // Once the buffer is full, send the HTTP POST request
    if (bufferIndex >= BATCH_SIZE) {
      sendTelemetryPayload();
      bufferIndex = 0; // Reset buffer
    }
  }
}

void sendTelemetryPayload() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    // Creating JSON payload using ArduinoJson
    StaticJsonDocument<2048> doc; 
    
    doc["patient_id"] = patientId;
    
    // In a real device, these would come from MAX30102 / MLX90614
    doc["heart_rate"] = random(70, 85); 
    doc["spo2"] = random(95, 100);
    doc["temperature"] = random(365, 375) / 10.0;
    doc["bp_systolic"] = 120;
    doc["bp_diastolic"] = 80;
    doc["fall_detected"] = false;

    // Attach the ECG buffer array
    JsonArray ecgArray = doc.createNestedArray("ecg_samples");
    for (int i = 0; i < BATCH_SIZE; i++) {
        // Normalizing the 0-4095 reading to a -1.0 to 1.0 float scale before sending
        float normalizedScale = (ecgBuffer[i] / 2048.0) - 1.0;
        ecgArray.add(normalizedScale);
    }

    String requestBody;
    serializeJson(doc, requestBody);

    // Send the POST request
    int httpResponseCode = http.POST(requestBody);

    if (httpResponseCode > 0) {
      Serial.print("HTTP POST successful. Response code: ");
      Serial.println(httpResponseCode);
    } else {
      Serial.print("Error sending POST request: ");
      Serial.println(httpResponseCode);
    }

    http.end(); // Free resources
  } else {
    Serial.println("Error: WiFi connection lost");
  }
}
