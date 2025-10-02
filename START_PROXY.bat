@echo off
REM ============================================
REM UEX-Discord Webhook Proxy Starter
REM PowerShell Version - Kein Node.js nötig!
REM ============================================
title UEX-Discord Webhook Proxy
color 0A

cls
echo ============================================
echo    UEX-DISCORD WEBHOOK PROXY
echo    Format-Übersetzer (PowerShell)
echo ============================================
echo.
echo Dieser Proxy übersetzt das UEX Format
echo für Discord, damit die Nachrichten ankommen!
echo.
echo ============================================
echo.

REM Prüfe ob config.txt existiert
if not exist "webhook-config.txt" (
    echo Discord Webhook URL eingeben:
    echo.
    set /p WEBHOOK="URL: "
    echo !WEBHOOK! > webhook-config.txt
) else (
    set /p WEBHOOK=<webhook-config.txt
    echo Nutze gespeicherte Webhook URL
    echo.
)

echo Starte Proxy auf Port 3000...
echo.
echo ============================================
echo.

REM Starte PowerShell Proxy
powershell -ExecutionPolicy Bypass -Command "& { $webhook = '%WEBHOOK%'; Write-Host 'Discord Webhook konfiguriert' -ForegroundColor Green; & '.\webhook-proxy.ps1' -Port 3000 -DiscordWebhook $webhook }"

pause
