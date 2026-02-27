"""
VitalSync — MongoDB Connection Manager
───────────────────────────────────────
Async MongoDB connection using Motor (async driver).
Provides the database instance and collection helpers.
"""
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "vitalsync")

# ─── Singleton client ─────────────────────────────────────
_client: AsyncIOMotorClient | None = None


def get_client() -> AsyncIOMotorClient:
    """Return the shared Motor client (creates on first call)."""
    global _client
    if _client is None:
        _client = AsyncIOMotorClient(
            MONGODB_URI,
            maxPoolSize=20,
            minPoolSize=5,
            serverSelectionTimeoutMS=5000,
        )
    return _client


def get_db():
    """Return the VitalSync database handle."""
    return get_client()[MONGODB_DB_NAME]


# ─── Collection accessors ──────────────────────────────────
def vitals_collection():
    """Time-series collection for vitals history."""
    return get_db()["vitals_history"]


def alerts_collection():
    """Alerts log collection."""
    return get_db()["alerts_log"]


def patients_collection():
    """Patient profiles collection."""
    return get_db()["patients"]


def daily_summaries_collection():
    """Pre-computed daily summaries."""
    return get_db()["daily_summaries"]


def audit_log_collection():
    """Audit trail (Phase 4)."""
    return get_db()["audit_log"]


# ─── Lifecycle hooks ───────────────────────────────────────
async def connect_db():
    """Verify MongoDB connectivity on startup."""
    client = get_client()
    # Ping to verify the connection works
    await client.admin.command("ping")
    print(f"✅ Connected to MongoDB Atlas — database: {MONGODB_DB_NAME}")


async def close_db():
    """Close the MongoDB connection on shutdown."""
    global _client
    if _client:
        _client.close()
        _client = None
        print("🔌 MongoDB connection closed")


async def init_collections():
    """
    Create collections with proper schemas on first run.
    Time-series collection for vitals_history gives 
    optimized storage and aggregation for time-based queries.
    """
    db = get_db()
    existing = await db.list_collection_names()

    # ── vitals_history (time-series) ──
    if "vitals_history" not in existing:
        await db.create_collection(
            "vitals_history",
            timeseries={
                "timeField": "timestamp",
                "metaField": "patient_id",
                "granularity": "seconds",
            },
        )
        print("📊 Created time-series collection: vitals_history")

    # ── Indexes ──
    vitals = vitals_collection()
    await vitals.create_index([("patient_id", 1), ("timestamp", -1)])

    alerts = alerts_collection()
    await alerts.create_index([("patient_id", 1), ("timestamp", -1)])
    await alerts.create_index("alert_id", unique=True, sparse=True)

    patients = patients_collection()
    await patients.create_index("patient_id", unique=True)

    summaries = daily_summaries_collection()
    await summaries.create_index(
        [("patient_id", 1), ("date", 1)], unique=True
    )

    print("🗂️  MongoDB indexes ensured")
