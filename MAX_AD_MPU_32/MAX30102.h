#ifndef MAX30102_H
#define MAX30102_H

#include <Arduino.h>
#include <Wire.h>
#include "MAX30105.h"

class MAX30102_Sensor {
public:
    bool begin(TwoWire &w, uint8_t sda, uint8_t scl);
    void update();

    float   getHeartRate();
    float   getSpO2();
    float   getIBI();
    bool    fingerPresent();

    // Accessors for main sketch diagnostics
    long    getRawIR();
    long    getRawRed();
    float   getDcIR();
    float   getDcRed();
    float   getAcIR();
    float   getAcRed();
    bool    peakOccurred();
    uint8_t getSignalQuality();

private:
    MAX30105 sensor;

    bool  finger = false;
    float hr   = NAN;
    float spo2 = NAN;
    float ibi  = NAN;

    long  lastRawIR  = 0;
    long  lastRawRed = 0;

    // Sampling
    unsigned long lastSample    = 0;
    unsigned long sampleInterval = 10;  // 100 Hz

    // LED power
    uint8_t ledRed = 0x30;
    uint8_t ledIR  = 0x30;
    void autoCalibrate();

    // DC removal — from working sketch (alpha=0.01)
    float dcIR  = 0;
    const float alpha = 0.01f;

    // Peak detection state — from working sketch
    float prevIR     = 0;
    float prevPrevIR = 0;
    float dynThr     = 0;

    unsigned long lastPeakMs = 0;
    bool peakFlag = false;
};

#endif
