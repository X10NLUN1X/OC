# 🔧 UEX-Discord Webhook Format Problem - GELÖST!

## ⚠️ Das Problem

**Discord erwartet:**
```json
{
  "content": "Text",
  "embeds": [{...}]
}
```

**UEX sendet:**
```json
{
  "client_username": "...",
  "negotiation_hash": "...",
  "listing_id": 123
}
```

**Discord versteht das UEX-Format nicht!** Deshalb kommen keine Nachrichten an.

## ✅ Die Lösungen

### Lösung 1: Lokaler Proxy Server (Empfohlen)

**Installation:**
1. Führe `INSTALL_PROXY.bat` aus
2. Gib deine Discord Webhook URL ein
3. Der Proxy startet automatisch

**In UEX eintragen:**
```
http://DEINE_IP:3000/webhook
```
(statt der Discord URL)

**Ablauf:**
```
UEX → Dein Proxy (Port 3000) → Discord
     ↑                      ↑
  Original Format    Übersetztes Format
```

---

### Lösung 2: Kostenlose Cloud Services

#### Option A: Pipedream (Empfohlen - Kostenlos)

1. **Account erstellen:** https://pipedream.com (kostenlos)

2. **Neuen Workflow erstellen:**
   - "New Workflow" → "HTTP / Webhook" Trigger

3. **Code Step hinzufügen:**
```javascript
export default defineComponent({
  async run({ steps, $ }) {
    // UEX Daten
    const uex = steps.trigger.event.body;
    
    // Übersetze zu Discord Format
    const discord = {
      embeds: [{
        title: uex.negotiation_hash ? "🤝 Neue Verhandlung" : "📦 UEX Update",
        color: 3447003,
        fields: Object.entries(uex).map(([key, value]) => ({
          name: key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
          value: String(value),
          inline: true
        })),
        timestamp: new Date().toISOString()
      }]
    };
    
    // Sende an Discord
    await $.send.http({
      method: "POST",
      url: "DEINE_DISCORD_WEBHOOK_URL",
      data: discord
    });
    
    return { success: true };
  }
})
```

4. **Deploy & URL kopieren**
5. **Diese URL in UEX eintragen**

---

#### Option B: Vercel (Kostenlos)

1. **Erstelle `api/webhook.js`:**
```javascript
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  const uexData = req.body;
  
  // Konvertiere UEX zu Discord
  const discordPayload = {
    embeds: [{
      title: '🚀 UEX Update',
      description: uexData.message || 'Neue Aktivität',
      fields: Object.entries(uexData).slice(0, 10).map(([k, v]) => ({
        name: k,
        value: String(v),
        inline: true
      }))
    }]
  };
  
  // Sende an Discord
  const response = await fetch(process.env.DISCORD_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(discordPayload)
  });
  
  res.status(200).json({ success: true });
}
```

2. **Deploy zu Vercel:**
```bash
npm i -g vercel
vercel
```

3. **Webhook URL:** `https://dein-projekt.vercel.app/api/webhook`

---

#### Option C: Cloudflare Workers (100k Requests/Tag kostenlos)

```javascript
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }
  
  const uexData = await request.json()
  
  // Discord Webhook URL (in Worker Settings setzen)
  const DISCORD_URL = DISCORD_WEBHOOK // Environment Variable
  
  // Konvertiere Format
  const discordPayload = {
    username: uexData.client_username || 'UEX Bot',
    embeds: [{
      title: '🎮 UEX Marketplace',
      fields: Object.entries(uexData).map(([key, val]) => ({
        name: key,
        value: String(val),
        inline: true
      }))
    }]
  }
  
  // Sende an Discord
  await fetch(DISCORD_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(discordPayload)
  })
  
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
}
```

---

### Lösung 3: Discord Bot statt Webhook

**Vorteil:** Mehr Kontrolle & Features

1. **Bot erstellen:** https://discord.com/developers/applications
2. **Bot Token kopieren**
3. **Simple Bot Script:**

```python
# bot.py
import discord
from flask import Flask, request
import threading

client = discord.Client(intents=discord.Intents.default())
app = Flask(__name__)

CHANNEL_ID = 123456789  # Dein Channel

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    
    # Erstelle Discord Embed
    embed = discord.Embed(
        title="UEX Update",
        color=0x00ff00
    )
    
    for key, value in data.items():
        embed.add_field(name=key, value=str(value), inline=True)
    
    # Sende an Channel
    channel = client.get_channel(CHANNEL_ID)
    client.loop.create_task(channel.send(embed=embed))
    
    return {'success': True}

@client.event
async def on_ready():
    print(f'Bot ist online als {client.user}')

# Starte Flask in Thread
threading.Thread(target=lambda: app.run(port=3000)).start()

# Starte Bot
client.run('DEIN_BOT_TOKEN')
```

---

## 🧪 Testen der Lösungen

### Test ob Proxy funktioniert:

```bash
# Test UEX Format
curl -X POST http://localhost:3000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "client_username": "TestUser",
    "negotiation_hash": "abc123",
    "listing_id": 456,
    "price": 1000
  }'
```

### Direkt Discord testen (funktioniert):
```bash
curl -X POST https://discord.com/api/webhooks/XXX/YYY \
  -H "Content-Type: application/json" \
  -d '{"content": "Test"}'
```

---

## 📊 Vergleich der Lösungen

| Lösung | Vorteile | Nachteile |
|--------|----------|-----------|
| **Lokaler Proxy** | Volle Kontrolle, Keine Limits | PC muss laufen |
| **Pipedream** | Kostenlos, Cloud, Einfach | 100 Req/Tag Limit |
| **Vercel** | Kostenlos, Schnell | Etwas technisch |
| **Cloudflare** | 100k Req/Tag, Schnell | Setup komplexer |
| **Discord Bot** | Mehr Features | Komplexer |

---

## 🚀 Schnellstart (2 Minuten)

1. **Einfachste Lösung:** Nutze Pipedream
   - Kostenloser Account
   - Copy & Paste Code
   - Fertig!

2. **Beste Lösung:** Lokaler Proxy
   - Führe `INSTALL_PROXY.bat` aus
   - Läuft auf deinem PC
   - Keine Limits

---

## ❓ FAQ

**Q: Warum funktioniert mein Webhook nicht?**
A: UEX sendet das falsche JSON-Format. Discord versteht es nicht.

**Q: Muss der Proxy immer laufen?**
A: Ja, er übersetzt zwischen UEX und Discord.

**Q: Ist das sicher?**
A: Ja, der Proxy leitet nur Daten weiter. Nutze HTTPS für extra Sicherheit.

**Q: Kann UEX das nicht direkt fixen?**
A: Das wäre ideal, aber bis dahin brauchen wir den Proxy.

---

## 💡 Pro-Tipps

1. **Mehrere Discord Channels:**
   - Modifiziere den Proxy für verschiedene Event-Typen
   - Sende Verhandlungen zu Channel A, Listings zu Channel B

2. **Filter einbauen:**
   - Nur Items über 1000 aUEC
   - Nur bestimmte Spieler

3. **Erweiterte Formatierung:**
   - Füge Bilder hinzu
   - Nutze Discord Buttons
   - Mentions für wichtige Events

---

**Das Format-Problem ist gelöst! Wähle eine Lösung und los geht's!** 🎉
