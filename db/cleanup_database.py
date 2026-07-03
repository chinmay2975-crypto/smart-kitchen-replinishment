#!/usr/bin/env python3
"""
Database cleanup script for Smart Kitchen Replenishment System
Removes all user data while preserving schema and seed data

Usage:
    python db/cleanup_database.py
"""

import asyncio
import os
import sys
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.append(str(Path(__file__).parent.parent))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL')

if not DATABASE_URL:
    print("ERROR: DATABASE_URL not found in .env file")
    sys.exit(1)


async def cleanup_database():
    """Remove all user data from the database"""
    
    print("=" * 60)
    print("Database Cleanup Script")
    print("=" * 60)
    print()
    print(f"Database: {DATABASE_URL.split('@')[1].split('/')[0]}")
    print()
    
    # Create async engine with statement_cache_size=0 for PgBouncer compatibility
    engine = create_async_engine(DATABASE_URL, connect_args={"statement_cache_size": 0})
    
    cleanup_queries = [
        # Disable foreign key checks
        "SET session_replication_role = replica",
        
        # Delete in reverse dependency order
        "DELETE FROM household_preferences",
        "DELETE FROM household_members",
        "DELETE FROM inventory_changes",
        "DELETE FROM inventory_current",
        "DELETE FROM order_line_items",
        "DELETE FROM replenishment_orders",
        "DELETE FROM sensor_readings",
        "DELETE FROM device_events",
        "DELETE FROM telemetry_5min",
        "DELETE FROM devices",
        "DELETE FROM product_catalog",
        "DELETE FROM households",
        "DELETE FROM alert_log",
        "DELETE FROM app_users",
        
        # Re-enable foreign key checks
        "SET session_replication_role = DEFAULT",
    ]
    
    verification_query = """
    SELECT 'app_users' as table_name, COUNT(*) as row_count FROM app_users
    UNION ALL SELECT 'households', COUNT(*) FROM households
    UNION ALL SELECT 'household_members', COUNT(*) FROM household_members
    UNION ALL SELECT 'household_preferences', COUNT(*) FROM household_preferences
    UNION ALL SELECT 'devices', COUNT(*) FROM devices
    UNION ALL SELECT 'product_catalog', COUNT(*) FROM product_catalog
    UNION ALL SELECT 'inventory_current', COUNT(*) FROM inventory_current
    UNION ALL SELECT 'replenishment_orders', COUNT(*) FROM replenishment_orders
    UNION ALL SELECT 'order_line_items', COUNT(*) FROM order_line_items
    UNION ALL SELECT 'alert_log', COUNT(*) FROM alert_log
    UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
    UNION ALL SELECT 'sensor_readings', COUNT(*) FROM sensor_readings
    UNION ALL SELECT 'device_events', COUNT(*) FROM device_events
    UNION ALL SELECT 'telemetry_5min', COUNT(*) FROM telemetry_5min
    UNION ALL SELECT 'inventory_changes', COUNT(*) FROM inventory_changes
    ORDER BY table_name
    """
    
    try:
        async with engine.begin() as conn:
            print("Starting database cleanup...")
            print()
            
            # Execute cleanup queries
            for i, query in enumerate(cleanup_queries, 1):
                query_short = query.replace("SET session_replication_role = ", "SET replication_role = ")
                print(f"[{i:2d}/{len(cleanup_queries)}] {query_short}")
                await conn.execute(text(query))
            
            print()
            print("=" * 60)
            print("Cleanup completed successfully!")
            print("=" * 60)
            print()
            print("Verification - Row counts after cleanup:")
            print("-" * 60)
            
            result = await conn.execute(text(verification_query))
            rows = result.fetchall()
            
            # Print results in a formatted table
            for row in rows:
                status = "✓" if row.row_count == 0 and row.table_name != 'suppliers' else " "
                supplier_marker = " (seed data)" if row.table_name == 'suppliers' else ""
                print(f"{status} {row.table_name:25s}: {row.row_count:3d} rows{supplier_marker}")
            
            print("-" * 60)
            print()
            print("✓ All user data removed")
            print("✓ Schema and seed data preserved")
            print("✓ Ready for fresh registrations")
            print()
            print("You can now test the registration flow with the fixed code.")
            print()
            
    except Exception as e:
        print()
        print("=" * 60)
        print("ERROR: Cleanup failed")
        print("=" * 60)
        print(f"Error: {e}")
        print()
        print("Please check:")
        print("1. Database credentials in .env file")
        print("2. Internet connection")
        print("3. Database is accessible")
        print()
        print("For alternative methods, see db/RUN_CLEANUP.md")
        print()
        sys.exit(1)
    finally:
        await engine.dispose()


if __name__ == "__main__":
    try:
        asyncio.run(cleanup_database())
    except KeyboardInterrupt:
        print("\n\nCleanup cancelled by user.")
        sys.exit(0)