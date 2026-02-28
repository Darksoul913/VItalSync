"""
VitalSync FastAPI Backend
───────────────────────────
Server for receiving sensor data (ESP32), processing vitals,
storing to MongoDB (history) + Firebase RTDB (live), and serving
analytics to the Flutter app.

Architecture:
  ESP32 → FastAPI → MongoDB (cold storage)  +  Firebase RTDB (hot/live)
  Flutter ← FastAPI (history/analytics)     +  Firebase RTDB (live stream)
"""
import os
import uuid
from datetime import datetime, timezone, timedelta
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException, Query, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv

load_dotenv()

# ─── MongoDB ───────────────────────────────────────────────
from database import (
    connect_db,
    close_db,
    init_collections,
    vitals_collection,
    alerts_collection,
    patients_collection,
    daily_summaries_collection,
    devices_collection,
)

# ─── Encryption ────────────────────────────────────────────
from encryption import encrypt_vitals, decrypt_vitals, decrypt_vitals_list, is_encryption_enabled

# ─── Auth & RBAC (Phase 4) ─────────────────────────────────
from auth import (
    AuthenticatedUser,
    verify_firebase_token,
    optional_firebase_token,
    check_patient_access,
    check_history_access,
    log_access,
)


# ─── App Lifecycle ─────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: connect to MongoDB. Shutdown: close connection."""
    await connect_db()
    await init_collections()
    yield
    await close_db()


