# ============================================================
#  LPC Pickleball — Web Dev Launcher
#  Starts the PayMongo CORS proxy AND Flutter web simultaneously.
#
#  Usage:  Right-click → "Run with PowerShell"
#          OR in terminal: .\run_web.ps1
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  LPC Pickleball Web Launcher" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Start the CORS proxy in a background window ────────────────────────────
Write-Host "[1/3] Starting PayMongo CORS Proxy..." -ForegroundColor Yellow

$proxyJob = Start-Process powershell -ArgumentList `
    "-NoProfile -Command `"cd '$PSScriptRoot'; dart run bin/cors_proxy.dart`"" `
    -PassThru -WindowStyle Normal

Write-Host "      Proxy PID: $($proxyJob.Id)" -ForegroundColor Green
Write-Host "      Waiting 2 seconds for proxy to bind to port 8085..." -ForegroundColor DarkGray
Start-Sleep -Seconds 2

# ── 2. Start Arduino LCD Bridge in a background window ────────────────────────
Write-Host ""
Write-Host "[2/3] Starting Arduino LCD Bridge (Court 1)..." -ForegroundColor Yellow

$bridgeJob = Start-Process powershell -ArgumentList `
    "-NoProfile -Command `"cd '$PSScriptRoot\arduino'; python firebase_to_arduino.py --court 1`"" `
    -PassThru -WindowStyle Normal

Write-Host "      Bridge PID: $($bridgeJob.Id)" -ForegroundColor Green
Start-Sleep -Seconds 1

# ── 3. Start Flutter web ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/3] Starting Flutter Web..." -ForegroundColor Yellow
Write-Host "      Press Ctrl+C to stop proxy, Arduino bridge, and Flutter." -ForegroundColor DarkGray
Write-Host ""

try {
    Set-Location $PSScriptRoot
    flutter run -d chrome --web-port 53029
} finally {
    # ── Cleanup: kill proxy and bridge when Flutter exits ──────────────────────
    Write-Host ""
    Write-Host "Stopping CORS proxy (PID $($proxyJob.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $proxyJob.Id -Force -ErrorAction SilentlyContinue

    if ($bridgeJob) {
        Write-Host "Stopping Arduino LCD bridge (PID $($bridgeJob.Id))..." -ForegroundColor Yellow
        Stop-Process -Id $bridgeJob.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Done." -ForegroundColor Green
}
