import uuid
from datetime import datetime, date
from sqlalchemy import (
    Column,
    String,
    Boolean,
    Numeric,
    Text,
    Integer,
    Float,
    Date,
    DateTime,
    ForeignKey,
    UniqueConstraint,
    CheckConstraint,
    JSON,
    BigInteger,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy import func
from typing import Optional


class Base(DeclarativeBase):
    pass


class AppUser(Base):
    __tablename__ = "app_users"

    user_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = mapped_column(String(255), unique=True, nullable=False)
    password_hash = mapped_column(String(255), nullable=False)
    full_name = mapped_column(String(150), nullable=False)
    phone = mapped_column(String(20), nullable=True)
    role = mapped_column(String(20), nullable=False, default="homeowner")
    is_active = mapped_column(Boolean, default=True)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at = mapped_column(DateTime(timezone=True), server_default=func.now())


class Household(Base):
    __tablename__ = "households"

    household_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = mapped_column(String(200), nullable=False)
    address_line1 = mapped_column(String(255), nullable=True)
    address_line2 = mapped_column(String(255), nullable=True)
    city = mapped_column(String(100), nullable=True)
    state = mapped_column(String(100), nullable=True)
    postal_code = mapped_column(String(20), nullable=True)
    country = mapped_column(String(100), default="IN")
    timezone = mapped_column(String(50), default="Asia/Kolkata")
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    owner_id = mapped_column(UUID(as_uuid=True), ForeignKey("app_users.user_id"), nullable=True)


class HouseholdMember(Base):
    __tablename__ = "household_members"

    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), primary_key=True)
    user_id = mapped_column(UUID(as_uuid=True), ForeignKey("app_users.user_id", ondelete="CASCADE"), primary_key=True)
    role = mapped_column(String(20), default="member")
    joined_at = mapped_column(DateTime(timezone=True), server_default=func.now())


class Device(Base):
    __tablename__ = "devices"

    device_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), nullable=True)
    device_name = mapped_column(String(100), nullable=False)
    device_type = mapped_column(String(50), nullable=False)
    mqtt_topic = mapped_column(String(255), unique=True, nullable=False)
    firmware_ver = mapped_column(String(30), nullable=True)
    is_online = mapped_column(Boolean, default=False)
    last_seen_at = mapped_column(DateTime(timezone=True), nullable=True)
    config_json = mapped_column(JSONB, default={})
    registered_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    deactivated_at = mapped_column(DateTime(timezone=True), nullable=True)
    reorder_level = mapped_column(Numeric(10, 2), nullable=True)
    reorder_quantity = mapped_column(Numeric(10, 2), nullable=True)
    battery_level = mapped_column(Numeric(5, 2), nullable=True, default=100)
    zoho_item_id = mapped_column(String(100), nullable=True)


class ProductCatalog(Base):
    __tablename__ = "product_catalog"

    product_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), nullable=True)
    sku = mapped_column(String(100), nullable=True)
    product_name = mapped_column(String(255), nullable=False)
    category = mapped_column(String(100), nullable=False)
    unit_type = mapped_column(String(30), nullable=False)
    default_threshold_min = mapped_column(Numeric(10, 2), nullable=True)
    default_threshold_max = mapped_column(Numeric(10, 2), nullable=True)
    image_url = mapped_column(Text, nullable=True)
    barcode = mapped_column(String(100), nullable=True)
    preferred_supplier_id = mapped_column(UUID(as_uuid=True), nullable=True)
    is_perishable = mapped_column(Boolean, default=False)
    shelf_life_days = mapped_column(Integer, nullable=True)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at = mapped_column(DateTime(timezone=True), server_default=func.now())


class InventoryCurrent(Base):
    __tablename__ = "inventory_current"

    inventory_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), nullable=True)
    product_id = mapped_column(UUID(as_uuid=True), ForeignKey("product_catalog.product_id", ondelete="CASCADE"), nullable=True)
    device_id = mapped_column(UUID(as_uuid=True), ForeignKey("devices.device_id", ondelete="SET NULL"), nullable=True)
    quantity = mapped_column(Numeric(10, 2), nullable=False, default=0)
    unit_type = mapped_column(String(30), nullable=False)
    location = mapped_column(String(100), default="pantry")
    threshold_min = mapped_column(Numeric(10, 2), nullable=True)
    threshold_max = mapped_column(Numeric(10, 2), nullable=True)
    expiry_date = mapped_column(Date, nullable=True)
    batch_lot = mapped_column(String(100), nullable=True)
    last_updated = mapped_column(DateTime(timezone=True), server_default=func.now())


class ReplenishmentOrder(Base):
    __tablename__ = "replenishment_orders"

    order_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), nullable=True)
    created_by = mapped_column(UUID(as_uuid=True), ForeignKey("app_users.user_id"), nullable=True)
    supplier_id = mapped_column(UUID(as_uuid=True), nullable=True)
    order_status = mapped_column(String(30), default="pending")
    order_type = mapped_column(String(20), default="automatic")
    total_amount = mapped_column(Numeric(12, 2), nullable=True)
    currency = mapped_column(String(3), default="INR")
    notes = mapped_column(Text, nullable=True)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    delivered_at = mapped_column(DateTime(timezone=True), nullable=True)


