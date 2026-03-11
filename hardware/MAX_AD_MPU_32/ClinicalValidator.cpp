#include "ClinicalValidator.h"
#include <math.h>

// ==========================================
// Clinical Reference Ranges
// ==========================================
//                                    critLow  warnLow  normLow  normHigh  warnHigh  critHigh
const ClinicalRange ClinicalValidator::hrRange   = { 40,  50,   60,   100,  150,  200  };
const ClinicalRange ClinicalValidator::spo2Range = { 85,  90,   95,   100,  101,  101  };  // SpO2 only has low-side warnings
const ClinicalRange ClinicalValidator::sysRange  = { 70,  80,   90,   120,  140,  180  };
const ClinicalRange ClinicalValidator::diaRange  = { 40,  50,   60,    80,   90,  120  };

ClinicalValidator::ClinicalValidator() {
    fallState = FALL_IDLE;
    freefallStart = 0;
    impactStart = 0;
    hrHistIdx = 0;
    spo2HistIdx = 0;
    hrHistCount = 0;
    spo2HistCount = 0;
    for (uint8_t i = 0; i < CONSISTENCY_WINDOW; i++) {
        hrHistory[i] = 0;
        spo2History[i] = 0;
    }
}

// ==========================================
// Range Factor: 100 if normal, 80 if warning, 50 if critical, 0 if absurd
// ==========================================
uint8_t ClinicalValidator::calcRangeFactor(float value, const ClinicalRange &range) {
    if (value >= range.normalLow && value <= range.normalHigh) return 100;
    if (value >= range.warningLow && value <= range.warningHigh) return 80;
    if (value >= range.criticalLow && value <= range.criticalHigh) return 50;
    return 20;  // way out of range
}

// ==========================================
// Consistency: low variance → high score
// ==========================================
uint8_t ClinicalValidator::calcConsistency(float value, float* history, uint8_t &idx, uint8_t &count) {
    history[idx] = value;
    idx = (idx + 1) % CONSISTENCY_WINDOW;
    if (count < CONSISTENCY_WINDOW) count++;

    if (count < 3) return 50;  // not enough data

    float sum = 0, sumSq = 0;
    for (uint8_t i = 0; i < count; i++) {
        sum += history[i];
        sumSq += history[i] * history[i];
    }
    float mean = sum / count;
    float variance = (sumSq / count) - (mean * mean);
    float cv = (mean > 0) ? (sqrt(fabs(variance)) / mean) * 100.0 : 100.0;

    // CV < 5% → 100, CV > 30% → 30
    if (cv < 5.0) return 100;
    if (cv > 30.0) return 30;
    return (uint8_t)(100.0 - (cv - 5.0) * 2.8);
}

// ==========================================
// Quality label from confidence score
// ==========================================
void ClinicalValidator::setQualityLabel(ValidatedReading &r) {
    if (r.confidence >= 80)      strcpy(r.quality, "HIGH");
    else if (r.confidence >= 55) strcpy(r.quality, "MED");
    else if (r.confidence >= 30) strcpy(r.quality, "LOW");
    else                         strcpy(r.quality, "BAD");
}

// ==========================================
// Flag setter based on clinical range
// ==========================================
void ClinicalValidator::setFlag(ValidatedReading &r, float value, const ClinicalRange &range,
                                 const char* lowCrit, const char* lowWarn,
                                 const char* normal,
                                 const char* highWarn, const char* highCrit) {
    r.inRange = (value >= range.normalLow && value <= range.normalHigh);

    if (value < range.criticalLow)       strncpy(r.flag, lowCrit, 15);
    else if (value < range.warningLow)   strncpy(r.flag, lowWarn, 15);
    else if (value <= range.normalHigh)  strncpy(r.flag, normal, 15);
    else if (value <= range.warningHigh) strncpy(r.flag, highWarn, 15);
    else                                 strncpy(r.flag, highCrit, 15);
    r.flag[15] = '\0';
}

