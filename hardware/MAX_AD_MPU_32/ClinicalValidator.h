#ifndef CLINICAL_VALIDATOR_H
#define CLINICAL_VALIDATOR_H

#include <Arduino.h>

// ==========================================
// Clinical Validation & Confidence Scoring
// ==========================================

// --- Validated Reading Result ---
struct ValidatedReading {
    float value;
    uint8_t confidence;   // 0–100
    char quality[5];      // "HIGH", "MED", "LOW", "BAD"
    bool inRange;
    char flag[16];        // Clinical flag string
};

// --- Fall Detection State Machine ---
enum FallState {
    FALL_IDLE = 0,
    FALL_FREEFALL,
    FALL_IMPACT,
    FALL_CONFIRMED
};

// --- Clinical Reference Ranges ---
struct ClinicalRange {
    float criticalLow;
    float warningLow;
    float normalLow;
    float normalHigh;
    float warningHigh;
    float criticalHigh;
};

class ClinicalValidator {
public:
    ClinicalValidator();

    // --- Vital Sign Validation ---
    ValidatedReading validateHR(float hr, uint8_t signalQuality);
    ValidatedReading validateSpO2(float spo2, uint8_t signalQuality);
    ValidatedReading validateECG(float ecgBpm, float ppgHr);
    ValidatedReading validateBP(float sys, float dia, unsigned long ptt);

    // --- Fall Detection (3-phase state machine) ---
    FallState updateFallDetection(float totalG, unsigned long currentTime);
    FallState getFallState();

    // --- Cross-validation ---
    uint8_t crossValidateHR(float ppgHr, float ecgBpm);

    // --- JSON Output ---
    String toJSON(
        float hr, uint8_t hrConf,
        float spo2, uint8_t spo2Conf,
        float ecgBpm, uint8_t ecgConf,
        float sysBP, float diaBP, uint8_t bpConf,
        float temp,
        FallState fallState,
        const char* overallQuality
    );

private:
    // Clinical ranges
    static const ClinicalRange hrRange;
    static const ClinicalRange spo2Range;
    static const ClinicalRange sysRange;
    static const ClinicalRange diaRange;

    // Fall detection state
    FallState fallState;
    unsigned long freefallStart;
    unsigned long impactStart;
    static const unsigned long FREEFALL_TIMEOUT_MS = 500;
    static const unsigned long INACTIVITY_PERIOD_MS = 2000;
    static constexpr float FREEFALL_THRESHOLD = 0.4;
    static constexpr float IMPACT_THRESHOLD = 2.5;
    static constexpr float INACTIVITY_THRESHOLD = 1.2;

    // Consistency tracking (rolling variance of last N readings)
    static const uint8_t CONSISTENCY_WINDOW = 8;
    float hrHistory[CONSISTENCY_WINDOW];
    float spo2History[CONSISTENCY_WINDOW];
    uint8_t hrHistIdx, spo2HistIdx;
    uint8_t hrHistCount, spo2HistCount;

    // Helper methods
    uint8_t calcRangeFactor(float value, const ClinicalRange &range);
    uint8_t calcConsistency(float value, float* history, uint8_t &idx, uint8_t &count);
    void setQualityLabel(ValidatedReading &r);
    void setFlag(ValidatedReading &r, float value, const ClinicalRange &range,
                 const char* lowCrit, const char* lowWarn,
                 const char* normal,
                 const char* highWarn, const char* highCrit);
};

#endif
