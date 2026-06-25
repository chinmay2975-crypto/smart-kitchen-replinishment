@echo off
echo ============================================
echo  Smart Kitchen Replenishment System
echo ============================================
echo.

:: Check if Docker is running
docker ps >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Docker is not running.
    echo Please start Docker Desktop manually first.
    echo.
    pause
    exit /b 1
)

echo [1/4] Starting PostgreSQL database...
docker compose up -d
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to start database.
    pause
    exit /b 1
)
echo Database started successfully.
echo.

:: Wait for database to be ready
echo [2/4] Waiting for database to be ready...
:waitloop
docker exec smart-kitchen-db pg_isready -U kitchen_admin -d smart_kitchen >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    timeout /t 3 /nobreak >nul
    goto waitloop
)
echo Database is ready.
echo.

echo [3/4] Installing Python dependencies...
pip install -r requirements.txt >nul 2>&1
echo Dependencies installed.
echo.

echo [4/4] Starting FastAPI backend server...
echo.
echo ============================================
echo  Backend API: http://127.0.0.1:8000
echo  Frontend:    Open frontend/index.html in browser
echo  API Docs:    http://127.0.0.1:8000/docs
echo ============================================
echo.
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause