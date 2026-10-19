@echo off
title LPC Pickleball - Web App Launcher
color 0A

echo.
echo  ============================================================
echo   LPC Pickleball Web App Launcher
echo   Starting PayMongo proxy + Arduino Bridge + Flutter web...
echo  ============================================================
echo.

cd /d "%~dp0"

echo  [1/3] Starting PayMongo CORS Proxy in background...
start "PayMongo CORS Proxy" cmd /c "dart run bin/cors_proxy.dart"

echo  [2/3] Starting Arduino LCD Bridge in background...
start "Arduino LCD Bridge" cmd /c "python arduino/firebase_to_arduino.py"

echo  [3/3] Waiting for services to initialize...
timeout /t 3 /nobreak > nul

echo  Launching Flutter Web App...
echo.
flutter run -d chrome --web-port 53029

echo.
echo  Done. Press any key to close.
pause > nul
