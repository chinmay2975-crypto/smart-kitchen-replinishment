@echo off
echo ========================================
echo Starting Smart Kitchen Backend Server
echo ========================================
echo.
echo Backend will run on: http://localhost:8000
echo API docs available at: http://localhost:8000/docs
echo.
echo Press Ctrl+C to stop the server
echo ========================================
echo.

cd /d "%~dp0"

REM Check if virtual environment exists
if exist venv\Scripts\activate.bat (
    echo Activating virtual environment...
    call venv\Scripts\activate.bat
)

REM Install dependencies if needed
echo Checking dependencies...
pip install -q -r requirements.txt

REM Start the server
echo Starting server...
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause