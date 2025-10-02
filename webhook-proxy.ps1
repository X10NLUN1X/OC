# ============================================
# UEX zu Discord Webhook Proxy - PowerShell
# ============================================
# Kein Node.js nötig! Läuft mit Windows PowerShell

param(
    [int]$Port = 3000,
    [string]$DiscordWebhook = "",
    [switch]$Debug
)

# ============================================
# KONFIGURATION
# ============================================

if (-not $DiscordWebhook) {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "   UEX-DISCORD WEBHOOK PROXY (PowerShell)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $DiscordWebhook = Read-Host "Discord Webhook URL eingeben"
    
    if (-not $DiscordWebhook -or $DiscordWebhook -like "*YOUR_WEBHOOK*") {
        Write-Host "Fehler: Keine gültige Webhook URL!" -ForegroundColor Red
        exit 1
    }
}

# HTTP Listener erstellen
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
$listener.Prefixes.Add("http://localhost:$Port/")

# ============================================
# FUNKTIONEN
# ============================================

function Convert-UEXToDiscord {
    param($UEXData)
    
    $embed = @{
        title = "📢 UEX Update"
        color = 3447003
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        fields = @()
    }
    
    # Erkenne Event-Typ
    if ($UEXData.negotiation_hash -or $UEXData.negotiation_id) {
        $embed.title = "🤝 Neue Verhandlung"
        $embed.color = 3447003  # Blau
    }
    elseif ($UEXData.listing_id) {
        $embed.title = "📦 Listing Update"
        $embed.color = 15844367  # Gold
    }
    elseif ($UEXData.message -or $UEXData.content) {
        $embed.title = "💬 Neue Nachricht"
        $embed.color = 3066993  # Grün
        $embed.description = $UEXData.message
    }
    
    # Konvertiere alle Felder
    foreach ($property in $UEXData.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value
        
        # Skip unwichtige Felder
        if ($name -in @('client_username', 'client_avatar')) {
            continue
        }
        
        # Formatiere Feldnamen
        $displayName = $name -replace '_', ' '
        $displayName = (Get-Culture).TextInfo.ToTitleCase($displayName)
        
        $embed.fields += @{
            name = $displayName
            value = [string]$value
            inline = $true
        }
    }
    
    # Discord Payload
    $discordPayload = @{
        username = if ($UEXData.client_username) { $UEXData.client_username } else { "UEX Trading Bot" }
        avatar_url = if ($UEXData.client_avatar) { $UEXData.client_avatar } else { "https://uexcorp.space/assets/images/logo.png" }
        embeds = @($embed)
    }
    
    return $discordPayload
}

function Send-ToDiscord {
    param($Payload)
    
    try {
        $json = $Payload | ConvertTo-Json -Depth 10 -Compress
        
        if ($Debug) {
            Write-Host "Sende an Discord:" -ForegroundColor Yellow
            Write-Host $json -ForegroundColor Gray
        }
        
        $response = Invoke-RestMethod -Uri $DiscordWebhook -Method Post -Body $json -ContentType "application/json"
        return $true
    }
    catch {
        Write-Host "Discord Fehler: $_" -ForegroundColor Red
        return $false
    }
}

