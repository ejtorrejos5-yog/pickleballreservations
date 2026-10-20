@echo off
title LPC Pickleball - Arduino LCD Bridge
cd /d "%~dp0arduino"

echo ====================================================
echo   LPC Pickleball - Arduino LCD Bridge
echo   1 LCD = 1 Court System (Auto-Started)
echo ====================================================
echo.

set courtChoice=%1
if "%courtChoice%"=="" set courtChoice=1

echo Starting bridge for Court %courtChoice%...
echo Serial port will be auto-detected (COM3).
echo.
python firebase_to_arduino.py --court %courtChoice%
pause

