# Smart Kitchen Replenishment System - Setup Guide

## Prerequisites
- Python 3.8+ installed
- pip (Python package manager)
- A modern web browser
- Supabase project (already configured)

## Step 1: Test Database Connection

First, verify that your backend can connect to Supabase:

```bash
python test_supabase_connection.py
```

**Expected output:**
- ✓ Connection successful!
- ✓ UUID extension working!
- List of existing tables (or "No tables found" if fresh)

If this fails, check:
- Your Supabase project is active
- Database credentials in `.env` are correct
- You have internet connectivity

## Step 2: Initialize Database Schema

If the connection test shows no tables, you need to initialize the schema:

### Option A: Using Supabase Dashboard (Recommended)
1. Go to https://supabase.com/dashboard/project/eqjianefzeaighbjegye/editor
2. Click on "SQL Editor" in the left sidebar
3. Click "New query"
4. Copy the entire contents of `db/init_supabase.sql`
5. Paste into the SQL editor
6. Click "Run" to execute

### Option B: Using psql command line
```bash
psql "postgresql://postgres.eqjianefzeaighbjegye:Chinmay2005@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?ssl=require" -f db/init_supabase.sql
```

## Step 3: Start the Backend Server

### Option A: Using the batch script (Windows)
Double-click `start_backend.bat` in your file explorer

### Option B: Using command line
```bash
# Install dependencies (first time only)
pip install -r requirements.txt

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Expected output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

The backend will be available at:
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

## Step 4: Open the Frontend

### Option A: Using VS Code Live Server (Recommended)
1. Install the "Live Server" extension in VS Code
2. Right-click on `frontend/index.html`
3. Select "Open with Live Server"
4. The app will open at `http://localhost:5500` (or similar)

### Option B: Direct browser open
Simply double-click `frontend/index.html` to open it in your default browser

## Step 5: Test Login/Register

### Test Registration
1. Click on the "Register" tab
2. Fill in the form:
   - Name: Your name
   - Email: your.email@example.com
   - Phone: +919876543210
   - Password: (minimum 6 characters)
   - Confirm Password: (same as above)
3. Click "Register"
4. You should see a success message and be logged in automatically

### Test Login
1. Click on the "Sign In" tab
2. Enter the email and password you just registered
3. Click "Sign In"
4. You should be redirected to the dashboard

## Troubleshooting

### Backend won't start
- Check if port 8000 is already in use
- Verify Python dependencies are installed: `pip install -r requirements.txt`
- Check the console for error messages

### Can't connect to database
- Run `python test_supabase_connection.py` to diagnose
- Verify `.env` file has correct credentials
- Check Supabase dashboard to ensure project is not paused

### Login/Register fails
- Open browser DevTools (F12) → Console tab to see errors
- Check backend console for error logs
- Verify the database tables were created (run the schema init if needed)
- Ensure CORS is enabled (it should be by default)

### Frontend can't reach backend
- Verify backend is running on http://localhost:8000
- Check `frontend/js/api.js` has `API_BASE = 'http://localhost:8000'`
- If using Live Server, ensure it's running on a different port (usually 5500)
- Check browser console for CORS errors

## Switching Between Local and Production

### To use local backend:
In `frontend/js/api.js`:
```javascript
const API_BASE = 'http://localhost:8000';
```

### To use production (Render):
In `frontend/js/api.js`:
```javascript
const API_BASE = 'https://smart-kitchen-api.onrender.com';
```

## API Documentation

When the backend is running, visit:
- http://localhost:8000/docs - Interactive API documentation (Swagger UI)
- http://localhost:8000/redoc - Alternative API documentation

## Project Structure

```
smart-kitchen-replenishment/
├── app/
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Configuration settings
│   ├── database.py          # Database connection setup
│   ├── routers/
│   │   ├── auth.py          # Login/Register endpoints
│   │   ├── devices.py       # Device management
│   │   └── iot.py           # IoT telemetry
│   └── services/
│       ├── data_simulator.py    # Simulates device data
│       └── replenishment_engine.py  # Auto-replenishment logic
├── frontend/
│   ├── index.html           # Main HTML file
│   └── js/
│       ├── api.js           # API client
│       ├── auth.js          # Authentication UI logic
│       ├── dashboard.js     # Dashboard functionality
│       └── devices.js       # Device management UI
├── db/
│   └── init_supabase.sql    # Database schema for Supabase
├── .env                     # Environment variables (database credentials)
├── requirements.txt         # Python dependencies
├── test_supabase_connection.py  # Database connection test
└── start_backend.bat        # Windows startup script
```

## Next Steps

Once login is working:
1. Explore the dashboard to see inventory data
2. Register devices in the Devices section
3. Test the replenishment engine
4. Customize thresholds and preferences

## Support

If you encounter issues:
1. Check the backend console for error logs
2. Check browser DevTools console for frontend errors
3. Verify database connection with the test script
4. Ensure all prerequisites are installed