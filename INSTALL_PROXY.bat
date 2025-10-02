@echo off
REM ============================================
REM UEX-Discord Webhook Proxy - Windows Setup
REM ============================================
title UEX-Discord Webhook Proxy Setup
color 0A

:header
cls
echo ============================================
echo    UEX-DISCORD WEBHOOK PROXY
echo    Format-Übersetzer Installation
echo ============================================
echo.
echo PROBLEM GELOEST: UEX sendet falsches JSON-Format!
echo.
echo Dieser Proxy übersetzt:
echo   UEX Format --^> Discord Format
echo.
echo ============================================
echo.
pause

:check_nodejs
echo Prüfe Node.js Installation...
where node >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo [!] Node.js ist nicht installiert!
    echo.
    echo Moechtest du Node.js jetzt installieren? (j/n)
    set /p install_node="Auswahl: "
    if /i "!install_node!"=="j" (
        echo Lade Node.js Installer...
        powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.10.0/node-v20.10.0-x64.msi' -OutFile 'node-installer.msi'"
        echo Starte Installation...
        msiexec /i node-installer.msi
        del node-installer.msi
        echo.
        echo Bitte starte dieses Script nach der Installation neu!
        pause
        exit
    ) else (
        echo.
        echo Alternative: Nutze die Cloud-Version (siehe README)
        pause
        exit
    )
)

echo [OK] Node.js gefunden: 
node --version
echo.

:setup
echo Erstelle Proxy-Server Verzeichnis...
set PROXY_DIR=%USERPROFILE%\Documents\UEX-Discord-Proxy
mkdir "%PROXY_DIR%" 2>nul
cd /d "%PROXY_DIR%"

:create_package_json
echo Erstelle package.json...
(
echo {
echo   "name": "uex-discord-webhook-proxy",
echo   "version": "1.0.0",
echo   "description": "Übersetzt UEX Webhook Format zu Discord Format",
echo   "main": "server.js",
echo   "scripts": {
echo     "start": "node server.js",
echo     "test": "curl http://localhost:3000/test"
echo   },
echo   "dependencies": {
echo     "express": "^4.18.2",
echo     "axios": "^1.6.0",
echo     "dotenv": "^16.3.1"
echo   }
echo }
) > package.json

:copy_server
echo Kopiere Server-Datei...
copy "%~dp0webhook-proxy-server.js" "%PROXY_DIR%\server.js" >nul

:get_discord_webhook
echo.
echo ============================================
echo    DISCORD WEBHOOK KONFIGURATION
echo ============================================
echo.
set /p DISCORD_WEBHOOK="Discord Webhook URL eingeben: "

:create_env
echo Erstelle Konfiguration...
(
echo # UEX-Discord Proxy Konfiguration
echo DISCORD_WEBHOOK=%DISCORD_WEBHOOK%
echo PORT=3000
echo DEBUG=true
) > .env

:install_dependencies
echo.
echo Installiere Dependencies...
call npm install

:create_start_script
echo Erstelle Start-Script...
(
echo @echo off
echo title UEX-Discord Webhook Proxy
echo color 0A
echo cls
echo echo ============================================
echo echo    UEX-DISCORD WEBHOOK PROXY
echo echo ============================================
echo echo.
echo node server.js
echo pause
) > start-proxy.bat

:create_service_installer
echo Erstelle Windows Service Installer...
(
echo @echo off
echo echo Installiere als Windows Service...
echo npm install -g node-windows
echo node -e "const Service = require('node-windows').Service; const svc = new Service({name:'UEX Discord Proxy', description:'UEX to Discord Webhook Translator', script:'%PROXY_DIR%\\server.js'}); svc.on('install', () => svc.start()); svc.install();"
echo pause
) > install-as-service.bat

:test_setup
echo.
echo ============================================
echo    TESTE PROXY SERVER
echo ============================================
echo.

echo Starte Proxy Server...
start /B node server.js >server.log 2>&1

timeout /t 3 /nobreak >nul

echo.
echo Sende Test-Nachricht...
curl -X GET http://localhost:3000/test

echo.
echo ============================================
echo    INSTALLATION ERFOLGREICH!
echo ============================================
echo.
echo Proxy Server läuft auf: http://localhost:3000
echo.
echo WICHTIG - Gib UEX diese Webhook URL:
echo.

:get_ip
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        set LOCAL_IP=%%b
        goto :found_ip
    )
)
:found_ip

echo   ╔════════════════════════════════════════════╗
echo   ║                                            ║
echo   ║   http://%LOCAL_IP%:3000/webhook           ║
echo   ║                                            ║
echo   ╚════════════════════════════════════════════╝
echo.
echo Diese URL in UEX eintragen statt der Discord URL!
echo.
echo Proxy Verzeichnis: %PROXY_DIR%
echo.
echo Befehle:
echo   start-proxy.bat        - Proxy starten
echo   install-as-service.bat - Als Windows Dienst
echo.
pause
