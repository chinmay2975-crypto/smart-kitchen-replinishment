@echo off
echo ========================================
echo Smart Kitchen - Starting Application
echo ========================================
echo.

REM Check if backend is already running
netstat -ano | findstr ":8000.*LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo Backend is already running on port 8000
) else (
    echo Starting backend server...
    
    REM Start backend in a new window
    start "Smart Kitchen Backend" cmd /c "uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
    
    REM Wait for backend to start
    echo Waiting for backend to start...
    timeout /t 3 /nobreak >nul
    
    REM Check if backend started successfully
    netstat -ano | findstr ":8000.*LISTENING" >nul 2>&1
    if %errorlevel% equ 0 (
        echo Backend started successfully!
    ) else (
        echo Warning: Backend may not have started properly
    )
)

echo.
echo ========================================
echo Opening Frontend...
echo ========================================
echo.

REM Open frontend with Live Server or default browser
REM Try to use Live Server if available, otherwise open directly
where code >nul 2>&1
if %errorlevel% equ 0 (
    echo Opening with VS Code Live Server...
    code frontend/index.html
) else (
    echo Opening in default browser...
    start frontend/index.html
)

echo.
echo ========================================
echo Application Started!
echo ========================================
echo Backend API: http://localhost:8000
echo API Docs: http://localhost:8000/docs
echo Health Check: http://localhost:8000/health
echo.
echo Close this window or press Ctrl+C to stop
echo ========================================
echo.

REM Keep the window open
pause