# VitalSync Backend

FastAPI server for the VitalSync remote health monitoring system.

## Quick Start

```bash
cd backend
pip install -r requirements.txt
python main.py
```

Server runs at `http://localhost:8000`  
API docs at `http://localhost:8000/docs`

## Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/vitals` | Receive sensor reading (from ESP32) |
| GET | `/api/v1/vitals/{id}` | Get latest vitals for patient |
| GET | `/api/v1/vitals/{id}/history` | Get historical readings |
| POST | `/api/v1/analytics` | Get vital stats + trends |
| GET | `/api/v1/alerts/{id}` | Get patient alerts |
| POST | `/api/v1/alerts/acknowledge/{id}` | Acknowledge alert |
| POST | `/api/v1/patients` | Register patient |
| GET | `/api/v1/patients/{id}` | Get patient profile |
| POST | `/api/v1/simulate` | Generate test reading |

## ESP32 Integration

The ESP32 sends POST requests to `/api/v1/vitals` in JSON:

```json
{
  "patient_id": "user-123",
  "heart_rate": 72.0,
  "spo2": 98.0,
  "temperature": 36.6,
  "bp_systolic": 120.0,
  "bp_diastolic": 80.0,
  "ecg_samples": [0.1, 0.5, ...],
  "fall_detected": false
}
```
