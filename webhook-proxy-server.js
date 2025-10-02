/**
 * UEX zu Discord Webhook Proxy Server
 * 
 * Problem: UEX sendet eigenes JSON-Format, Discord erwartet anderes Format
 * Lösung: Dieser Proxy übersetzt zwischen beiden Formaten
 * 
 * Ablauf:
 * 1. UEX sendet an diesen Proxy (statt direkt an Discord)
 * 2. Proxy konvertiert UEX-Format zu Discord-Format
 * 3. Proxy leitet an Discord weiter
 */

const express = require('express');
const axios = require('axios');
const app = express();

// ============================================
// KONFIGURATION
// ============================================

const CONFIG = {
    // Dieser Proxy läuft auf Port 3000
    PROXY_PORT: process.env.PORT || 3000,
    
    // Dein echter Discord Webhook
    DISCORD_WEBHOOK_URL: process.env.DISCORD_WEBHOOK || 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE',
    
    // Debug-Modus
    DEBUG: process.env.DEBUG === 'true',
    
    // Webhook Secret (optional für Sicherheit)
    SECRET: process.env.WEBHOOK_SECRET || ''
};

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request Logging
app.use((req, res, next) => {
    if (CONFIG.DEBUG) {
        console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
        console.log('Headers:', req.headers);
        console.log('Body:', req.body);
    }
    next();
});

// ============================================
// WEBHOOK TRANSLATOR
// ============================================

/**
 * Konvertiert UEX Format zu Discord Format
 */
function convertUEXToDiscord(uexData) {
    // Standard Discord Nachricht
    let discordPayload = {
        username: uexData.client_username || 'UEX Trading Bot',
        avatar_url: uexData.client_avatar || 'https://uexcorp.space/assets/images/logo.png'
    };

    // Erkenne den UEX Event-Typ und erstelle passende Discord Embed
    if (uexData.negotiation_hash || uexData.negotiation_id) {
        // Neue Verhandlung
        discordPayload.embeds = [{
            title: '🤝 Neue Verhandlung',
            color: 3447003, // Blau
            fields: [
                {
                    name: 'Verhandlungs-ID',
                    value: uexData.negotiation_hash || uexData.negotiation_id || 'N/A',
                    inline: true
                },
                {
                    name: 'Käufer',
                    value: uexData.buyer || uexData.buyer_username || 'Unbekannt',
                    inline: true
                },
                {
                    name: 'Verkäufer', 
                    value: uexData.seller || uexData.seller_username || 'Unbekannt',
                    inline: true
                }
            ],
            timestamp: new Date().toISOString()
        }];
        
        // Füge weitere Felder hinzu wenn vorhanden
        if (uexData.item_name) {
            discordPayload.embeds[0].fields.push({
                name: 'Artikel',
                value: uexData.item_name,
                inline: false
            });
        }
        if (uexData.price) {
            discordPayload.embeds[0].fields.push({
                name: 'Preis',
                value: `${uexData.price} aUEC`,
                inline: true
            });
        }
        if (uexData.quantity) {
            discordPayload.embeds[0].fields.push({
                name: 'Menge',
                value: uexData.quantity.toString(),
                inline: true
            });
        }
        
    } else if (uexData.listing_id) {
        // Listing Update
        discordPayload.embeds = [{
            title: '📦 Listing Update',
            color: 15844367, // Gold
            fields: [
                {
                    name: 'Listing ID',
                    value: uexData.listing_id.toString(),
                    inline: true
                },
                {
                    name: 'Artikel',
                    value: uexData.item_name || uexData.name || 'N/A',
                    inline: true
                },
                {
                    name: 'Preis',
                    value: `${uexData.price || 0} aUEC`,
                    inline: true
                },
                {
                    name: 'Status',
                    value: uexData.status || 'Aktiv',
                    inline: true
                }
            ],
            timestamp: new Date().toISOString()
        }];
        
    } else if (uexData.message || uexData.content) {
        // Chat-Nachricht
        discordPayload.embeds = [{
            title: '💬 Neue Nachricht',
            description: uexData.message || uexData.content,
            color: 3066993, // Grün
            fields: [
                {
                    name: 'Von',
                    value: uexData.sender || uexData.from || 'Unbekannt',
                    inline: true
                },
                {
                    name: 'Zeit',
                    value: new Date().toLocaleString('de-DE'),
                    inline: true
                }
            ],
            timestamp: new Date().toISOString()
        }];
        
    } else {
        // Fallback: Zeige alle Daten als JSON
        const fields = [];
        for (const [key, value] of Object.entries(uexData)) {
            if (key !== 'client_username' && key !== 'client_avatar' && value) {
                // Konvertiere snake_case zu Title Case
                const fieldName = key.replace(/_/g, ' ')
                    .replace(/\b\w/g, l => l.toUpperCase());
                
                fields.push({
                    name: fieldName,
                    value: value.toString().substring(0, 1024),
                    inline: fields.length % 2 === 0
                });
            }
        }
        
        discordPayload.embeds = [{
            title: '📢 UEX Update',
            color: 9807270, // Grau
            fields: fields.length > 0 ? fields : [
                { name: 'Daten', value: JSON.stringify(uexData).substring(0, 1024) }
            ],
            timestamp: new Date().toISOString(),
            footer: {
                text: 'UEX Webhook Proxy'
            }
        }];
    }
    
    // Füge Raw-Daten im Debug-Modus hinzu
    if (CONFIG.DEBUG && discordPayload.embeds && discordPayload.embeds[0]) {
        discordPayload.embeds[0].footer = {
            text: `Debug: ${Object.keys(uexData).join(', ')}`
        };
    }
    
    return discordPayload;
}

