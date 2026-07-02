import logging
import random
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
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
async def register(request: Request, db: AsyncSession = Depends(get_db)):
    """Register a new user. Creates user + household + preferences."""
    # Get the raw request body to see what was sent
    try:
        body = await request.json()
        logger.info("Registration attempt with data: %s", body)
    except Exception:
        logger.warning("Could not parse request body")
        body = {}
    
    # Validate the request manually to get better error messages
    try:
        req = RegisterRequest(**body)
    except RequestValidationError as e:
        logger.error("Validation error: %s", e.errors())
        # Extract the first error message
        errors = e.errors()
        if errors:
            error = errors[0]
            field = error.get('loc', ['unknown'])[0] if error.get('loc') else 'unknown'
            msg = error.get('msg', 'Validation error')
            raise HTTPException(status_code=422, detail=f"{field}: {msg}")
        raise HTTPException(status_code=422, detail="Validation error")
    
    logger.info("Registration attempt for email: %s", req.email)
    
    try:
        email = req.email.strip().lower()
        name = req.name.strip()
        phone = req.phone.strip()

        # Check if email already exists
        existing = await db.execute(
            text("SELECT user_id FROM app_users WHERE email = :email"),
            {"email": email},
        )
        if existing.first():
            logger.warning("Registration failed: email %s already exists", email)
            raise HTTPException(status_code=409, detail="Email already registered")

        # Check if phone already exists
        existing_phone = await db.execute(
            text("SELECT user_id FROM app_users WHERE phone = :phone"),
            {"phone": phone},
        )
        if existing_phone.first():
            logger.warning("Registration failed: phone %s already exists", phone)
            raise HTTPException(status_code=409, detail="Phone number already registered")

        user_id = uuid.uuid4()
        household_id = uuid.uuid4()
        now = datetime.now(timezone.utc)
        password_hash = get_password_hash(req.password)

        # Create user
        logger.info("Creating user %s with household %s", user_id, household_id)
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
        logger.info("Successfully registered user %s with household %s", email, household_id)
    except IntegrityError as exc:
        await db.rollback()
        logger.error("Registration integrity error for %s: %s", email, exc, exc_info=True)
        raise HTTPException(status_code=409, detail="Email or phone number already registered")
    except SQLAlchemyError as exc:
        await db.rollback()
        logger.error("Registration database error for %s: %s", email, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Registration failed due to a database error")
    except Exception as exc:
        await db.rollback()
        logger.error("Registration unexpected error for %s: %s", email, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Registration failed due to an unexpected error")

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
    logger.info("Login attempt for email: %s", req.email)
    
    try:
        email = req.email.strip().lower()

        if not email or not req.password:
            logger.warning("Login failed: missing email or password")
            raise invalid_credentials_exception()

        # Step 1: Query the database for the user
        try:
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
        except Exception as exc:
            logger.error("Login database query error for %s: %s", email, exc, exc_info=True)
            raise HTTPException(
                status_code=503,
                detail="Login failed: database is temporarily unavailable. Please try again."
            )

        row = result.first()
        if not row:
            logger.warning("Login failed: user %s not found", email)
            raise invalid_credentials_exception()

        # Step 2: Verify the password hash exists and is valid
        stored_hash = row[4]
        if not stored_hash:
            logger.error("Login failed: user %s has no password hash stored", email)
            raise HTTPException(
                status_code=500,
                detail="Login failed: account configuration error. Please contact support."
            )

        try:
            password_is_valid = verify_password(req.password, stored_hash)
        except Exception as exc:
            logger.error("Password verification error for %s: %s", email, exc, exc_info=True)
            raise HTTPException(
                status_code=500,
                detail="Login failed: password verification error. Please try again."
            )

        if not password_is_valid:
            logger.warning("Login failed: invalid password for %s", email)
            raise invalid_credentials_exception()

        # Step 3: Generate tokens
        user_id = row[0]
        try:
            access_token = create_access_token({"sub": str(user_id), "email": row[1]})
            refresh_token = create_refresh_token({"sub": str(user_id)})
        except Exception as exc:
            logger.error("Token generation error for %s: %s", email, exc, exc_info=True)
            raise HTTPException(
                status_code=500,
                detail="Login failed: could not generate authentication tokens. Please try again."
            )
        
        logger.info("Login successful for user %s (ID: %s)", email, user_id)

        return AuthResponse(
            user_id=str(user_id),
            email=row[1],
            name=row[2],
            phone=row[3],
            household_id=str(row[5]) if row[5] else None,
            access_token=access_token,
            refresh_token=refresh_token,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Login unexpected error for %s: %s", email, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Login failed due to an unexpected error")


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