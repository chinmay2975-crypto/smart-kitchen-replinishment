import logging
import random
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)

logger = logging.getLogger("smart_kitchen.auth")
router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

# ---------------------------------------------------------------------------
# In-memory OTP store (for demo purposes — use Redis in production)
# ---------------------------------------------------------------------------
_otp_store: dict[str, dict] = {}

# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

class SendOtpRequest(BaseModel):
    phone: str = Field(..., pattern=r"^\+?[1-9]\d{9,14}$")

class VerifyOtpRequest(BaseModel):
    phone: str
    otp: str

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    email: str = Field(..., pattern=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")
    phone: str = Field(..., pattern=r"^\+?[1-9]\d{9,14}$")
    password: str = Field(..., min_length=6)

class LoginRequest(BaseModel):
    email: str
    password: str

class RefreshRequest(BaseModel):
    refresh_token: str

class AuthResponse(BaseModel):
    user_id: str
    email: str
    name: str | None = None
    phone: str | None = None
    household_id: str | None = None
    access_token: str
    refresh_token: str

class OtpResponse(BaseModel):
    status: str
    message: str
    otp: str | None = None  # Included in dev mode for testing


def invalid_credentials_exception() -> HTTPException:
    return HTTPException(status_code=401, detail="Invalid email or password")

# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/send-otp", response_model=OtpResponse)
async def send_otp(req: SendOtpRequest):
    """Send OTP to the given phone number (mock — prints to console)."""
    otp = f"{random.randint(100000, 999999)}"
    _otp_store[req.phone] = {
        "otp": otp,
        "expires_at": datetime.utcnow() + timedelta(minutes=5),
    }
    # In production, integrate with Twilio / MSG91 / AWS SNS here
    logger.info("OTP for %s: %s", req.phone, otp)
    print(f"\n📱 OTP for {req.phone}: {otp}\n")
    return {
        "status": "success",
        "message": "OTP sent successfully",
        "otp": otp,  # Exposed in dev for testing
    }


@router.post("/verify-otp", response_model=dict)
async def verify_otp(req: VerifyOtpRequest):
    """Verify the OTP for a phone number."""
    stored = _otp_store.get(req.phone)
    if not stored:
        raise HTTPException(status_code=400, detail="No OTP requested for this number")
    if datetime.utcnow() > stored["expires_at"]:
        _otp_store.pop(req.phone, None)
        raise HTTPException(status_code=400, detail="OTP expired")
    if stored["otp"] != req.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    _otp_store.pop(req.phone, None)
    return {"status": "success", "message": "OTP verified successfully"}


@router.post("/register", response_model=AuthResponse)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new user. Creates user + household + preferences."""
    email = req.email.strip().lower()
    name = req.name.strip()
    phone = req.phone.strip()

    # Check if email already exists
    existing = await db.execute(
        text("SELECT user_id FROM app_users WHERE email = :email"),
        {"email": email},
    )
    if existing.first():
        raise HTTPException(status_code=409, detail="Email already registered")

    # Check if phone already exists
    existing_phone = await db.execute(
        text("SELECT user_id FROM app_users WHERE phone = :phone"),
        {"phone": phone},
    )
    if existing_phone.first():
        raise HTTPException(status_code=409, detail="Phone number already registered")

    user_id = uuid.uuid4()
    household_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    password_hash = get_password_hash(req.password)

    try:
        # Create user
        await db.execute(
            text("""
                INSERT INTO app_users (user_id, email, password_hash, full_name, phone, role, is_active, created_at, updated_at)
                VALUES (:uid, :email, :pwd, :name, :phone, 'homeowner', TRUE, :now, :now)
            """),
            {
                "uid": user_id,
                "email": email,
                "pwd": password_hash,
                "name": name,
                "phone": phone,
                "now": now,
            },
        )

        # Create household
        await db.execute(
            text("""
                INSERT INTO households (household_id, name, owner_id, created_at)
                VALUES (:hid, :hname, :uid, :now)
            """),
            {
                "hid": household_id,
                "hname": f"{name}'s Kitchen",
                "uid": user_id,
                "now": now,
            },
        )

        # Add as household member
        await db.execute(
            text("""
                INSERT INTO household_members (household_id, user_id, role, joined_at)
                VALUES (:hid, :uid, 'owner', :now)
            """),
            {"hid": household_id, "uid": user_id, "now": now},
        )

        # Create default preferences
        await db.execute(
            text("""
                INSERT INTO household_preferences (household_id, user_id, auto_replenish, notify_low_stock, notify_expiry)
                VALUES (:hid, :uid, TRUE, TRUE, TRUE)
            """),
            {"hid": household_id, "uid": user_id},
        )

        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        logger.warning("Registration integrity error for %s: %s", email, exc)
        raise HTTPException(status_code=409, detail="Email or phone number already registered")
    except SQLAlchemyError as exc:
        await db.rollback()
        logger.exception("Registration database error for %s", email)
        raise HTTPException(status_code=500, detail="Registration failed due to a database error")

    access_token = create_access_token({"sub": str(user_id), "email": email})
    refresh_token = create_refresh_token({"sub": str(user_id)})

    return AuthResponse(
        user_id=str(user_id),
        email=email,
        name=name,
        phone=phone,
        household_id=str(household_id),
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login with email and password."""
    email = req.email.strip().lower()

    if not email or not req.password:
        raise invalid_credentials_exception()

    result = await db.execute(
        text("""
            SELECT u.user_id, u.email, u.full_name, u.phone, u.password_hash,
                   h.household_id
            FROM app_users u
            LEFT JOIN households h ON h.owner_id = u.user_id
            WHERE u.email = :email AND u.is_active = TRUE
        """),
        {"email": email},
    )
    row = result.first()
    if not row:
        raise invalid_credentials_exception()

    try:
        password_is_valid = verify_password(req.password, row[4])
    except Exception as exc:
        logger.warning("Password verification failed for %s due to stored hash error: %s", email, exc)
        password_is_valid = False

    if not password_is_valid:
        raise invalid_credentials_exception()

    user_id = row[0]
    access_token = create_access_token({"sub": str(user_id), "email": row[1]})
    refresh_token = create_refresh_token({"sub": str(user_id)})

    return AuthResponse(
        user_id=str(user_id),
        email=row[1],
        name=row[2],
        phone=row[3],
        household_id=str(row[5]) if row[5] else None,
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=dict)
async def refresh(req: RefreshRequest):
    """Refresh an expired access token using a refresh token."""
    try:
        payload = decode_token(req.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=403, detail="Invalid token type")
        new_access = create_access_token({"sub": payload["sub"]})
        new_refresh = create_refresh_token({"sub": payload["sub"]})
        return {
            "access_token": new_access,
            "refresh_token": new_refresh,
        }
    except Exception:
        raise HTTPException(status_code=403, detail="Invalid or expired refresh token")