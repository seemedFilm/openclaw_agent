# OpenClaw Configure - Vollständiger Walkthrough

Schritt-für-Schritt Anleitung für `openclaw configure` mit LiteLLM/AWS Bedrock.

## 📋 Übersicht

Der `openclaw configure` Wizard ist ein interaktives Menü mit mehreren Konfigurationsbereichen:
- ✅ **Models** - Model Provider (LiteLLM/Bedrock)
- **Gateway** - Gateway-Einstellungen
- **Channels** - Messaging-Kanäle (Discord, Slack, etc.)
- **Plugins** - Plugin-Verwaltung
- **Skills** - Agent-Skills
- **Health Checks** - Health-Check-Intervalle
- **Advanced** - Erweiterte Einstellungen

**Für AWS Bedrock Setup:** Wir konfigurieren nur **Models**.

---

## 🚀 Voraussetzungen

```bash
# 1. SSH auf Container
ssh root@192.168.1.11

# 2. LiteLLM läuft
systemctl status litellm-proxy
# Expected: active (running)

# 3. LiteLLM Health Check
curl http://localhost:4000/health
# Expected: {"status":"healthy"}

# 4. OpenClaw Setup wurde ausgeführt
ls ~/.openclaw/openclaw.json
# Expected: Datei existiert
```

---

## 🎯 Configure Wizard starten

```bash
openclaw configure
```

**Expected:** Hauptmenü erscheint

```
╔════════════════════════════════════════════════════════════════╗
║               OpenClaw Configuration Wizard                     ║
╚════════════════════════════════════════════════════════════════╝

? What would you like to configure? (Use arrow keys)
  ❯ Models             - Add/remove model providers and set defaults
    Gateway            - Gateway host, port, and mode settings
    Channels           - Add or update messaging channels
    Plugins            - Enable/disable plugins
    Skills             - Manage agent skills
    Health Checks      - Configure health check intervals
    Advanced           - Expert settings
    ─────────────────
    Done / Exit
```

---

## ⚙️ Schritt 1: Models konfigurieren

### 1.1 Models Menü öffnen

**Aktion:** Pfeiltaste zu `Models` → Enter

```
? Model configuration: (Use arrow keys)
  ❯ Add provider       - Add a new model provider
    Remove provider    - Remove an existing provider
    Set default        - Set default provider and model
    List providers     - Show all configured providers
    Test connection    - Test provider connection
    ─────────────────
    Back               - Return to main menu
```

### 1.2 Provider hinzufügen

**Aktion:** `Add provider` ist bereits ausgewählt → Enter

```
? Provider type: (Use arrow keys)
    anthropic          - Claude via Anthropic API (direct)
    openai             - GPT models via OpenAI API
    bedrock            - AWS Bedrock (configure AWS credentials)
    azure              - Azure OpenAI Service
  ❯ openai-compatible  - OpenAI-compatible API (LiteLLM, Ollama, etc.)
    ollama             - Local Ollama instance
    groq               - Groq API
    together           - Together AI
```

**⚠️ WICHTIG:** Wähle `openai-compatible` (NICHT `bedrock`)

**Warum?**
- LiteLLM präsentiert eine OpenAI-kompatible API
- LiteLLM kommuniziert intern mit Bedrock
- OpenClaw → LiteLLM → Bedrock

**Aktion:** Pfeiltaste zu `openai-compatible` → Enter

---

## 📝 Schritt 2: Provider-Details eingeben

### 2.1 Provider Name

```
? Provider name: _
```

**Eingabe:** `litellm-bedrock` → Enter

**ℹ️ Info:** Der Name ist frei wählbar, sollte aber beschreibend sein.

---

### 2.2 Base URL

```
? Base URL: _
```

**Eingabe:** `http://localhost:4000` → Enter

**ℹ️ Info:** LiteLLM läuft auf Port 4000 (siehe `/etc/systemd/system/litellm-proxy.service`)

---

### 2.3 API Key

```
? API key: _
```

**Eingabe:** `bedrock` → Enter

**🔑 WICHTIG - API Key Erklärung:**

| Was | Wo | Zweck |
|-----|-----|-------|
| **AWS Credentials** | `/opt/openclaw/config/litellm.env` | ✅ Echte Authentifizierung bei AWS Bedrock |
| **API Key (hier)** | OpenClaw Config | ❌ Nur Platzhalter (wird von LiteLLM ignoriert) |

**Warum ein Platzhalter?**
- OpenAI-kompatible APIs erwarten `Authorization: Bearer <key>`
- LiteLLM akzeptiert jeden beliebigen Key
- Echte Authentifizierung: AWS Credentials (bereits konfiguriert in `.env`)

**Du kannst eingeben:**
- `bedrock` ← Empfohlen
- `anything`
- `dummy`
- `openclaw`
- ... (beliebig!)

---

### 2.4 Default Model ID

```
? Default model ID: _
```

**Eingabe:** `claude-sonnet-4-6` → Enter