class CartItem(Base):
    """Amazon-style auto-reorder cart entry, distinct from the household
    replenishment_orders/order_line_items pipeline used by the background
    replenishment engine."""
    __tablename__ = "cart_items"

    cart_item_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = mapped_column(UUID(as_uuid=True), ForeignKey("app_users.user_id", ondelete="CASCADE"), nullable=False)
    container_id = mapped_column(UUID(as_uuid=True), ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    item_name = mapped_column(String(255), nullable=False)
    quantity = mapped_column(Numeric(10, 2), nullable=False)
    status = mapped_column(String(20), nullable=False, default="pending_cart")
    estimated_delivery = mapped_column(Date, nullable=True)
    zoho_sales_order_number = mapped_column(String(100), nullable=True)
    unit_price = mapped_column(Numeric(10, 2), nullable=True)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index('idx_cart_items_user_status', 'user_id', 'status'),
        Index('idx_cart_items_container_status', 'container_id', 'status'),
    )


class OrderLineItem(Base):
    __tablename__ = "order_line_items"

    line_item_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id = mapped_column(UUID(as_uuid=True), ForeignKey("replenishment_orders.order_id", ondelete="CASCADE"), nullable=True)
    product_id = mapped_column(UUID(as_uuid=True), ForeignKey("product_catalog.product_id"), nullable=True)
    quantity_ordered = mapped_column(Numeric(10, 2), nullable=False)
    quantity_received = mapped_column(Numeric(10, 2), nullable=True)
    unit_type = mapped_column(String(30), nullable=False)
    unit_price = mapped_column(Numeric(10, 2), nullable=True)
    total_price = mapped_column(Numeric(10, 2), nullable=True)
    supplier_sku = mapped_column(String(100), nullable=True)


class Supplier(Base):
    __tablename__ = "suppliers"

    supplier_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    supplier_name = mapped_column(String(200), nullable=False)
    contact_name = mapped_column(String(150), nullable=True)
    email = mapped_column(String(255), nullable=True)
    phone = mapped_column(String(20), nullable=True)
    website = mapped_column(String(255), nullable=True)
    api_endpoint = mapped_column(String(255), nullable=True)
    api_key_enc = mapped_column(Text, nullable=True)
    is_active = mapped_column(Boolean, default=True)
    delivery_lead_time_hours = mapped_column(Integer, default=48)
    min_order_amount = mapped_column(Numeric(10, 2), default=0)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())


class AlertLog(Base):
    __tablename__ = "alert_log"

    alert_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), nullable=True)
    alert_type = mapped_column(String(50), nullable=False)
    severity = mapped_column(String(20), default="info")
    title = mapped_column(String(255), nullable=False)
    message = mapped_column(Text, nullable=True)
    is_read = mapped_column(Boolean, default=False)
    is_resolved = mapped_column(Boolean, default=False)
    related_entity_type = mapped_column(String(50), nullable=True)
    related_entity_id = mapped_column(UUID(as_uuid=True), nullable=True)
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    resolved_at = mapped_column(DateTime(timezone=True), nullable=True)


class HouseholdPreference(Base):
    __tablename__ = "household_preferences"

    preference_id = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    household_id = mapped_column(UUID(as_uuid=True), ForeignKey("households.household_id", ondelete="CASCADE"), nullable=True)
    user_id = mapped_column(UUID(as_uuid=True), ForeignKey("app_users.user_id", ondelete="CASCADE"), nullable=True)
    auto_replenish = mapped_column(Boolean, default=True)
    notify_low_stock = mapped_column(Boolean, default=True)
    notify_expiry = mapped_column(Boolean, default=True)
    preferred_replenish_day = mapped_column(String(20), default="monday")
    notification_channels = mapped_column(JSONB, default=["push", "email"])
    created_at = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at = mapped_column(DateTime(timezone=True), server_default=func.now())


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    reading_id = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    device_id = mapped_column(UUID(as_uuid=True), ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    sensor_type = mapped_column(Text, nullable=False)
    value = mapped_column(Numeric(10, 4), nullable=False)
    unit = mapped_column(Text, nullable=False)
    metadata_json = mapped_column(JSONB, default={})
    recorded_at = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class DeviceReading(Base):
    __tablename__ = "device_readings"

    reading_id = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id = mapped_column(UUID(as_uuid=True), ForeignKey("app_users.user_id", ondelete="CASCADE"), nullable=False)
    device_id = mapped_column(UUID(as_uuid=True), ForeignKey("devices.device_id", ondelete="SET NULL"), nullable=True)
    feed_id = mapped_column(String(50), nullable=True)
    reading_value = mapped_column(Numeric(10, 2), nullable=False)
    unit = mapped_column(String(20), default="gram")
    latitude = mapped_column(Numeric(9, 6), nullable=True)
    longitude = mapped_column(Numeric(9, 6), nullable=True)
    elevation = mapped_column(Numeric(8, 2), nullable=True)
    external_id = mapped_column(String(50), nullable=True)
    metadata_json = mapped_column(JSONB, default={})
    created_at = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        Index('idx_device_readings_user_created', 'user_id', 'created_at'),
    )