function Start-WebhookProxy {
    try {
        $listener.Start()
        
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "   WEBHOOK PROXY LÄUFT" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Proxy URL für UEX:" -ForegroundColor Cyan
        
        # Zeige alle verfügbaren IPs
        $ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" }
        foreach ($ip in $ips) {
            Write-Host "  http://$($ip.IPAddress):$Port/webhook" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Test-URLs:" -ForegroundColor Cyan
        Write-Host "  http://localhost:$Port/test" -ForegroundColor Gray
        Write-Host "  http://localhost:$Port/status" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Discord Webhook: $($DiscordWebhook.Substring(0, 50))..." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Warte auf Webhooks... (STRG+C zum Beenden)" -ForegroundColor Green
        Write-Host ""
        
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] $($request.HttpMethod) $($request.Url.LocalPath)" -NoNewline
            
            # Route handling
            switch ($request.Url.LocalPath) {
                "/webhook" {
                    if ($request.HttpMethod -eq "POST") {
                        # Lese Request Body
                        $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        
                        if ($Debug) {
                            Write-Host " - Body: $body" -ForegroundColor Gray
                        }
                        
                        try {
                            $uexData = $body | ConvertFrom-Json
                            
                            # Konvertiere und sende
                            $discordPayload = Convert-UEXToDiscord -UEXData $uexData
                            $success = Send-ToDiscord -Payload $discordPayload
                            
                            if ($success) {
                                Write-Host " ✓ Weitergeleitet an Discord" -ForegroundColor Green
                                $responseJson = '{"success": true, "message": "Forwarded to Discord"}'
                                $response.StatusCode = 200
                            }
                            else {
                                Write-Host " ✗ Discord Fehler" -ForegroundColor Red
                                $responseJson = '{"success": false, "error": "Discord forward failed"}'
                                $response.StatusCode = 500
                            }
                        }
                        catch {
                            Write-Host " ✗ Parse Fehler: $_" -ForegroundColor Red
                            $responseJson = '{"success": false, "error": "Invalid JSON"}'
                            $response.StatusCode = 400
                        }
                    }
                    else {
                        Write-Host " - Method not allowed" -ForegroundColor Yellow
                        $responseJson = '{"error": "Only POST allowed"}'
                        $response.StatusCode = 405
                    }
                }
                
                "/test" {
                    Write-Host " - Sende Test-Nachricht..." -NoNewline
                    
                    $testPayload = @{
                        embeds = @(
                            @{
                                title = "🧪 Proxy Test Erfolgreich"
                                description = "Der UEX-Discord Proxy funktioniert!"
                                color = 65280
                                fields = @(
                                    @{ name = "Status"; value = "✅ Online"; inline = $true }
                                    @{ name = "Port"; value = $Port; inline = $true }
                                    @{ name = "Zeit"; value = (Get-Date).ToString("HH:mm:ss"); inline = $true }
                                )
                                timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                            }
                        )
                    }
                    
                    $success = Send-ToDiscord -Payload $testPayload
                    if ($success) {
                        Write-Host " ✓" -ForegroundColor Green
                        $responseJson = '{"success": true, "message": "Test message sent to Discord"}'
                    }
                    else {
                        Write-Host " ✗" -ForegroundColor Red
                        $responseJson = '{"success": false, "error": "Failed to send test"}'
                    }
                }
                
                "/status" {
                    Write-Host " - Status" -ForegroundColor Gray
                    $status = @{
                        status = "running"
                        port = $Port
                        webhook_configured = $true
                        debug_mode = $Debug.IsPresent
                    }
                    $responseJson = $status | ConvertTo-Json
                }
                
                "/" {
                    Write-Host " - Info" -ForegroundColor Gray
                    $responseJson = @"
{
    "service": "UEX to Discord Webhook Proxy",
    "version": "1.0 PowerShell",
    "endpoints": {
        "webhook": "POST /webhook - Receive UEX webhooks",
        "test": "GET /test - Send test message",
        "status": "GET /status - Service status"
    }
}
"@
                }
                
                default {
                    Write-Host " - 404 Not Found" -ForegroundColor Yellow
                    $responseJson = '{"error": "Endpoint not found"}'
                    $response.StatusCode = 404
                }
            }
            
            # Sende Response
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseJson)
            $response.ContentLength64 = $buffer.Length
            $response.ContentType = "application/json"
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
    }
    catch {
        Write-Host "Fehler: $_" -ForegroundColor Red
    }
    finally {
        $listener.Stop()
    }
}

# ============================================
# HAUPTPROGRAMM
# ============================================

# Admin-Rechte prüfen (für Port-Binding)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin -and $Port -lt 1024) {
    Write-Host "WARNUNG: Ports unter 1024 benötigen Admin-Rechte!" -ForegroundColor Yellow
    Write-Host "Nutze Port 3000 oder höher, oder starte als Administrator." -ForegroundColor Yellow
    exit 1
}

# Firewall-Regel hinzufügen (optional)
if ($isAdmin) {
    $ruleName = "UEX Discord Proxy Port $Port"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    
    if (-not $existingRule) {
        Write-Host "Füge Firewall-Regel hinzu für Port $Port..." -ForegroundColor Yellow
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
        Write-Host "Firewall-Regel hinzugefügt" -ForegroundColor Green
    }
}

# Cleanup bei Beendigung
Register-EngineEvent PowerShell.Exiting -Action {
    if ($listener.IsListening) {
        $listener.Stop()
    }
} | Out-Null

# Starte Proxy
try {
    Start-WebhookProxy
}
catch {
    Write-Host "Kritischer Fehler: $_" -ForegroundColor Red
    if ($_.Exception.Message -like "*Access denied*") {
        Write-Host "Port $Port ist möglicherweise belegt oder benötigt Admin-Rechte." -ForegroundColor Yellow
        Write-Host "Versuche einen anderen Port: .\webhook-proxy.ps1 -Port 8080" -ForegroundColor Yellow
    }
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    Write-Host "`nProxy beendet." -ForegroundColor Yellow
}
