"""
VitalSync — Field-Level Encryption
────────────────────────────────────
AES-256 encryption for sensitive vital signs data before MongoDB storage.
Even if the database is compromised, vitals remain unreadable.

Uses Fernet (AES-128-CBC + HMAC-SHA256) from the `cryptography` library.
Fernet provides authenticated encryption — tampered data is detected.

Key Management:
  - Key is loaded from ENCRYPTION_KEY env variable
  - Generate a key: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
  - In production, use AWS KMS, GCP Secret Manager, or Azure Key Vault
"""
import os
import json
from cryptography.fernet import Fernet, InvalidToken
from dotenv import load_dotenv

load_dotenv()

# ─── Key Management ──────────────────────────────────────
_ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY", "")
_fernet: Fernet | None = None


def _get_fernet() -> Fernet | None:
    """Get or create the Fernet cipher. Returns None if no key configured."""
    global _fernet
    if _fernet is not None:
        return _fernet
    if not _ENCRYPTION_KEY:
        print("⚠️  ENCRYPTION_KEY not set — vitals will be stored unencrypted")
        return None
    try:
        _fernet = Fernet(_ENCRYPTION_KEY.encode())
        print("🔐 Field-level encryption active")
        return _fernet
    except Exception as e:
        print(f"⚠️  Invalid ENCRYPTION_KEY: {e}")
        return None


def is_encryption_enabled() -> bool:
    """Check if encryption is properly configured."""
    return _get_fernet() is not None


# ─── Fields to encrypt ────────────────────────────────────
# Only medical vitals are encrypted; metadata (patient_id, timestamp)
# stays plaintext for indexing and querying.
ENCRYPTED_FIELDS = [
    "heart_rate",
    "spo2",
    "temperature",
    "bp_systolic",
    "bp_diastolic",
    "ecg_samples",
]


# ─── Encrypt / Decrypt ───────────────────────────────────
def encrypt_vitals(doc: dict) -> dict:
    """
    Encrypt sensitive vital fields in a document before MongoDB insert.
    Non-sensitive fields (patient_id, timestamp, fall_detected) remain plain.

    Returns a new dict with encrypted fields replaced by a single
    'encrypted_vitals' blob + an 'is_encrypted' flag.
    """
    f = _get_fernet()
    if f is None:
        return doc  # No encryption key — store as-is

    # Extract fields to encrypt
    vitals_data = {}
    for field in ENCRYPTED_FIELDS:
        if field in doc:
            vitals_data[field] = doc[field]

    if not vitals_data:
        return doc

    # Serialize and encrypt
    plaintext = json.dumps(vitals_data).encode("utf-8")
    ciphertext = f.encrypt(plaintext).decode("utf-8")

    # Build new document: metadata + encrypted blob
    encrypted_doc = {
        k: v for k, v in doc.items() if k not in ENCRYPTED_FIELDS
    }
    encrypted_doc["encrypted_vitals"] = ciphertext
    encrypted_doc["is_encrypted"] = True

    return encrypted_doc


def decrypt_vitals(doc: dict) -> dict:
    """
    Decrypt a document retrieved from MongoDB.
    If document is not encrypted, returns as-is.
    """
    if not doc.get("is_encrypted"):
        return doc  # Not encrypted — return as-is

    f = _get_fernet()
    if f is None:
        # Key not available — can't decrypt
        doc["_decryption_error"] = "Encryption key not configured"
        return doc

    try:
        ciphertext = doc.get("encrypted_vitals", "")
        plaintext = f.decrypt(ciphertext.encode("utf-8"))
        vitals_data = json.loads(plaintext.decode("utf-8"))

        # Merge decrypted fields back into doc
        decrypted_doc = {
            k: v for k, v in doc.items()
            if k not in ("encrypted_vitals", "is_encrypted")
        }
        decrypted_doc.update(vitals_data)
        return decrypted_doc

    except InvalidToken:
        doc["_decryption_error"] = "Invalid key or tampered data"
        return doc
    except Exception as e:
        doc["_decryption_error"] = str(e)
        return doc


def decrypt_vitals_list(docs: list[dict]) -> list[dict]:
    """Decrypt a list of documents."""
    return [decrypt_vitals(doc) for doc in docs]
