# Database Cleanup Instructions

## Overview
This guide provides multiple methods to clean up all user data from the database so you can test fresh registrations with the fixed code.

## Database Information
- **Database Type**: PostgreSQL (Supabase)
- **Connection**: See `.env` file for `DATABASE_URL`
- **Tables to Clean**: All user-created data (users, households, devices, inventory, orders, etc.)
- **Preserved Data**: Database schema and seed data (suppliers)

---

## Method 1: Using psql Command Line (Recommended)

### Prerequisites
- PostgreSQL client (`psql`) installed on your system
- Database credentials from `.env` file

### Steps

1. **Extract database credentials from `.env`**:
   ```bash
   DATABASE_URL=postgresql+asyncpg://postgres.eqjianefzeaighbjegye:Chinmay2005%40@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?ssl=require
   ```

2. **Convert asyncpg URL to standard PostgreSQL format**:
   - Remove `+asyncpg` from the protocol
   - Decode the password (`%40` → `@`)
   - Result: `postgresql://postgres.eqjianefzeaighbjegye:Chinmay2005@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?ssl=require`

3. **Run the cleanup script**:
   ```bash
   psql "postgresql://postgres.eqjianefzeaighbjegye:Chinmay2005@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?ssl=require" -f db/cleanup_users.sql
   ```

### Alternative: One-liner command
```bash
psql "postgresql://postgres.eqjianefzeaighbjegye:Chinmay2005@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?sslmode=require" -c "SET session_replication_role = replica; DELETE FROM household_preferences; DELETE FROM household_members; DELETE FROM inventory_changes; DELETE FROM inventory_current; DELETE FROM order_line_items; DELETE FROM replenishment_orders; DELETE FROM sensor_readings; DELETE FROM device_events; DELETE FROM telemetry_5min; DELETE FROM devices; DELETE FROM product_catalog; DELETE FROM households; DELETE FROM alert_log; DELETE FROM app_users; SET session_replication_role = DEFAULT; SELECT 'Cleanup completed' as status;"
```

---

## Method 2: Using Python Script

Create a Python script to run the cleanup:

```python
#!/usr/bin/env python3
"""
Database cleanup script for Smart Kitchen Replenishment System
Removes all user data while preserving schema and seed data
"""

import asyncio
import os
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL')

async def cleanup_database():
    """Remove all user data from the database"""
    
    # Create async engine
    engine = create_async_engine(DATABASE_URL)
    
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
    UNION ALL SELECT 'devices', COUNT(*) FROM devices
    UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
    """
    
    try:
        async with engine.begin() as conn:
            print("Starting database cleanup...")
            
            # Execute cleanup queries
            for query in cleanup_queries:
                print(f"Executing: {query[:50]}...")
                await conn.execute(text(query))
            
            print("\nCleanup completed successfully!")
            print("\nVerification - Row counts after cleanup:")
            print("-" * 50)
            
            result = await conn.execute(text(verification_query))
            rows = result.fetchall()
            
            for row in rows:
                print(f"{row.table_name:20s}: {row.row_count:3d} rows")
            
            print("-" * 50)
            print("\n✓ All user data removed")
            print("✓ Schema and seed data preserved")
            print("✓ Ready for fresh registrations")
            
    except Exception as e:
        print(f"Error during cleanup: {e}")
        raise
    finally:
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(cleanup_database())
```

### Run the Python script:
```bash
python db/cleanup_database.py
```

---

## Method 3: Using Supabase Web Interface

### Steps

1. **Open Supabase Dashboard**:
   - Go to https://supabase.com/dashboard
   - Navigate to your project

2. **Open SQL Editor**:
   - Click on "SQL Editor" in the left sidebar
   - Click "New query"

3. **Copy and paste the cleanup script**:
   - Open `db/cleanup_users.sql`
   - Copy all the DELETE statements (lines 14-42)
   - Paste into the SQL Editor
   - Click "Run" to execute

4. **Verify cleanup**:
   - Copy the verification query (lines 47-62)
   - Paste into a new SQL query
   - Run to see row counts

---

## Method 4: Quick Cleanup via API (If you have admin endpoints)

If your backend has an admin endpoint for cleanup, you can use:

```bash
curl -X POST https://backend-309488529038.asia-south1.run.app/api/v1/admin/cleanup-database \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json"
```

*Note: You would need to implement this admin endpoint first.*

---

## Verification

After running any cleanup method, verify the database is clean:

### Check specific tables:
```sql
-- Should return 0 rows
SELECT COUNT(*) FROM app_users;
SELECT COUNT(*) FROM households;
SELECT COUNT(*) FROM devices;
SELECT COUNT(*) FROM product_catalog;
SELECT COUNT(*) FROM inventory_current;

-- Should still have 4 rows (suppliers)
SELECT COUNT(*) FROM suppliers;
```

### Expected Results:
- `app_users`: 0 rows
- `households`: 0 rows
- `devices`: 0 rows
- `product_catalog`: 0 rows
- `inventory_current`: 0 rows
- `suppliers`: 4 rows (preserved seed data)

---

## Testing the Fix

After cleanup, test the registration with these scenarios:

### Test 1: Fresh Registration (Should Succeed)
```
Name: Test User
Email: test@example.com
Phone: 9876543210
Password: TestPass123
```
**Expected**: Registration succeeds

### Test 2: Duplicate Email (Should Fail with specific message)
```
Name: Another User
Email: test@example.com  (same as above)
Phone: 9876543211
Password: TestPass123
```
**Expected**: "Email already registered"

### Test 3: Duplicate Phone (Should Fail with specific message)
```
Name: Third User
Email: test3@example.com
Phone: 9876543210  (same as Test 1)
Password: TestPass123
```
**Expected**: "Phone number already registered"

### Test 4: Phone Format Variations (All should be treated as same)
Try registering with these phone formats - all should be detected as duplicates:
- `9876543210`
- `+919876543210`
- `91 98765 43210`
- `+91-98765-43210`

### Test 5: Email Case Variations (All should be treated as same)
Try registering with these email formats - all should be detected as duplicates:
- `Test@Example.com`
- `test@example.com`
- `TEST@EXAMPLE.COM`

---

## Troubleshooting

### Issue: "Permission denied" when running psql
**Solution**: Make sure you're using the correct database credentials from `.env`

### Issue: "Relation does not exist"
**Solution**: The database schema hasn't been initialized. Run `db/init.sql` first.

### Issue: "Foreign key violation"
**Solution**: Make sure to delete in the correct order (child tables before parent tables). The provided script handles this correctly.

### Issue: Cleanup doesn't work on Supabase
**Solution**: Supabase may have Row Level Security (RLS). You might need to disable RLS temporarily or use the Supabase dashboard SQL Editor.

---

## Rollback (If Needed)

If you need to restore data after cleanup:
- **Option 1**: Restore from database backup
- **Option 2**: If using Supabase, use the "Backups" section in the dashboard
- **Option 3**: Re-run `db/init.sql` to reset to initial state (will lose all data including suppliers)

---

## Next Steps

After cleanup and testing:
1. Deploy the fixed backend code (`app/routers/auth.py`)
2. Deploy the fixed frontend code (`frontend/js/auth.js`)
3. Test the registration flow thoroughly
4. Monitor logs for any issues

---

## Support

If you encounter issues:
1. Check the backend logs for detailed error messages
2. Verify database connection in `.env` file
3. Ensure all dependencies are installed (`pip install -r requirements.txt`)
4. Check that the backend server is running