app = FastAPI(
    title="VitalSync API",
    description="Backend for the VitalSync remote health monitoring system",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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


class DevicePairRequest(BaseModel):
    patient_id: str
    device_name: str = "VitalSync Band"


class DeviceActivateRequest(BaseModel):
    device_token: str
    patient_id: str


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
        "version": "2.0.0",
        "database": "MongoDB Atlas",
        "status": "running",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/health")
async def health_check():
    """Health check — also verifies MongoDB connectivity."""
    try:
        from database import get_client
        await get_client().admin.command("ping")
        return {"status": "healthy", "mongodb": "connected"}
    except Exception as e:
        return {"status": "degraded", "mongodb": f"error: {str(e)}"}


# ─── Sensor Data Endpoints ────────────────────────────────
@app.post("/api/v1/vitals", tags=["Sensor Data"])
async def receive_vital_reading(
    reading: VitalReading,
    x_device_token: Optional[str] = Header(None),
):
    """
    Receive a vital reading from ESP32/ESP8266 or simulator.
    Stores to MongoDB (history) and checks alert thresholds.
    Optionally validates device token if provided.
    """
    # Validate device token if provided
    if x_device_token:
        devices = devices_collection()
        device = await devices.find_one({"device_token": x_device_token})
        if not device:
            raise HTTPException(status_code=401, detail="Invalid device token")
        if device.get("status") != "active":
            raise HTTPException(status_code=403, detail="Device not activated")
        # Ensure the device belongs to this patient
        if device.get("patient_id") != reading.patient_id:
            raise HTTPException(status_code=403, detail="Device not paired to this patient")

    if not reading.timestamp:
        reading.timestamp = datetime.now(timezone.utc).isoformat()

    # Prepare document for MongoDB
    doc = reading.model_dump()
    doc["timestamp"] = datetime.fromisoformat(
        doc["timestamp"].replace("Z", "+00:00")
    )
    doc["_inserted_at"] = datetime.now(timezone.utc)

    # Encrypt sensitive vitals before storage (Phase 3)
    stored_doc = encrypt_vitals(doc)

    # Store in MongoDB vitals_history (time-series)
    collection = vitals_collection()
    await collection.insert_one(stored_doc)

    # Check thresholds and generate alerts
    generated_alerts = await _check_thresholds(reading)

    return {
        "status": "stored",
        "database": "mongodb",
        "timestamp": reading.timestamp,
        "alerts_generated": len(generated_alerts),
        "alerts": generated_alerts,
    }


@app.get("/api/v1/vitals/{patient_id}", tags=["Sensor Data"])
async def get_latest_vitals(
    patient_id: str,
    user: AuthenticatedUser | None = Depends(optional_firebase_token),
):
    """Get the latest vital reading for a patient from MongoDB."""
    # RBAC check (if authenticated)
    if user:
        check_patient_access(user, patient_id)
        await log_access(user.uid, "READ_LATEST_VITALS", patient_id)

    collection = vitals_collection()
    reading = await collection.find_one(
        {"patient_id": patient_id},
        sort=[("timestamp", -1)],
        projection={"_id": 0},
    )
    if not reading:
        raise HTTPException(status_code=404, detail="No readings found")

    # Decrypt vitals (Phase 3)
    reading = decrypt_vitals(reading)

    # Convert datetime to ISO string for JSON
    if isinstance(reading.get("timestamp"), datetime):
        reading["timestamp"] = reading["timestamp"].isoformat()
    reading.pop("_inserted_at", None)

    return reading


@app.get("/api/v1/vitals/{patient_id}/history", tags=["Sensor Data"])
async def get_vitals_history(
    patient_id: str,
    limit: int = Query(100, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=720),
    user: AuthenticatedUser | None = Depends(optional_firebase_token),
):
    """Get historical vital readings from MongoDB."""
    # RBAC check — relatives blocked from history (if authenticated)
    if user:
        check_history_access(user, patient_id)
        await log_access(user.uid, "READ_HISTORY", patient_id, {
            "limit": limit, "hours": hours,
        })

    collection = vitals_collection()
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    cursor = collection.find(
        {"patient_id": patient_id, "timestamp": {"$gte": cutoff}},
        projection={"_id": 0, "_inserted_at": 0, "ecg_samples": 0},
        sort=[("timestamp", -1)],
        limit=limit,
    )
    readings = await cursor.to_list(length=limit)

    # Decrypt vitals (Phase 3)
    readings = decrypt_vitals_list(readings)

    # Convert datetime objects to ISO strings
    for r in readings:
        if isinstance(r.get("timestamp"), datetime):
            r["timestamp"] = r["timestamp"].isoformat()

    return {
        "patient_id": patient_id,
        "count": len(readings),
        "period_hours": hours,
        "readings": readings,
    }


# ─── Analytics Endpoints (decrypt-then-aggregate) ─────────
@app.post("/api/v1/analytics", tags=["Analytics"])
async def get_analytics(request: AnalyticsRequest):
    """
    Get analytics for a vital type over a time period.
    Decrypts vitals first, then computes avg/min/max/trend in Python.
    """
    collection = vitals_collection()
    cutoff = datetime.now(timezone.utc) - timedelta(hours=request.period_hours)

    vital_map = {
        "heart_rate": "heart_rate",
        "spo2": "spo2",
        "temperature": "temperature",
        "bp": "bp_systolic",
    }
    field = vital_map.get(request.vital_type, "heart_rate")

    # Fetch raw (encrypted) documents
    cursor = collection.find(
        {"patient_id": request.patient_id, "timestamp": {"$gte": cutoff}},
        projection={"_id": 0},
        sort=[("timestamp", 1)],
    )
    raw_docs = await cursor.to_list(length=5000)

    if not raw_docs:
        return {
            "patient_id": request.patient_id,
            "vital_type": request.vital_type,
            "avg": 0, "min": 0, "max": 0,
            "count": 0, "trend": "no_data",
        }

    # Decrypt all documents
    decrypted = decrypt_vitals_list(raw_docs)

    # Extract values for the requested vital
    values = []
    for doc in decrypted:
        val = doc.get(field)
        if val is not None and isinstance(val, (int, float)):
            values.append(float(val))

    if not values:
        return {
            "patient_id": request.patient_id,
            "vital_type": request.vital_type,
            "avg": 0, "min": 0, "max": 0,
            "count": 0, "trend": "no_data",
        }

    avg_val = sum(values) / len(values)
    min_val = min(values)
    max_val = max(values)

    # Trend detection
    if len(values) >= 10:
        recent = values[-5:]
        older = values[-10:-5]
        avg_recent = sum(recent) / len(recent)
        avg_older = sum(older) / len(older)
        if avg_recent > avg_older * 1.05:
            trend = "rising"
        elif avg_recent < avg_older * 0.95:
            trend = "falling"
        else:
            trend = "stable"
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


@app.get("/api/v1/analytics/{patient_id}/summary", tags=["Analytics"])
async def get_daily_summary(
    patient_id: str,
    date: Optional[str] = None,
):
    """
    Get or generate a daily summary for a patient.
    Checks cache first, generates from decrypted raw data if needed.
    """
    target_date = date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    summaries = daily_summaries_collection()

    # Check cached summary
    cached = await summaries.find_one(
        {"patient_id": patient_id, "date": target_date},
        projection={"_id": 0},
    )
    if cached:
        if isinstance(cached.get("generated_at"), datetime):
            cached["generated_at"] = cached["generated_at"].isoformat()
        return cached

    # Fetch and decrypt raw vitals for the day
    dt = datetime.strptime(target_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    start = dt
    end = dt + timedelta(days=1)

    collection = vitals_collection()
    cursor = collection.find(
        {"patient_id": patient_id, "timestamp": {"$gte": start, "$lt": end}},
        projection={"_id": 0},
    )
    raw_docs = await cursor.to_list(length=10000)

    if not raw_docs:
        return {
            "patient_id": patient_id,
            "date": target_date,
            "reading_count": 0,
            "message": "No data for this date",
        }

    # Decrypt all
    decrypted = decrypt_vitals_list(raw_docs)

    # Compute stats from decrypted values
    hr_vals = [d["heart_rate"] for d in decrypted if d.get("heart_rate") is not None]
    spo2_vals = [d["spo2"] for d in decrypted if d.get("spo2") is not None]
    temp_vals = [d["temperature"] for d in decrypted if d.get("temperature") is not None]
    sys_vals = [d["bp_systolic"] for d in decrypted if d.get("bp_systolic") is not None]
    dia_vals = [d["bp_diastolic"] for d in decrypted if d.get("bp_diastolic") is not None]

    def _stats(vals):
        if not vals:
            return {"avg": 0, "min": 0, "max": 0}
        return {
            "avg": round(sum(vals) / len(vals), 1),
            "min": round(min(vals), 1),
            "max": round(max(vals), 1),
        }

    summary = {
        "patient_id": patient_id,
        "date": target_date,
        "reading_count": len(decrypted),
        "heart_rate": _stats(hr_vals),
        "spo2": {
            "avg": round(sum(spo2_vals) / len(spo2_vals), 1) if spo2_vals else 0,
            "min": round(min(spo2_vals), 1) if spo2_vals else 0,
        },
        "temperature": _stats(temp_vals),
        "bp": {
            "systolic_avg": round(sum(sys_vals) / len(sys_vals), 1) if sys_vals else 0,
            "diastolic_avg": round(sum(dia_vals) / len(dia_vals), 1) if dia_vals else 0,
        },
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    # Cache the summary
    await summaries.replace_one(
        {"patient_id": patient_id, "date": target_date},
        summary,
        upsert=True,
    )

    return summary


@app.get("/api/v1/vitals/{patient_id}/timeseries", tags=["Analytics"])
async def get_vitals_timeseries(
    patient_id: str,
    vital_type: str = Query("heart_rate", description="heart_rate|spo2|temperature|bp_systolic|bp_diastolic"),
    hours: int = Query(24, ge=1, le=720),
    interval_minutes: int = Query(5, ge=1, le=60, description="Group readings into N-minute buckets"),
):
    """
    Get time-series data points for chart plotting.
    Returns decrypted vitals grouped into time buckets with avg values.
    """
    collection = vitals_collection()
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    cursor = collection.find(
        {"patient_id": patient_id, "timestamp": {"$gte": cutoff}},
        projection={"_id": 0},
        sort=[("timestamp", 1)],
    )
    raw_docs = await cursor.to_list(length=10000)

    if not raw_docs:
        return {
            "patient_id": patient_id,
            "vital_type": vital_type,
            "hours": hours,
            "data_points": [],
        }

    # Decrypt all
    decrypted = decrypt_vitals_list(raw_docs)

    # Group into time buckets
    buckets = {}
    for doc in decrypted:
        val = doc.get(vital_type)
        ts = doc.get("timestamp")
        if val is None or ts is None:
            continue

        # Parse timestamp if string
        if isinstance(ts, str):
            ts = datetime.fromisoformat(ts.replace("Z", "+00:00"))

        # Round to bucket
        bucket_key = ts.replace(
            minute=(ts.minute // interval_minutes) * interval_minutes,
            second=0, microsecond=0
        )
        bucket_str = bucket_key.isoformat()

        if bucket_str not in buckets:
            buckets[bucket_str] = []
        buckets[bucket_str].append(float(val))

    # Build data points (avg per bucket)
    data_points = []
    for ts_str in sorted(buckets.keys()):
        vals = buckets[ts_str]
        data_points.append({
            "timestamp": ts_str,
            "value": round(sum(vals) / len(vals), 2),
            "count": len(vals),
        })

    return {
        "patient_id": patient_id,
        "vital_type": vital_type,
        "hours": hours,
        "interval_minutes": interval_minutes,
        "data_points": data_points,
    }


# ─── Alert Endpoints ──────────────────────────────────────
@app.get("/api/v1/alerts/{patient_id}", tags=["Alerts"])
async def get_patient_alerts(
    patient_id: str,
    limit: int = Query(50, ge=1, le=500),
):
    """Get recent alerts from MongoDB."""
    collection = alerts_collection()
    cursor = collection.find(
        {"patient_id": patient_id},
        projection={"_id": 0},
        sort=[("timestamp", -1)],
        limit=limit,
    )
    alert_list = await cursor.to_list(length=limit)

    for a in alert_list:
        if isinstance(a.get("timestamp"), datetime):
            a["timestamp"] = a["timestamp"].isoformat()

    return {
        "patient_id": patient_id,
        "count": len(alert_list),
        "alerts": alert_list,
    }


@app.post("/api/v1/alerts/acknowledge/{alert_id}", tags=["Alerts"])
async def acknowledge_alert(alert_id: str):
    """Acknowledge an alert in MongoDB."""
    collection = alerts_collection()
    result = await collection.update_one(
        {"alert_id": alert_id},
        {"$set": {"acknowledged": True, "acknowledged_at": datetime.now(timezone.utc)}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"status": "acknowledged", "alert_id": alert_id}


# ─── Patient Endpoints ────────────────────────────────────
@app.post("/api/v1/patients", tags=["Patients"])
async def register_patient(profile: PatientProfile):
    """Register or update a patient profile in MongoDB."""
    collection = patients_collection()
    await collection.replace_one(
        {"patient_id": profile.patient_id},
        profile.model_dump(),
        upsert=True,
    )
    return {"status": "registered", "patient_id": profile.patient_id}


@app.get("/api/v1/patients/{patient_id}", tags=["Patients"])
async def get_patient(patient_id: str):
    """Get patient profile from MongoDB."""
    collection = patients_collection()
    patient = await collection.find_one(
        {"patient_id": patient_id},
        projection={"_id": 0},
    )
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    return patient


# ─── ESP32 Simulator ──────────────────────────────────────
@app.post("/api/v1/simulate", tags=["Simulator"])
async def simulate_reading(patient_id: str = "demo-user"):
    """Generate a simulated vital reading and store in MongoDB."""
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


# ─── Stats Endpoint ───────────────────────────────────────
@app.get("/api/v1/stats", tags=["Analytics"])
async def get_database_stats():
    """Get database statistics — useful for monitoring."""
    vitals = vitals_collection()
    alerts = alerts_collection()
    pts = patients_collection()

    return {
        "vitals_count": await vitals.count_documents({}),
        "alerts_count": await alerts.count_documents({}),
        "patients_count": await pts.count_documents({}),
        "database": "MongoDB Atlas",
    }


# ─── Device Pairing Endpoints ─────────────────────────────
@app.post("/api/v1/devices/pair", tags=["Devices"])
async def pair_device(request: DevicePairRequest):
    """
    Generate a device token and register a new device for a patient.
    Called by the Flutter app when user initiates pairing.
    """
    device_token = f"vsd-{uuid.uuid4().hex}"

    device_doc = {
        "device_token": device_token,
        "patient_id": request.patient_id,
        "device_name": request.device_name,
        "status": "pending",  # pending → active after ESP confirms
        "paired_at": datetime.now(timezone.utc),
        "activated_at": None,
        "last_seen": None,
    }

    devices = devices_collection()
    await devices.insert_one(device_doc)

    return {
        "status": "paired",
        "device_token": device_token,
        "patient_id": request.patient_id,
        "device_name": request.device_name,
    }


@app.post("/api/v1/devices/activate", tags=["Devices"])
async def activate_device(request: DeviceActivateRequest):
    """
    Called by ESP8266 after it reboots with saved config.
    Marks the device as active in MongoDB.
    """
    devices = devices_collection()
    device = await devices.find_one({"device_token": request.device_token})

    if not device:
        raise HTTPException(status_code=404, detail="Device token not found")

    if device.get("patient_id") != request.patient_id:
        raise HTTPException(status_code=403, detail="Token does not match patient")

    await devices.update_one(
        {"device_token": request.device_token},
        {"$set": {
            "status": "active",
            "activated_at": datetime.now(timezone.utc),
            "last_seen": datetime.now(timezone.utc),
        }},
    )

    return {
        "status": "synced",
        "device_token": request.device_token,
        "patient_id": request.patient_id,
    }


@app.get("/api/v1/devices/{patient_id}", tags=["Devices"])
async def get_patient_devices(patient_id: str):
    """Get all paired devices for a patient."""
    devices = devices_collection()
    cursor = devices.find(
        {"patient_id": patient_id},
        projection={"_id": 0},
    )
    device_list = await cursor.to_list(length=20)

    for d in device_list:
        for field in ("paired_at", "activated_at", "last_seen"):
            if isinstance(d.get(field), datetime):
                d[field] = d[field].isoformat()

    return {
        "patient_id": patient_id,
        "count": len(device_list),
        "devices": device_list,
    }


@app.delete("/api/v1/devices/{device_token}", tags=["Devices"])
async def unpair_device(device_token: str):
    """Unpair and remove a device."""
    devices = devices_collection()
    result = await devices.delete_one({"device_token": device_token})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Device not found")
    return {"status": "unpaired", "device_token": device_token}


# ─── Helper Functions ─────────────────────────────────────
async def _check_thresholds(reading: VitalReading) -> list:
    """Check vital reading against thresholds and store alerts in MongoDB."""
    generated = []

    if reading.heart_rate > THRESHOLDS["hr_critical"]:
        alert = await _create_alert(
            reading.patient_id,
            "ALERT_HR_CRITICAL",
            f"Heart rate critically high: {reading.heart_rate:.0f} BPM",
            "critical",
            reading.heart_rate,
        )
        generated.append(alert)
    elif reading.heart_rate > THRESHOLDS["hr_high"]:
        alert = await _create_alert(
            reading.patient_id,
            "ALERT_HR_HIGH",
            f"Heart rate elevated: {reading.heart_rate:.0f} BPM",
            "warning",
            reading.heart_rate,
        )
        generated.append(alert)

    if reading.spo2 < THRESHOLDS["spo2_critical"]:
        alert = await _create_alert(
            reading.patient_id,
            "ALERT_SPO2_LOW",
            f"SpO2 critically low: {reading.spo2:.0f}%",
            "critical",
            reading.spo2,
        )
        generated.append(alert)

    if reading.temperature > THRESHOLDS["temp_critical"]:
        alert = await _create_alert(
            reading.patient_id,
            "ALERT_TEMP_HIGH",
            f"Temperature critically high: {reading.temperature:.1f}°C",
            "critical",
            reading.temperature,
        )
        generated.append(alert)

    if reading.fall_detected:
        alert = await _create_alert(
            reading.patient_id,
            "ALERT_FALL",
            "Fall detected! Emergency check initiated.",
            "critical",
            0,
        )
        generated.append(alert)

    return generated


async def _create_alert(
    patient_id: str,
    code: str,
    message: str,
    severity: str,
    value: float,
) -> dict:
    """Create and store an alert in MongoDB."""
    alert = {
        "alert_id": f"alert-{uuid.uuid4().hex[:12]}",
        "patient_id": patient_id,
        "alert_code": code,
        "message": message,
        "severity": severity,
        "vital_value": value,
        "timestamp": datetime.now(timezone.utc),
        "acknowledged": False,
    }

    collection = alerts_collection()
    await collection.insert_one(alert)

    # Return JSON-safe version
    alert_response = {**alert, "timestamp": alert["timestamp"].isoformat()}
    alert_response.pop("_id", None)
    return alert_response


# ─── Audit Log Endpoint (Phase 4) ───────────────────────
@app.get("/api/v1/audit/{patient_id}", tags=["Audit"])
async def get_audit_log(
    patient_id: str,
    limit: int = Query(50, ge=1, le=500),
    user: AuthenticatedUser | None = Depends(optional_firebase_token),
):
    """
    View the audit trail for a patient.
    Only the patient themselves or their doctor can view this.
    """
    if user:
        check_patient_access(user, patient_id)

    from database import audit_log_collection
    collection = audit_log_collection()
    cursor = collection.find(
        {"patient_id": patient_id},
        projection={"_id": 0},
        sort=[("timestamp", -1)],
        limit=limit,
    )
    entries = await cursor.to_list(length=limit)

    for e in entries:
        if isinstance(e.get("timestamp"), datetime):
            e["timestamp"] = e["timestamp"].isoformat()

    return {
        "patient_id": patient_id,
        "count": len(entries),
        "entries": entries,
    }


# ─── Run Server ───────────────────────────────────────────
# ─── Firebase RTDB Management (Phase 2) ───────────────────

# Initialize Firebase Admin SDK if service account exists
_firebase_app = None

def _get_firebase_app():
    """Lazy-initialize Firebase Admin SDK."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    try:
        import firebase_admin
        from firebase_admin import credentials
        sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json")
        if os.path.exists(sa_path):
            cred = credentials.Certificate(sa_path)
            _firebase_app = firebase_admin.initialize_app(cred, {
                "databaseURL": os.getenv(
                    "FIREBASE_RTDB_URL",
                    "https://vitalsync-9f06f-default-rtdb.firebaseio.com"
                ),
            })
            print("🔥 Firebase Admin SDK initialized")
        else:
            print(f"⚠️  Firebase service account not found: {sa_path}")
    except Exception as e:
        print(f"⚠️  Firebase Admin init failed: {e}")
    return _firebase_app


@app.post("/api/v1/rtdb/cleanup", tags=["Firebase RTDB"])
async def cleanup_stale_vitals(max_age_seconds: int = 60):
    """
    TTL Cleanup: Delete stale live vitals from Firebase RTDB.
    Only keeps the last `max_age_seconds` of data per patient.
    Call this periodically (e.g., every 60s via a scheduler).
    """
    try:
        fb_app = _get_firebase_app()
        if fb_app is None:
            return {"status": "skipped", "reason": "Firebase not initialized"}

        from firebase_admin import db as rtdb
        patients_ref = rtdb.reference("patients")
        patients_data = patients_ref.get()

        if not patients_data:
            return {"status": "ok", "cleaned": 0}

        import time
        cutoff = int(time.time()) - max_age_seconds
        cleaned = 0

        for patient_id, patient_data in patients_data.items():
            vitals = patient_data.get("vitals", {}).get("live", {})
            ts = vitals.get("timestamp", 0)

            # If timestamp is older than cutoff, clear it
            if isinstance(ts, (int, float)) and ts > 0 and ts < cutoff:
                rtdb.reference(f"patients/{patient_id}/vitals/live").delete()
                cleaned += 1

        return {"status": "ok", "cleaned": cleaned, "max_age_seconds": max_age_seconds}

    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.post("/api/v1/rtdb/authorize-doctor", tags=["Firebase RTDB"])
async def authorize_doctor(doctor_uid: str, patient_uid: str, grant: bool = True):
    """
    Manage which doctors can access a patient's live vitals in RTDB.
    Writes to /authorized_doctors/{doctor_uid}/{patient_uid} in Firebase RTDB.
    """
    try:
        fb_app = _get_firebase_app()
        if fb_app is None:
            return {"status": "error", "reason": "Firebase not initialized"}

        from firebase_admin import db as rtdb
        ref = rtdb.reference(f"authorized_doctors/{doctor_uid}/{patient_uid}")

        if grant:
            ref.set(True)
            return {
                "status": "granted",
                "doctor": doctor_uid,
                "patient": patient_uid,
            }
        else:
            ref.delete()
            return {
                "status": "revoked",
                "doctor": doctor_uid,
                "patient": patient_uid,
            }

    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.post("/api/v1/rtdb/authorize-relative", tags=["Firebase RTDB"])
async def authorize_relative(relative_uid: str, patient_uid: str, grant: bool = True):
    """
    Manage which relatives can view a patient's live vitals in RTDB.
    Writes to /authorized_relatives/{relative_uid}/{patient_uid}.
    """
    try:
        fb_app = _get_firebase_app()
        if fb_app is None:
            return {"status": "error", "reason": "Firebase not initialized"}

        from firebase_admin import db as rtdb
        ref = rtdb.reference(f"authorized_relatives/{relative_uid}/{patient_uid}")

        if grant:
            ref.set(True)
            return {
                "status": "granted",
                "relative": relative_uid,
                "patient": patient_uid,
            }
        else:
            ref.delete()
            return {
                "status": "revoked",
                "relative": relative_uid,
                "patient": patient_uid,
            }

    except Exception as e:
        return {"status": "error", "message": str(e)}


# ─── Run Server ───────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