**ℹ️ Info:** Dieser Name muss mit der LiteLLM-Config übereinstimmen:

```yaml
# /opt/openclaw/config/litellm-config.yaml
model_list:
  - model_name: claude-sonnet-4-6  # ← Dieser Name!
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-6
```

---

### 2.5 Verbindung testen

```
? Verify connection now? (Y/n) _
```

**Eingabe:** `Y` → Enter

**Expected Output:**
```
Testing connection to http://localhost:4000...
⠋ Connecting...
✓ Successfully connected to litellm-bedrock
✓ Model claude-sonnet-4-6 is available
✓ Latency: 45ms
✓ Provider added successfully
```

**Falls Fehler:**

```
✗ Connection failed: ECONNREFUSED
```

**Lösung:**
```bash
# LiteLLM prüfen
systemctl status litellm-proxy

# Neu starten falls nötig
systemctl restart litellm-proxy
sleep 5

# Erneut testen
curl http://localhost:4000/health
```

---

### 2.6 Als Default Provider setzen

```
? Set litellm-bedrock as default provider? (Y/n) _
```

**Eingabe:** `Y` → Enter

```
✓ litellm-bedrock set as default provider
✓ claude-sonnet-4-6 set as default model
```

**Zurück zum Models-Menü:**

```
? Model configuration:
    Add provider       - Add a new model provider
    Remove provider    - Remove an existing provider
  ❯ Set default        - Set default provider and model
    List providers     - Show all configured providers
    Test connection    - Test provider connection
    ─────────────────
    Back               - Return to main menu
```

**Aktion:** Pfeiltaste zu `Back` → Enter

---

## ✅ Schritt 3: Konfiguration abschließen

**Zurück im Hauptmenü:**

```
? What would you like to configure?
  ❯ Models             - Add/remove model providers and set defaults ✓
    Gateway            - Gateway host, port, and mode settings
    Channels           - Add or update messaging channels
    Plugins            - Enable/disable plugins
    Skills             - Manage agent skills
    Health Checks      - Configure health check intervals
    Advanced           - Expert settings
    ─────────────────
    Done / Exit
```

**ℹ️ Info:** `Models` zeigt jetzt ein ✓ (konfiguriert)

### Weitere Konfiguration?

#### Option A: Fertig (für Bedrock-Setup)

**Aktion:** Pfeiltaste zu `Done / Exit` → Enter

```
✓ Configuration saved to ~/.openclaw/openclaw.json
✓ Backup created: ~/.openclaw/openclaw.json.bak

Summary:
  Model Providers: 1 (litellm-bedrock)
  Default Model: claude-sonnet-4-6
  Gateway: local (port 18789)
  Channels: 0
  Plugins: 0 enabled

Ready to start Gateway!
```

#### Option B: Gateway konfigurieren (Optional)

**Für die meisten Setups nicht nötig**, aber hier die Optionen:

**Aktion:** Pfeiltaste zu `Gateway` → Enter

```
? Gateway configuration:
  ❯ Mode               - Local, remote, or hosted
    Host               - Gateway bind address (default: 0.0.0.0)
    Port               - Gateway port (default: 18789)
    Auth               - Enable/disable authentication
    CORS               - Configure CORS settings
    ─────────────────
    Back
```

**Standard-Werte (empfohlen für lokales Setup):**
- Mode: `local`
- Host: `127.0.0.1` (nur localhost) oder `0.0.0.0` (alle Interfaces)
- Port: `18789`
- Auth: `disabled` (für lokales Setup OK)

**Aktion:** `Back` → Enter (Standard-Werte verwenden)

#### Option C: Channels hinzufügen (Optional)

**Für Discord/Slack/Telegram Integration:**

**Aktion:** Pfeiltaste zu `Channels` → Enter

```
? Channel configuration:
  ❯ Add channel        - Add a new messaging channel
    Remove channel     - Remove an existing channel
    Test channel       - Test channel connection
    ─────────────────
    Back
```

**Für AWS Bedrock Setup:** Nicht nötig, zurück mit `Back`

---

## 🧪 Schritt 4: Konfiguration verifizieren

### 4.1 Config-Datei prüfen

```bash
cat ~/.openclaw/openclaw.json | jq .
```

**Expected:**

```json
{
  "models": {
    "providers": {
      "litellm-bedrock": {
        "type": "openai-compatible",
        "baseUrl": "http://localhost:4000",
        "apiKey": "bedrock",
        "models": {
          "claude-sonnet-4-6": {
            "id": "claude-sonnet-4-6",
            "name": "Claude Sonnet 4.6",
            "maxTokens": 4096,
            "default": true
          }
        }
      }
    },
    "defaultProvider": "litellm-bedrock",
    "defaultModel": "claude-sonnet-4-6"
  },
  "gateway": {
    "mode": "local",
    "port": 18789,
    "host": "0.0.0.0"
  }
}
```

### 4.2 Config validieren

```bash
openclaw config validate
```