// ==========================================
// Heart Rate Validation
// ==========================================
ValidatedReading ClinicalValidator::validateHR(float hr, uint8_t signalQuality) {
    ValidatedReading r;
    r.value = hr;

    if (isnan(hr) || hr <= 0) {
        r.confidence = 0;
        r.inRange = false;
        strcpy(r.quality, "BAD");
        strcpy(r.flag, "NO_SIGNAL");
        return r;
    }

    uint8_t rangeFactor = calcRangeFactor(hr, hrRange);
    uint8_t consistency = calcConsistency(hr, hrHistory, hrHistIdx, hrHistCount);

    // confidence = signalQuality * rangeFactor * consistency / 10000
    uint32_t raw = (uint32_t)signalQuality * rangeFactor * consistency;
    uint32_t conf = raw / 10000UL;
    r.confidence = (uint8_t)(conf > 100 ? 100 : conf);

    setFlag(r, hr, hrRange, "SEVERE_BRADY", "BRADYCARDIA", "NORMAL", "TACHYCARDIA", "SEVERE_TACHY");
    setQualityLabel(r);
    return r;
}

// ==========================================
// SpO2 Validation
// ==========================================
ValidatedReading ClinicalValidator::validateSpO2(float spo2, uint8_t signalQuality) {
    ValidatedReading r;
    r.value = spo2;

    if (isnan(spo2) || spo2 <= 0) {
        r.confidence = 0;
        r.inRange = false;
        strcpy(r.quality, "BAD");
        strcpy(r.flag, "NO_SIGNAL");
        return r;
    }

    uint8_t rangeFactor = calcRangeFactor(spo2, spo2Range);
    uint8_t consistency = calcConsistency(spo2, spo2History, spo2HistIdx, spo2HistCount);

    uint32_t raw = (uint32_t)signalQuality * rangeFactor * consistency;
    uint32_t conf2 = raw / 10000UL;
    r.confidence = (uint8_t)(conf2 > 100 ? 100 : conf2);

    setFlag(r, spo2, spo2Range, "SEVERE_HYPOX", "HYPOXIA", "NORMAL", "NORMAL", "NORMAL");
    setQualityLabel(r);
    return r;
}

// ==========================================
// ECG Validation (cross-validated with PPG HR)
// ==========================================
ValidatedReading ClinicalValidator::validateECG(float ecgBpm, float ppgHr) {
    ValidatedReading r;
    r.value = ecgBpm;

    if (ecgBpm <= 0) {
        r.confidence = 0;
        r.inRange = false;
        strcpy(r.quality, "BAD");
        strcpy(r.flag, "NO_SIGNAL");
        return r;
    }

    uint8_t rangeFactor = calcRangeFactor(ecgBpm, hrRange);

    // Cross-validation with PPG heart rate
    uint8_t crossVal = crossValidateHR(ppgHr, ecgBpm);

    uint32_t raw = (uint32_t)rangeFactor * crossVal;
    uint32_t conf3 = raw / 100UL;
    r.confidence = (uint8_t)(conf3 > 100 ? 100 : conf3);

    setFlag(r, ecgBpm, hrRange, "SEVERE_BRADY", "BRADYCARDIA", "NORMAL", "TACHYCARDIA", "SEVERE_TACHY");
    setQualityLabel(r);
    return r;
}

// ==========================================
// Blood Pressure Validation
// ==========================================
ValidatedReading ClinicalValidator::validateBP(float sys, float dia, unsigned long ptt) {
    ValidatedReading r;
    r.value = sys;  // primary value is systolic

    if (sys <= 0 || dia <= 0 || ptt == 0) {
        r.confidence = 0;
        r.inRange = false;
        strcpy(r.quality, "BAD");
        strcpy(r.flag, "NO_DATA");
        return r;
    }

    uint8_t sysRangeFactor = calcRangeFactor(sys, sysRange);
    uint8_t diaRangeFactor = calcRangeFactor(dia, diaRange);
    uint8_t avgRange = (sysRangeFactor + diaRangeFactor) / 2;

    // PTT quality factor: 80-350ms is physiological, edges are lower confidence
    uint8_t pttFactor = 100;
    if (ptt < 80 || ptt > 350) pttFactor = 20;
    else if (ptt < 100 || ptt > 300) pttFactor = 60;

    // Physiological check: systolic must be > diastolic
    if (sys <= dia) {
        r.confidence = 10;
        r.inRange = false;
        strcpy(r.quality, "BAD");
        strcpy(r.flag, "INVALID_BP");
        return r;
    }

    // Pulse pressure (SYS - DIA) should be 30–60 mmHg typically
    float pp = sys - dia;
    uint8_t ppFactor = 100;
    if (pp < 20 || pp > 80) ppFactor = 50;
    else if (pp < 25 || pp > 70) ppFactor = 75;

    uint32_t raw = (uint32_t)avgRange * pttFactor * ppFactor;
    uint32_t conf4 = raw / 10000UL;
    r.confidence = (uint8_t)(conf4 > 100 ? 100 : conf4);

    // Flag based on systolic primarily
    setFlag(r, sys, sysRange, "HYPOTENSION", "LOW_BP", "NORMAL", "PRE_HYPER", "HYPERTENSION");
    setQualityLabel(r);
    return r;
}

