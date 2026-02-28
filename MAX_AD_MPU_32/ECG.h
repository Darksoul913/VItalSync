#ifndef ECG_H
#define ECG_H

#include <Arduino.h>
#include <math.h>

class ECG {
public:
    // Number of samples per cycle (fixed resolution)
    static const int SAMPLES = 100;

    // Generate one full PQRST cycle into buf[SAMPLES]
    // hr: heart rate in BPM (30–220)
    static void generateCycle(float hr, int16_t* buf) {
        if (hr < 30 || hr > 220) hr = 75;  // safe default

        // === PQRST Gaussian parameters ===
        // Each wave: { angle_mean (rad, 0–2π), amplitude, width (rad) }
        // Tuned to produce realistic ECG morphology at rest HR
        // Based on McSharry et al "A dynamical model for generating synthetic ECG signals"

        struct Wave { float mean; float amp; float width; };

        // Scale QRS sharpness inversely with HR (higher HR → tighter QRS)
        float hrScale = 75.0f / hr;  // normalize to resting HR

        const Wave waves[5] = {
            // P wave (atrial depolarization — small bump)
            { -1.05f, 0.20f, 0.25f },
            // Q wave (small dip before R)
            { -0.17f, -0.12f, 0.06f },
            // R wave (dominant spike)
            {  0.00f,  1.00f, 0.08f * hrScale },
            // S wave (small dip after R)
            {  0.17f, -0.20f, 0.07f },
            // T wave (repolarization bump)
            {  0.90f,  0.30f, 0.30f }
        };

        for (int i = 0; i < SAMPLES; i++) {
            // Map sample index to angle [-π, π]
            float theta = -M_PI + (2.0f * M_PI * i) / SAMPLES;
            float v = 0;
            for (int w = 0; w < 5; w++) {
                float dt = theta - waves[w].mean;
                // Wrap dt to [-π, π] to handle boundary cases
                while (dt >  M_PI) dt -= 2.0f * M_PI;
                while (dt < -M_PI) dt += 2.0f * M_PI;
                v += waves[w].amp * expf(-(dt * dt) / (2.0f * waves[w].width * waves[w].width));
            }
            // Scale to int16 range [-512, 512]
            buf[i] = (int16_t)constrain((int)(v * 512.0f), -512, 512);
        }
    }

    // Serialize to compact JSON array string: "[10,20,-5,...]"
    // Caller must provide a char buf large enough: SAMPLES * 5 + 4 bytes
    static void toJSONArray(int16_t* samples, char* out, size_t outLen) {
        int pos = 0;
        out[pos++] = '[';
        for (int i = 0; i < SAMPLES && pos < (int)outLen - 8; i++) {
            if (i > 0) out[pos++] = ',';
            pos += snprintf(out + pos, outLen - pos, "%d", (int)samples[i]);
        }
        out[pos++] = ']';
        out[pos] = '\0';
    }
};

#endif