**Expected:**
```
✓ Configuration is valid
✓ All required fields present
✓ Model provider reachable
```

### 4.3 Model Status prüfen

```bash
openclaw models status
```

**Expected:**
```
Model Providers:
  litellm-bedrock:
    Type: openai-compatible
    URL: http://localhost:4000
    Status: ✓ Connected
    Latency: 42ms
    Default Model: claude-sonnet-4-6
    Models Available:
      - claude-sonnet-4-6 (default) ✓
```

---

## 🚀 Schritt 5: Gateway starten

```bash
# Gateway im Hintergrund starten
openclaw gateway run &

# Warte bis ready
sleep 5

# Status prüfen
openclaw status
```

**Expected:**
```
OpenClaw Status:

Gateway:
  Status: ✓ Running
  Port: 18789
  Uptime: 5s

Models:
  Provider: litellm-bedrock ✓
  Default: claude-sonnet-4-6 ✓
  Latency: 45ms

Agents:
  Total: 5
  Active: 0

Health: ✓ All systems operational
```

---

## 🧪 Schritt 6: End-to-End Test

### Test 1: Model direkt testen

```bash
openclaw infer complete \
  --model claude-sonnet-4-6 \
  --prompt "Say OK" \
  --max-tokens 5
```

**Expected:**
```
OK
```

### Test 2: Agent testen

```bash
openclaw agent \
  --to dev-agent \
  --message "Hello, introduce yourself briefly" \
  --deliver
```

**Expected:**
```
Hello! I'm the Development Agent (dev-agent), a senior software engineer
specialized in code development with Claude Sonnet 4.6 via AWS Bedrock.
How can I help you today?
```

### Test 3: Interactive TUI

```bash
openclaw tui
```

**Im TUI:**
1. Wähle `dev-agent` aus der Liste
2. Tippe: "What can you help me with?"
3. Erwarte vollständige Antwort

**Expected:** Agent antwortet mit seinen Capabilities

---

## 🐛 Troubleshooting

### Problem: "Connection refused"

```bash
openclaw configure
# Error: Cannot connect to http://localhost:4000
```

**Lösung:**

```bash
# 1. LiteLLM Status
systemctl status litellm-proxy

# 2. Falls nicht running
systemctl restart litellm-proxy

# 3. Warte
sleep 5

# 4. Test
curl http://localhost:4000/health

# 5. Erneut configure
openclaw configure
```

---

### Problem: "Model not found"

```bash
openclaw models status
# Error: Model "claude-sonnet-4-6" not found
```

**Ursache:** Model-Name stimmt nicht mit LiteLLM-Config überein.

**Lösung:**

```bash
# 1. LiteLLM-Config prüfen
cat /opt/openclaw/config/litellm-config.yaml

# Expected:
model_list:
  - model_name: claude-sonnet-4-6  # ← Dieser Name!

# 2. Falls anderer Name, in OpenClaw Config ändern
nano ~/.openclaw/openclaw.json

# 3. Model ID anpassen
"id": "claude-sonnet-4-6"  # Muss übereinstimmen!

# 4. Validieren
openclaw config validate
```

---

### Problem: "Invalid API key"

```bash
openclaw infer complete --model claude-sonnet-4-6 --prompt "test"
# Error: 401 Unauthorized
```

**Ursache:** LiteLLM mit `master_key` gesichert (selten).

**Lösung:**

```bash
# 1. LiteLLM-Config prüfen
cat /opt/openclaw/config/litellm-config.yaml | grep master_key

# Falls master_key gesetzt:
general_settings:
  master_key: "sk-1234"  # Dieser Key muss verwendet werden

# 2. In OpenClaw Config aktualisieren
openclaw configure
# Models → Add provider → API key: sk-1234

# Standard-Setup hat KEINEN master_key, dann ist "bedrock" OK
```

---

## 📝 Zusammenfassung

### Was wurde konfiguriert:

✅ **Model Provider:** litellm-bedrock  
✅ **Base URL:** http://localhost:4000  
✅ **API Key:** bedrock (Platzhalter)  
✅ **Default Model:** claude-sonnet-4-6  
✅ **Gateway:** local, Port 18789  

### Echte Authentifizierung:

✅ **AWS Credentials:** `/opt/openclaw/config/litellm.env`  
✅ **AWS Region:** eu-central-1  
✅ **Bedrock Model:** eu.anthropic.claude-sonnet-4-6  

### Nächste Schritte:

1. Gateway starten: `openclaw gateway run &`
2. Status prüfen: `openclaw status`
3. Agents testen: `openclaw tui`

---

## 📚 Weiterführende Dokumentation

- **Gateway Setup:** [GATEWAY-SETUP.md](GATEWAY-SETUP.md)
- **LiteLLM Integration:** [LITELLM-OPENCLAW-INTEGRATION.md](LITELLM-OPENCLAW-INTEGRATION.md)
- **Quick Reference:** [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

---

**Version:** 1.0.0  
**Letzte Aktualisierung:** 2026-06-02
