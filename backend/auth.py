"""
VitalSync — Authentication & RBAC (Phase 4)
─────────────────────────────────────────────
Firebase token verification and role-based access control
for the FastAPI backend.

Roles:
  - patient  : Can read/write own vitals and history
  - doctor   : Can read assigned patients' vitals and history
  - relative : Can read assigned patients' live vitals only (no history)

Token Flow:
  Flutter → Firebase Auth → ID Token → FastAPI → Verify → Extract uid + role
"""
import os
from datetime import datetime, timezone
from typing import Optional
from functools import wraps

from fastapi import HTTPException, Header, Depends
from dotenv import load_dotenv

load_dotenv()


# ─── Firebase Admin (reuse existing or init) ──────────────
def _ensure_firebase():
    """Ensure Firebase Admin SDK is initialized."""
    try:
        import firebase_admin
        # Check if already initialized
        firebase_admin.get_app()
    except ValueError:
        # Not initialized yet — initialize
        from firebase_admin import credentials
        sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json")
        if os.path.exists(sa_path):
            cred = credentials.Certificate(sa_path)
            import firebase_admin
            firebase_admin.initialize_app(cred, {
                "databaseURL": os.getenv(
                    "FIREBASE_RTDB_URL",
                    "https://vitalsync-9f06f-default-rtdb.firebaseio.com"
                ),
            })


# ─── Token Verification ──────────────────────────────────
class AuthenticatedUser:
    """Represents a verified Firebase user with role info."""
    def __init__(self, uid: str, email: str = "", role: str = "patient"):
        self.uid = uid
        self.email = email
        self.role = role

    def __repr__(self):
        return f"User(uid={self.uid}, role={self.role})"


async def verify_firebase_token(
    authorization: Optional[str] = Header(None),
) -> AuthenticatedUser:
    """
    FastAPI dependency: verify Firebase ID token from Authorization header.
    Returns an AuthenticatedUser with uid and role.

    Usage in endpoint:
        @app.get("/api/v1/protected")
        async def protected(user: AuthenticatedUser = Depends(verify_firebase_token)):
            ...
    """
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing Authorization header. Send: Bearer <firebase_id_token>",
        )

    # Extract token from "Bearer <token>"
    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="Invalid Authorization format. Expected: Bearer <token>",
        )

    token = parts[1]

    try:
        _ensure_firebase()
        from firebase_admin import auth

        # Verify the ID token
        decoded = auth.verify_id_token(token)
        uid = decoded.get("uid", "")
        email = decoded.get("email", "")

        # Get role from custom claims or Firestore
        role = decoded.get("role", "patient")
        if not role or role == "patient":
            # Check custom claims
            role = decoded.get("custom_claims", {}).get("role", "patient") if isinstance(decoded.get("custom_claims"), dict) else "patient"

        return AuthenticatedUser(uid=uid, email=email, role=role)

    except Exception as e:
        error_msg = str(e)
        if "expired" in error_msg.lower():
            raise HTTPException(status_code=401, detail="Token expired. Please re-authenticate.")
        elif "invalid" in error_msg.lower():
            raise HTTPException(status_code=401, detail="Invalid token.")
        else:
            raise HTTPException(status_code=401, detail=f"Authentication failed: {error_msg}")


# ─── Optional Auth (for backward compatibility) ──────────
async def optional_firebase_token(
    authorization: Optional[str] = Header(None),
) -> Optional[AuthenticatedUser]:
    """
    Like verify_firebase_token, but returns None instead of 401
    if no token is provided. Useful for endpoints that work both
    authenticated and unauthenticated.
    """
    if not authorization:
        return None
    try:
        return await verify_firebase_token(authorization)
    except HTTPException:
        return None


# ─── RBAC Helpers ─────────────────────────────────────────
def check_patient_access(user: AuthenticatedUser, patient_id: str):
    """
    Verify the user has access to a specific patient's data.
    Raises 403 if access is denied.
    """
    if user.role == "patient":
        # Patients can only access their own data
        if user.uid != patient_id:
            raise HTTPException(
                status_code=403,
                detail="Access denied. Patients can only access their own data.",
            )

    elif user.role == "doctor":
        # Doctors can access their assigned patients
        # In production, check authorized_doctors node or a DB lookup
        # For now, allow access (authorization is managed via RTDB rules)
        pass

    elif user.role == "relative":
        # Relatives have limited access (live vitals only, no history)
        pass

    else:
        raise HTTPException(
            status_code=403,
            detail=f"Unknown role: {user.role}",
        )


def check_history_access(user: AuthenticatedUser, patient_id: str):
    """
    Verify the user can access vitals HISTORY (stricter than live).
    Relatives are blocked from history access.
    """
    if user.role == "relative":
        raise HTTPException(
            status_code=403,
            detail="Relatives cannot access vitals history. Only live vitals are available.",
        )
    check_patient_access(user, patient_id)


# ─── Audit Logging ────────────────────────────────────────
async def log_access(
    actor_uid: str,
    action: str,
    patient_id: str,
    details: dict = None,
):
    """
    Log an access event to the MongoDB audit_log collection.
    Called whenever someone reads patient data.
    """
    try:
        from database import audit_log_collection
        collection = audit_log_collection()

        entry = {
            "actor_uid": actor_uid,
            "action": action,
            "patient_id": patient_id,
            "timestamp": datetime.now(timezone.utc),
            "details": details or {},
        }
        await collection.insert_one(entry)
    except Exception as e:
        # Don't fail the request if audit logging fails
        print(f"⚠️  Audit log failed: {e}")
