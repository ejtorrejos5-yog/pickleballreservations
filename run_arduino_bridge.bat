@echo off
title LPC Pickleball - Arduino LCD Bridge
cd /d "%~dp0arduino"

echo ====================================================
echo   LPC Pickleball - Arduino LCD Bridge
echo   1 LCD = 1 Court System
echo ====================================================
echo.
echo Select Court for this LCD:
echo   [1] Court 1 (Default)
echo   [2] Court 2
echo   [3] Court 3
echo   [4] Court 4
echo.
set /p courtChoice="Enter court number [1-4] or press Enter for Court 1: "
if "%courtChoice%"=="" set courtChoice=1

echo.
echo Starting bridge for Court %courtChoice%...
python firebase_to_arduino.py --court %courtChoice%
pause
