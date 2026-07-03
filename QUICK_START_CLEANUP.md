# Quick Start: Clean Database for Testing

## Your Database is Ready to Clean!

You have **4 methods** to remove all registered user data and start fresh:

---

## 🚀 Method 1: Windows Batch File (Easiest)

```bash
# Just double-click this file:
db/cleanup.bat
```

**Requirements**: PostgreSQL client (psql) installed and in PATH

---

## 🐍 Method 2: Python Script (Recommended)

```bash
# Make sure you have the required packages:
pip install sqlalchemy asyncpg python-dotenv

# Run the cleanup script:
python db/cleanup_database.py
```

**Requirements**: Python 3.7+, required packages installed

---

## 💻 Method 3: Command Line (psql)

```bash
# One-line command:
psql "postgresql://postgres.eqjianefzeaighbjegye:Chinmay2005@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?sslmode=require" -c "SET session_replication_role = replica; DELETE FROM household_preferences; DELETE FROM household_members; DELETE FROM inventory_changes; DELETE FROM inventory_current; DELETE FROM order_line_items; DELETE FROM replenishment_orders; DELETE FROM sensor_readings; DELETE FROM device_events; DELETE FROM telemetry_5min; DELETE FROM devices; DELETE FROM product_catalog; DELETE FROM households; DELETE FROM alert_log; DELETE FROM app_users; SET session_replication_role = DEFAULT; SELECT 'Cleanup completed!' as status;"
```

---

## 🌐 Method 4: Supabase Dashboard (No Installation Needed)

1. Go to https://supabase.com/dashboard
2. Open your project
3. Go to **SQL Editor**
4. Copy contents from `db/cleanup_users.sql`
5. Paste and click **Run**

---

## ✅ What Gets Deleted

- ✓ All user accounts
- ✓ All households
- ✓ All devices and sensor data
- ✓ All inventory and orders
- ✓ All preferences and memberships

## 🛡️ What Gets Preserved

- ✓ Database schema
- ✓ Seed data (4 suppliers)
- ✓ Table structures and indexes

---

## 🧪 After Cleanup - Test the Fix

### Test 1: Fresh Registration (Should Succeed)
```
Name: Test User
Email: test@example.com
Phone: 9876543210
Password: TestPass123
```
**Expected**: ✅ Registration succeeds

### Test 2: Duplicate Email (Should Fail)
```
Name: Another User
Email: test@example.com  (same as above)
Phone: 9876543211
Password: TestPass123
```
**Expected**: ❌ "Email already registered"

### Test 3: Duplicate Phone (Should Fail)
```
Name: Third User
Email: test3@example.com
Phone: 9876543210  (same as Test 1)
Password: TestPass123
```
**Expected**: ❌ "Phone number already registered"

### Test 4: Phone Format Variations (All Same)
Try these - all should be detected as duplicates:
- `9876543210`
- `+919876543210`
- `91 98765 43210`
- `+91-98765-43210`

### Test 5: Email Case Variations (All Same)
Try these - all should be detected as duplicates:
- `Test@Example.com`
- `test@example.com`
- `TEST@EXAMPLE.COM`

---

## 📋 Verification

After cleanup, verify with these queries:

```sql
-- Should return 0 rows (all user data removed)
SELECT COUNT(*) FROM app_users;
SELECT COUNT(*) FROM households;
SELECT COUNT(*) FROM devices;

-- Should return 4 rows (suppliers preserved)
SELECT COUNT(*) FROM suppliers;
```

---

## 🚨 Troubleshooting

### "psql is not recognized"
- Install PostgreSQL: https://www.postgresql.org/download/windows/
- Or use Method 2 (Python) or Method 4 (Supabase Dashboard)

### "Connection refused"
- Check your internet connection
- Verify database credentials in `.env` file
- Ensure Supabase project is active

### "Permission denied"
- Make sure you're using the correct credentials from `.env`
- Try using Supabase Dashboard (Method 4)

---

## 📝 Files Created

1. **`db/cleanup_users.sql`** - SQL cleanup script
2. **`db/cleanup_database.py`** - Python cleanup script
3. **`db/cleanup.bat`** - Windows batch file
4. **`db/RUN_CLEANUP.md`** - Detailed instructions
5. **`REGISTRATION_FIX_SUMMARY.md`** - Bug fix documentation

---

## 🎯 Next Steps

1. **Run cleanup** using any of the methods above
2. **Verify** database is clean (0 users, 4 suppliers)
3. **Deploy** the fixed code:
   - Backend: `app/routers/auth.py`
   - Frontend: `frontend/js/auth.js`
4. **Test** registration with the test cases above
5. **Monitor** logs for any issues

---

## 📞 Need Help?

- Check `db/RUN_CLEANUP.md` for detailed troubleshooting
- Review `REGISTRATION_FIX_SUMMARY.md` for bug fix details
- Check backend logs for error messages

---

**Ready to clean?** Choose a method above and run it! 🎉