"""
VitalSync FastAPI Backend
───────────────────────────
Server for receiving sensor data (ESP32), processing vitals,
storing to Firebase, and serving analytics to the Flutter app.
"""
import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ─── Firebase Setup ────────────────────────────────────────
# import firebase_admin
# from firebase_admin import credentials, firestore, db as rtdb
# cred = credentials.Certificate("serviceAccountKey.json")
# firebase_admin.initialize_app(cred, {"databaseURL": "https://YOUR_PROJECT.firebaseio.com"})
# firestore_db = firestore.client()

app = FastAPI(
    title="VitalSync API",
    description="Backend for the VitalSync remote health monitoring system",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── In-memory storage (replace with Firebase) ────────────
sensor_readings: list = []
alerts: list = []
patients: dict = {}


# ─── Pydantic Models ──────────────────────────────────────
class VitalReading(BaseModel):
    patient_id: str = Field(..., description="Patient identifier")
    heart_rate: float = Field(..., ge=0, le=300)
    spo2: float = Field(..., ge=0, le=100)
    temperature: float = Field(..., ge=20.0, le=50.0)
    bp_systolic: float = Field(..., ge=0, le=300)
    bp_diastolic: float = Field(..., ge=0, le=200)
    ecg_samples: list[float] = Field(default_factory=list)
    fall_detected: bool = False
    timestamp: Optional[str] = None


class PatientProfile(BaseModel):
    patient_id: str
    name: str
    email: str
    age: int = Field(..., ge=0, le=150)
    gender: str
    language: str = "en"
    emergency_name: Optional[str] = None
    emergency_phone: Optional[str] = None
    role: str = "patient"


class AlertRequest(BaseModel):
    patient_id: str
    alert_code: str
    message: str
    severity: str  # 'warning' | 'critical'
    vital_value: float = 0


class AnalyticsRequest(BaseModel):
    patient_id: str
    vital_type: str  # 'heart_rate' | 'spo2' | 'temperature' | 'bp'
    period_hours: int = 24


# ─── Alert Thresholds ─────────────────────────────────────
THRESHOLDS = {
    "hr_high": 100.0,
    "hr_critical": 150.0,
    "spo2_low": 92.0,
    "spo2_critical": 88.0,
    "temp_high": 38.0,
    "temp_critical": 39.5,
    "bp_systolic_high": 140.0,
    "bp_systolic_critical": 180.0,
}


# ─── Health Endpoints ─────────────────────────────────────
@app.get("/")
async def root():
    return {
        "service": "VitalSync API",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy", "uptime": "ok"}


# ─── Sensor Data Endpoints ────────────────────────────────
@app.post("/api/v1/vitals", tags=["Sensor Data"])
async def receive_vital_reading(reading: VitalReading):
    """
    Receive a vital reading from ESP32 sensor or simulator.
    Processes alerts and stores data.
    """
    if not reading.timestamp:
        reading.timestamp = datetime.now(timezone.utc).isoformat()

    data = reading.model_dump()
    sensor_readings.append(data)

    # Keep only last 1000 readings per patient in memory
    patient_readings = [r for r in sensor_readings if r["patient_id"] == reading.patient_id]
    if len(patient_readings) > 1000:
        sensor_readings[:] = [
            r for r in sensor_readings if r["patient_id"] != reading.patient_id
        ] + patient_readings[-1000:]

    # TODO: Write to Firebase Realtime DB
    # ref = rtdb.reference(f"/vitals/{reading.patient_id}/current")
    # ref.set(data)
    # firestore_db.collection("vitals_log").add(data)

    # Check thresholds and generate alerts
    generated_alerts = _check_thresholds(reading)

    return {
        "status": "received",
        "timestamp": data["timestamp"],
        "alerts_generated": len(generated_alerts),
        "alerts": generated_alerts,
    }


@app.get("/api/v1/vitals/{patient_id}", tags=["Sensor Data"])
async def get_latest_vitals(patient_id: str):
    """Get the latest vital reading for a patient."""
    patient_readings = [
        r for r in sensor_readings if r["patient_id"] == patient_id
    ]
    if not patient_readings:
        raise HTTPException(status_code=404, detail="No readings found for patient")
    return patient_readings[-1]


@app.get("/api/v1/vitals/{patient_id}/history", tags=["Sensor Data"])
async def get_vitals_history(patient_id: str, limit: int = 100):
    """Get historical vital readings for a patient."""
    patient_readings = [
        r for r in sensor_readings if r["patient_id"] == patient_id
    ]
    return {
        "patient_id": patient_id,
        "count": len(patient_readings[-limit:]),
        "readings": patient_readings[-limit:],
    }


# ─── Analytics Endpoints ──────────────────────────────────
@app.post("/api/v1/analytics", tags=["Analytics"])
async def get_analytics(request: AnalyticsRequest):
    """Get analytics for a specific vital type over a time period."""
    patient_readings = [
        r for r in sensor_readings if r["patient_id"] == request.patient_id
    ]
    if not patient_readings:
        return {
            "patient_id": request.patient_id,
            "vital_type": request.vital_type,
            "avg": 0,
            "min": 0,
            "max": 0,
            "count": 0,
            "trend": "stable",
        }

    vital_map = {
        "heart_rate": "heart_rate",
        "spo2": "spo2",
        "temperature": "temperature",
        "bp": "bp_systolic",
    }
    key = vital_map.get(request.vital_type, "heart_rate")
    values = [r[key] for r in patient_readings if key in r]

    if not values:
        return {"error": "No data for this vital type"}

    avg_val = sum(values) / len(values)
    min_val = min(values)
    max_val = max(values)

    # Simple trend detection
    if len(values) >= 5:
        recent = values[-5:]
        older = values[-10:-5] if len(values) >= 10 else values[:5]
        trend = "rising" if sum(recent) / len(recent) > sum(older) / len(older) * 1.05 else \
                "falling" if sum(recent) / len(recent) < sum(older) / len(older) * 0.95 else "stable"
    else:
        trend = "insufficient_data"

    return {
        "patient_id": request.patient_id,
        "vital_type": request.vital_type,
        "avg": round(avg_val, 2),
        "min": round(min_val, 2),
        "max": round(max_val, 2),
        "count": len(values),
        "trend": trend,
    }


# ─── Alert Endpoints ──────────────────────────────────────
@app.get("/api/v1/alerts/{patient_id}", tags=["Alerts"])
async def get_patient_alerts(patient_id: str, limit: int = 50):
    """Get recent alerts for a patient."""
    patient_alerts = [a for a in alerts if a["patient_id"] == patient_id]
    return {
        "patient_id": patient_id,
        "count": len(patient_alerts[-limit:]),
        "alerts": patient_alerts[-limit:],
    }


@app.post("/api/v1/alerts/acknowledge/{alert_id}", tags=["Alerts"])
async def acknowledge_alert(alert_id: str):
    """Acknowledge an alert."""
    for alert in alerts:
        if alert.get("id") == alert_id:
            alert["acknowledged"] = True
            return {"status": "acknowledged", "alert_id": alert_id}
    raise HTTPException(status_code=404, detail="Alert not found")


# ─── Patient Endpoints ────────────────────────────────────
@app.post("/api/v1/patients", tags=["Patients"])
async def register_patient(profile: PatientProfile):
    """Register a new patient profile."""
    patients[profile.patient_id] = profile.model_dump()
    # TODO: firestore_db.collection("patients").document(profile.patient_id).set(profile.model_dump())
    return {"status": "registered", "patient_id": profile.patient_id}


@app.get("/api/v1/patients/{patient_id}", tags=["Patients"])
async def get_patient(patient_id: str):
    """Get patient profile."""
    if patient_id not in patients:
        raise HTTPException(status_code=404, detail="Patient not found")
    return patients[patient_id]


# ─── ESP32 Simulator Endpoint ─────────────────────────────
@app.post("/api/v1/simulate", tags=["Simulator"])
async def simulate_reading(patient_id: str = "demo-user"):
    """Generate a simulated vital reading for testing."""
    import random

    reading = VitalReading(
        patient_id=patient_id,
        heart_rate=round(random.uniform(60, 100), 1),
        spo2=round(random.uniform(94, 100), 1),
        temperature=round(random.uniform(36.0, 37.5), 1),
        bp_systolic=round(random.uniform(100, 140), 0),
        bp_diastolic=round(random.uniform(60, 90), 0),
        ecg_samples=[round(random.uniform(-0.5, 1.0), 3) for _ in range(100)],
        fall_detected=random.random() < 0.01,
    )
    return await receive_vital_reading(reading)


# ─── Helper Functions ─────────────────────────────────────
def _check_thresholds(reading: VitalReading) -> list:
    """Check vital reading against thresholds and generate alerts."""
    generated = []

    if reading.heart_rate > THRESHOLDS["hr_critical"]:
        alert = _create_alert(
            reading.patient_id,
            "ALERT_HR_CRITICAL",
            f"Heart rate critically high: {reading.heart_rate:.0f} BPM",
            "critical",
            reading.heart_rate,
        )
        generated.append(alert)
    elif reading.heart_rate > THRESHOLDS["hr_high"]:
        alert = _create_alert(
            reading.patient_id,
            "ALERT_HR_HIGH",
            f"Heart rate elevated: {reading.heart_rate:.0f} BPM",
            "warning",
            reading.heart_rate,
        )
        generated.append(alert)

    if reading.spo2 < THRESHOLDS["spo2_critical"]:
        alert = _create_alert(
            reading.patient_id,
            "ALERT_SPO2_LOW",
            f"SpO2 critically low: {reading.spo2:.0f}%",
            "critical",
            reading.spo2,
        )
        generated.append(alert)

    if reading.temperature > THRESHOLDS["temp_critical"]:
        alert = _create_alert(
            reading.patient_id,
            "ALERT_TEMP_HIGH",
            f"Temperature critically high: {reading.temperature:.1f}°C",
            "critical",
            reading.temperature,
        )
        generated.append(alert)

    if reading.fall_detected:
        alert = _create_alert(
            reading.patient_id,
            "ALERT_FALL",
            "Fall detected! Emergency check initiated.",
            "critical",
            0,
        )
        generated.append(alert)

    return generated


def _create_alert(patient_id: str, code: str, message: str, severity: str, value: float) -> dict:
    """Create and store an alert."""
    alert = {
        "id": f"alert-{datetime.now(timezone.utc).timestamp():.0f}",
        "patient_id": patient_id,
        "alert_code": code,
        "message": message,
        "severity": severity,
        "vital_value": value,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "acknowledged": False,
    }
    alerts.append(alert)
    if len(alerts) > 500:
        alerts[:] = alerts[-500:]

    # TODO: Send FCM push notification
    # TODO: Write to Firebase: firestore_db.collection("alerts").add(alert)

    return alert


# ─── Run Server ───────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
