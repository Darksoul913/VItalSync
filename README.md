# VitalSync – The AI-Powered Vernacular Guardian

![VitalSync Hero Image](vitalWrist.jpeg)

**Domain:** IoT / MedTech / Remote Patient Monitoring  


---

## 📖 Table of Contents

- [Executive Summary](#-executive-summary)
- [Hardware Architecture](#-hardware-architecture-the-wearable-node)
- [Software Architecture](#-software-architecture-the-hybrid-stack)
- [The "Life of a Packet"](#-the-life-of-a-packet)
- [Key Features & Innovations](#-key-features--innovations)
- [Advanced Features](#-advanced-features)
- [Repository Structure](#-repository-structure)
- [Getting Started](#-getting-started)

---

## 🚀 Executive Summary

VitalSync is a low-cost (<₹3,200), hybrid-edge wearable designed to democratize critical health monitoring for rural and elderly populations. It addresses the "Digital Health Divide" by combining an affordable hardware node with a sophisticated mobile neural engine.

Unlike standard fitness trackers, VitalSync is a specialized medical device that utilizes a **Hybrid Compute Architecture** to split processing between an ultra-low-power wearable node (ESP32-C3) and a mobile neural engine (Smartphone). Key innovations include:
- **"Touch-to-Measure" Copper Tape Electrodes**
- **Offline Vernacular Voice Alerts** 
- **Rx-Efficacy Analytics Engine** (quantifies patient improvement pre- and post-medication)

---

## 🛠 Hardware Architecture (The Wearable Node)

Designed for mass manufacturability, repairability, and high precision.

### Core Processing Unit
- **Microcontroller:** Seeed Studio ESP32-C3
- **Architecture:** 32-bit RISC-V Single Core Processor (160 MHz)
- **Connectivity:** Wi-Fi + Bluetooth 5.0 (BLE) subsystem

### Sensor Array

| Subsystem | Sensor | Function |
|-----------|--------|----------|
| **ECG** | AD8232 | Captures P-Q-R-S-T waveform for Arrhythmia detection. Utilizes custom copper tape electrodes for 90% cost reduction. 500Hz sampling. |
| **PPG** | MAX30102 | Measures SpO2 (Oxygen Saturation) and Heart Rate via I2C. |
| **Inertial** | MPU6050 / GY-87 | 6-DOF Accelerometer + Gyroscope for detecting high-G impacts (Falls) and body orientation. |
| **Thermal** | MLX90614 | Contactless IR Temperature with ±0.5°C medical-grade accuracy. |

### Power & Enclosure
- **Battery:** 3.7V Li-Po (500mAh)
- **Charging:** TP4056 Module via USB-C
- **Power Draw:** <10µA in Deep Sleep (Wake-on-motion trigger enabled)

---

## 🧠 Software Architecture (The Hybrid Stack)

We utilize a **"Split-Brain" architecture**: The Watch handles *Reflexes* (Falls), and the Phone handles *Intelligence* (Diagnosis).

### Firmware (ESP32-C3 | C++ & FreeRTOS)
- **DSP Pipeline:** 50Hz Notch Filter + 20Hz Low-Pass Filter.
- **Batching Engine:** Buffers 20 samples (40ms) into a single BLE packet for optimized throughput.
- **Local Logic (Reflex):** On-chip fall detection via high-G and orientation change thresholds.

### Mobile Neural Engine (Flutter | Dart & TFLite)
- **Mobile Edge AI:** 1D-CNN trained on MIT-BIH Arrhythmia Database for real-time inference via `tflite_flutter`.
- **Algorithms:** Cuffless BP calculated via Pulse Transit Time (PTT).
- **Vernacular Voice Engine:** Offline-first audio alerts mapped to error codes (e.g., `marathi_high_bp.mp3`).

### Cloud Backend & Data Transmission
- **API Engine:** Smart API handles intelligent data ingestion and routing.
- **Longitudinal Analytics:** Cron jobs compare pre/post medication vitals for Rx-Efficacy "Improvement Reports".


## 🔄 The "Life of a Packet"

1. **Acquisition (On-Device):** Hardware timer triggers at 500Hz. ESP32 reads ECG, applies DSP filters, and buffers. Parallel 10ms task checks for falls.
2. **Transmission (BLE Link):** Batch of 20 compressed samples (`int16`) is sent via BLE Notification.
3. **Intelligence (On-Mobile):** Flutter app receives/decompresses packet. Data is plotted, fed to TFLite models, and algorithms run.
4. **Action & Storage:** In emergencies, vernacular voice alerts play and SMS/WhatsApp is sent to contacts. In routine use, data is locally buffered and batch-uploaded via the Smart API.

---

## ✨ Key Features & Innovations

| Feature | VitalSync Approach | Traditional Approach |
|---------|-------------------|----------------------|
| **Blood Pressure** | Cuffless (Pulse Transit Time) | Inflatable Cuff (Bulky) |
| **AI Processing** | Mobile Edge (Fast, Offline) | Cloud API (Slow, Expensive) |
| **Connectivity** | Store-and-Forward (Resilient) | Requires Always-on 4G/Wi-Fi |
| **User Interface** | Voice & Pictorial (Inclusive) | Text/Numbers |
| **Scale** | Smart API architecture | Direct DB Writes (Bottleneck) |
| **Electrode Cost** | Low-Cost Copper Tape | Expensive Silver-Chloride |

---

## 🔬 Advanced Features

- **RAG Agent Chatbot:** Queries live sensor DB for personalized health answers rather than generic text.
- **Predictive Weather Integration:** e.g., "Cold front coming + Rising BP = Eat less salt today."
- **Correlative Analysis:** Identifies links like "Lack of sleep caused your BP to spike today."
- **Auto-Scribe (Doctor View):** Generates structured SOAP notes automatically from dashboard charts.
- **Active Tests:** Interactively prompts the user (e.g., "Stand up now") to test for Orthostasis.

---

## 📁 Repository Structure

```
├── backend/                  # Node.js Backend services & cron jobs
├── ml/                       # Machine Learning models & TFLite conversion
├── vital_sync/               # Flutter Mobile App source code
├── i2c/                      # Arduino/ESP32 Firmware code
├── SPO2/                     # MAX30102 code & SpO2 algorithms
├── mitbih_database/          # Dataset for training the Arrhythmia model
├── plan.md                   # Detailed Project Specifications
└── README.md                 # Project Overview (You are here)
```

---

## ⚙️ Getting Started

*(Instructions for setting up the hardware node, mobile app, and backend will be added here)*

- **App:** Make sure Flutter is installed. Navigate to `vital_sync/` and run `flutter run`.
- **Hardware:** Open `i2c/i2c.ino` in Arduino IDE or PlatformIO. Ensure the ESP32-C3 board package is installed.

---

*VitalSync - Built to bridge the digital health divide.*