// ==========================================
// Cross-validate PPG HR vs ECG BPM
// Returns 100 if they agree, lower if diverging
// ==========================================
uint8_t ClinicalValidator::crossValidateHR(float ppgHr, float ecgBpm) {
    if (ppgHr <= 0 || ecgBpm <= 0) return 50;  // can't validate, neutral

    float diff = fabs(ppgHr - ecgBpm);
    float avg = (ppgHr + ecgBpm) / 2.0;
    float pctDiff = (diff / avg) * 100.0;

    if (pctDiff < 5.0)  return 100;  // excellent agreement
    if (pctDiff < 10.0) return 90;
    if (pctDiff < 15.0) return 70;
    if (pctDiff < 25.0) return 50;
    if (pctDiff < 35.0) return 30;
    return 15;  // >35% divergence, one sensor is likely wrong
}

// ==========================================
// 3-Phase Fall Detection State Machine
// IDLE → FREE_FALL → IMPACT → CONFIRMED
// ==========================================
FallState ClinicalValidator::updateFallDetection(float totalG, unsigned long currentTime) {
    switch (fallState) {
        case FALL_IDLE:
            if (totalG < FREEFALL_THRESHOLD) {
                fallState = FALL_FREEFALL;
                freefallStart = currentTime;
            }
            break;

        case FALL_FREEFALL:
            if (totalG > IMPACT_THRESHOLD) {
                fallState = FALL_IMPACT;
                impactStart = currentTime;
            } else if (currentTime - freefallStart > FREEFALL_TIMEOUT_MS) {
                fallState = FALL_IDLE;  // timeout, was not a real free-fall
            }
            break;

        case FALL_IMPACT:
            if (totalG < INACTIVITY_THRESHOLD &&
                (currentTime - impactStart > INACTIVITY_PERIOD_MS)) {
                fallState = FALL_CONFIRMED;
            } else if (currentTime - impactStart > 5000) {
                // Person moved after impact — not a fall (or they recovered)
                fallState = FALL_IDLE;
            }
            break;

        case FALL_CONFIRMED:
            // Stay confirmed until explicitly reset
            // The main sketch should handle alerts and then reset
            break;
    }
    return fallState;
}

FallState ClinicalValidator::getFallState() {
    return fallState;
}

// ==========================================
// JSON output for backend consumption
// ==========================================
String ClinicalValidator::toJSON(
    float hr, uint8_t hrConf,
    float spo2, uint8_t spo2Conf,
    float ecgBpm, uint8_t ecgConf,
    float sysBP, float diaBP, uint8_t bpConf,
    float temp,
    FallState fs,
    const char* overallQuality
) {
    String json = "{";

    json += "\"hr\":"; json += String(hr, 1);
    json += ",\"hr_conf\":"; json += hrConf;

    json += ",\"spo2\":"; json += String(spo2, 1);
    json += ",\"spo2_conf\":"; json += spo2Conf;

    json += ",\"ecg_bpm\":"; json += String(ecgBpm, 1);
    json += ",\"ecg_conf\":"; json += ecgConf;

    json += ",\"sys\":"; json += String(sysBP, 1);
    json += ",\"dia\":"; json += String(diaBP, 1);
    json += ",\"bp_conf\":"; json += bpConf;

    json += ",\"temp\":"; json += String(temp, 1);

    json += ",\"fall\":";
    switch (fs) {
        case FALL_IDLE:      json += "\"IDLE\""; break;
        case FALL_FREEFALL:  json += "\"FREEFALL\""; break;
        case FALL_IMPACT:    json += "\"IMPACT\""; break;
        case FALL_CONFIRMED: json += "\"CONFIRMED\""; break;
    }

    json += ",\"quality\":\""; json += overallQuality; json += "\"";
    json += "}";
    return json;
}
