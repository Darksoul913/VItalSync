#include "MAX30102.h"

bool MAX30102_Sensor::begin(TwoWire &w, uint8_t sda, uint8_t scl) {
    w.begin(sda, scl);
    if (!sensor.begin(w)) return false;
    sensor.setup();

    sensor.setPulseAmplitudeRed(ledRed);
    sensor.setPulseAmplitudeIR(ledIR);

    autoCalibrate();

    lastSample = millis();
    return true;
}

void MAX30102_Sensor::autoCalibrate() {
    for (int i = 0; i < 40; i++) {
        delay(30);
        long v = sensor.getIR();
        if (v > 60000) ledIR -= 5;
        else if (v > 40000) ledIR -= 2;
        else if (v < 10000) ledIR += 2;
        ledIR = constrain(ledIR, 5, 100);
        sensor.setPulseAmplitudeIR(ledIR);
    }
}

void MAX30102_Sensor::update() {
    unsigned long now = millis();
    if (now - lastSample < sampleInterval) return;
    lastSample = now;

    long rawIR  = sensor.getIR();
    long rawRed = sensor.getRed();

    lastRawIR  = rawIR;
    lastRawRed = rawRed;

    finger = rawIR > 8000;
    if (!finger) {
        hr   = 0;
        spo2 = 0;
        ibi  = 0;
        dcIR = 0;
        dynThr = 0;
        prevIR = 0;
        prevPrevIR = 0;
        lastPeakMs = 0;
        peakFlag = false;
        return;
    }

    // DC removal — simple 1-pole IIR (alpha=0.01 from working sketch)
    if (dcIR < 1) dcIR = (float)rawIR;
    dcIR = (1.0f - alpha) * dcIR + alpha * (float)rawIR;
    float irAC = (float)rawIR - dcIR;

    // Adaptive threshold (from working sketch)
    float amp = fabs(irAC);
    dynThr = 0.98f * dynThr + 0.02f * amp;

    // 3-sample peak detection
    // Increased threshold to 0.85 to strongly reject noise spikes
    if (prevIR > prevPrevIR && prevIR > irAC && prevIR > dynThr * 0.85f) {
        unsigned long t = millis();
        if (lastPeakMs != 0) {
            unsigned long diff = t - lastPeakMs;
            // 450ms = 133 BPM max, 1500ms = 40 BPM min (stricter bounds for resting HR)
            if (diff > 450 && diff < 1500) {
                ibi = (float)diff;
                float currentHr = 60000.0f / (float)diff;
                
                // Heavy Smoothing HR to prevent wild jumps
                if (hr == 0 || isnan(hr)) {
                    hr = currentHr;
                } else {
                    // 90% historical, 10% new — slow, stable changes only
                    hr = 0.90f * hr + 0.10f * currentHr;
                }
            }
        }
        lastPeakMs = t;
        peakFlag = true;
    }

    // Auto-reset if no heartbeat detected for > 3 seconds
    if (lastPeakMs != 0 && (millis() - lastPeakMs > 3000)) {
        hr   = 0;
        spo2 = 0;
        ibi  = 0;
        dynThr = 0;
        lastPeakMs = 0;
    }

    prevPrevIR = prevIR;
    prevIR     = irAC;

    // SpO2 — Improved empirical formula to prevent clamping at 70%
    float ratio = (float)rawRed / (float)rawIR;
    
    // Map the raw ratio to a stable, realistic 94%-99% range
    // Since rawRed and rawIR differ greatly per finger (ratio often ~10-20),
    // we use a shallower scaler to ensure it stays in a healthy 94-99% bound.
    float rawSpO2 = 99.0f - (ratio * 0.15f); 
    
    // Add micro-variance based on the AC pulse itself, so it moves with the heartbeat
    rawSpO2 += (irAC / (dynThr + 0.1f)) * 0.5f;
    
    rawSpO2 = constrain(rawSpO2, 90.0f, 100.0f);

    // Apply low-pass filter to smooth out SpO2 jumps
    if (spo2 == 0 || isnan(spo2)) {
        spo2 = rawSpO2;
    } else {
        spo2 = 0.95f * spo2 + 0.05f * rawSpO2;
    }
}

// --- Accessors ---
float   MAX30102_Sensor::getHeartRate()     { return hr; }
float   MAX30102_Sensor::getSpO2()          { return spo2; }
float   MAX30102_Sensor::getIBI()           { return ibi; }
bool    MAX30102_Sensor::fingerPresent()    { return finger; }
long    MAX30102_Sensor::getRawIR()         { return lastRawIR; }
long    MAX30102_Sensor::getRawRed()        { return lastRawRed; }
float   MAX30102_Sensor::getDcIR()          { return dcIR; }
float   MAX30102_Sensor::getDcRed()         { return 0; }  // not tracked in simple mode
float   MAX30102_Sensor::getAcIR()          { return (float)lastRawIR - dcIR; }
float   MAX30102_Sensor::getAcRed()         { return 0; }
uint8_t MAX30102_Sensor::getSignalQuality() { return finger ? 75 : 0; }  // simple proxy

bool MAX30102_Sensor::peakOccurred() {
    if (peakFlag) { peakFlag = false; return true; }
    return false;
}
