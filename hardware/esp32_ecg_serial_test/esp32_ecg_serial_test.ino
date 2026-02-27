// --- AD8232 ECG Pins for DOIT ESP32 DEVKIT V1 ---
const int PIN_ECG_OUTPUT = 34; // Analog input for ECG signal
const int PIN_LO_PLUS    = 32; // Leads Off + detection
const int PIN_LO_MINUS   = 33; // Leads Off - detection

// Sampling Variables
// 125 Hz matching the ML Model input frequency
const int sampleInterval_ms = 8; 
unsigned long lastSampleTime = 0;

void setup() {
  // Start the serial port incredibly fast for smooth plotting
  Serial.begin(115200);
  
  // Setup the digital Leads Off detection pins
  pinMode(PIN_LO_PLUS, INPUT);
  pinMode(PIN_LO_MINUS, INPUT);
  
  Serial.println("Initialising AD8232 ECG Sensor Test...");
  delay(1000);
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastSampleTime >= sampleInterval_ms) {
    lastSampleTime = currentMillis;

    // Check if the pads have fallen off the body
    if (digitalRead(PIN_LO_PLUS) == 1 || digitalRead(PIN_LO_MINUS) == 1) {
      // Leads Off!
      // We print a flat line of 0 so the plotter doesn't go crazy
      Serial.println(0); 
    } 
    else {
      // Leads are securely attached, read the analog ECG voltage
      // ESP32's ADC runs from 0 to 4095
      int sensorValue = analogRead(PIN_ECG_OUTPUT);
      
      // Print the raw value to the Serial Plotter
      Serial.println(sensorValue);
    }
  }
}
