@echo off
REM ============================================================
REM Database Cleanup Script for Windows
REM Removes all user data while preserving schema and seed data
REM ============================================================

echo.
echo ========================================
echo Database Cleanup Script
echo ========================================
echo.

REM Database credentials from .env file
set PGHOST=aws-1-ap-south-1.pooler.supabase.com
set PGPORT=6543
set PGUSER=postgres.eqjianefzeaighbjegye
set PGPASSWORD=Chinmay2005@
set PGDATABASE=postgres

echo Connecting to database...
echo Host: %PGHOST%
echo Port: %PGPORT%
echo Database: %PGDATABASE%
echo.

REM Check if psql is available
where psql >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: psql (PostgreSQL client) is not installed or not in PATH
    echo.
    echo Please install PostgreSQL client from:
    echo https://www.postgresql.org/download/windows/
    echo.
    echo Or use one of the alternative methods in db/RUN_CLEANUP.md
    pause
    exit /b 1
)

echo Running cleanup script...
echo.

REM Execute the cleanup SQL script
psql -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %PGDATABASE% -f "%~dp0cleanup_users.sql" --set=sslmode=require

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Cleanup completed successfully!
    echo ========================================
    echo.
    echo You can now test fresh registrations.
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Cleanup failed
    echo ========================================
    echo.
    echo Please check:
    echo 1. Database credentials in .env file
    echo 2. Internet connection
    echo 3. Database is accessible
    echo.
    echo For alternative methods, see db/RUN_CLEANUP.md
    echo.
)

pause