// ============================================
// ROUTES
// ============================================

// Health Check
app.get('/', (req, res) => {
    res.json({
        status: 'running',
        service: 'UEX to Discord Webhook Proxy',
        endpoints: {
            webhook: '/webhook',
            test: '/test',
            health: '/'
        }
    });
});

// Test Endpoint
app.get('/test', async (req, res) => {
    try {
        const testPayload = {
            content: '✅ Proxy Server Test erfolgreich!',
            embeds: [{
                title: '🧪 Webhook Proxy Test',
                description: 'Der UEX zu Discord Proxy funktioniert!',
                color: 65280,
                fields: [
                    { name: 'Status', value: 'Online', inline: true },
                    { name: 'Zeit', value: new Date().toLocaleString('de-DE'), inline: true }
                ],
                timestamp: new Date().toISOString()
            }]
        };
        
        const response = await axios.post(CONFIG.DISCORD_WEBHOOK_URL, testPayload);
        
        res.json({
            success: true,
            message: 'Test-Nachricht gesendet! Prüfe Discord.',
            discord_status: response.status
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Hauptendpoint - Empfängt UEX Webhooks
app.post('/webhook', async (req, res) => {
    try {
        console.log(`[${new Date().toISOString()}] Webhook empfangen von UEX`);
        
        // Optional: Prüfe Secret für Sicherheit
        if (CONFIG.SECRET && req.headers['x-webhook-secret'] !== CONFIG.SECRET) {
            return res.status(401).json({ error: 'Unauthorized' });
        }
        
        // Konvertiere UEX Format zu Discord Format
        const discordPayload = convertUEXToDiscord(req.body);
        
        if (CONFIG.DEBUG) {
            console.log('Konvertierte Payload:', JSON.stringify(discordPayload, null, 2));
        }
        
        // Sende an Discord
        const discordResponse = await axios.post(CONFIG.DISCORD_WEBHOOK_URL, discordPayload, {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        console.log(`[${new Date().toISOString()}] An Discord weitergeleitet: ${discordResponse.status}`);
        
        // Antworte an UEX
        res.status(200).json({
            success: true,
            message: 'Webhook processed and forwarded to Discord',
            discord_status: discordResponse.status
        });
        
    } catch (error) {
        console.error(`[${new Date().toISOString()}] Fehler:`, error.message);
        
        // Detaillierte Fehlerinfo im Debug-Modus
        if (CONFIG.DEBUG && error.response) {
            console.error('Discord Response:', error.response.data);
        }
        
        res.status(500).json({
            success: false,
            error: error.message,
            details: CONFIG.DEBUG ? error.response?.data : undefined
        });
    }
});

// Catch-All für andere Methoden
app.all('/webhook', (req, res) => {
    res.status(405).json({
        error: 'Method not allowed',
        allowed: ['POST']
    });
});

// 404 Handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Endpoint not found',
        available_endpoints: {
            webhook: 'POST /webhook',
            test: 'GET /test',
            health: 'GET /'
        }
    });
});

// ============================================
// SERVER START
// ============================================

const server = app.listen(CONFIG.PROXY_PORT, '0.0.0.0', () => {
    console.log('============================================');
    console.log('   UEX zu Discord Webhook Proxy Server');
    console.log('============================================');
    console.log(`✅ Server läuft auf Port ${CONFIG.PROXY_PORT}`);
    console.log(`📍 Webhook Endpoint: http://localhost:${CONFIG.PROXY_PORT}/webhook`);
    console.log(`🧪 Test Endpoint: http://localhost:${CONFIG.PROXY_PORT}/test`);
    console.log('');
    console.log('Konfiguration:');
    console.log(`- Discord Webhook: ${CONFIG.DISCORD_WEBHOOK_URL.substring(0, 50)}...`);
    console.log(`- Debug Modus: ${CONFIG.DEBUG ? 'AN' : 'AUS'}`);
    console.log('');
    console.log('Nächste Schritte:');
    console.log('1. Teste mit: curl http://localhost:3000/test');
    console.log('2. Gib UEX diese Webhook URL:');
    console.log(`   http://DEINE_IP:${CONFIG.PROXY_PORT}/webhook`);
    console.log('');
    console.log('Drücke STRG+C zum Beenden');
    console.log('============================================');
});

// Graceful Shutdown
process.on('SIGINT', () => {
    console.log('\n[INFO] Server wird heruntergefahren...');
    server.close(() => {
        console.log('[INFO] Server beendet');
        process.exit(0);
    });
});

// Error Handler
process.on('uncaughtException', (error) => {
    console.error('[FATAL] Uncaught Exception:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('[FATAL] Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

module.exports = app; // Für Tests
