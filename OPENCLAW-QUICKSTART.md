# OpenClaw Quick Start - AWS Bedrock Setup

Schnelleinstieg für OpenClaw mit LiteLLM/AWS Bedrock in 5 Minuten.

## ✅ Voraussetzungen

```bash
ssh root@192.168.1.11

# 1. LiteLLM läuft
systemctl status litellm-proxy
# → active (running) ✓

# 2. Health Check
curl http://localhost:4000/health
# → {"status":"healthy"} ✓
```

---

## 🚀 Setup in 3 Schritten

### Schritt 1: OpenClaw Setup

```bash
openclaw setup
```

**Eingaben:**
- Gateway mode: `local` ⏎
- Workspace: (Standard) ⏎
- Provider: `custom` ⏎

### Schritt 2: Configure

```bash
openclaw configure
```

**Navigation:**
1. Wähle: `Models` ⏎
2. Wähle: `Add provider` ⏎
3. Wähle: `openai-compatible` ⏎

**Eingaben:**
```
Provider name: litellm-bedrock
Base URL: http://localhost:4000
API key: bedrock
Default model: claude-sonnet-4-6
Verify connection: Y
Set as default: Y
```

**Dann:** `Done / Exit`

### Schritt 3: Gateway starten

```bash
openclaw gateway run &
sleep 5
openclaw status
```

---

## 🧪 Test

```bash
# Test 1: Model
openclaw infer complete --model claude-sonnet-4-6 --prompt "Say OK"

# Test 2: Agent
openclaw agent --to dev-agent --message "Hello" --deliver

# Test 3: Interactive
openclaw tui
```

---

## 📋 Configure Wizard Cheat Sheet

### Hauptmenü

```
openclaw configure
→ Models           ← Wähle dies für Bedrock Setup
  Gateway          ← Optional (Standard OK)
  Channels         ← Optional (für Discord/Slack)
  Plugins
  Skills
  Health Checks
  Advanced
  Done / Exit
```

### Models Menü

```
Models
→ Add provider     ← Wähle dies
  Remove provider
  Set default
  List providers
  Test connection
  Back
```

### Provider Type

```
Provider type:
  anthropic
  openai
  bedrock          ← NICHT dies (LiteLLM übernimmt Bedrock)
  azure
→ openai-compatible ← Wähle dies für LiteLLM
  ollama
  groq
  together
```

### Provider Details

| Feld | Eingabe | Hinweis |
|------|---------|---------|
| Provider name | `litellm-bedrock` | Frei wählbar |
| Base URL | `http://localhost:4000` | LiteLLM Port |
| API key | `bedrock` | Platzhalter (beliebig!) |
| Default model | `claude-sonnet-4-6` | Muss mit LiteLLM-Config übereinstimmen |
| Verify connection | `Y` | Test durchführen |
| Set as default | `Y` | Als Standard setzen |

---

## 🔑 API Key Erklärung

**❓ Warum "bedrock" als API Key?**

| Was | Wo | Zweck |
|-----|-----|-------|
| **AWS Credentials** | `/opt/openclaw/config/litellm.env` | ✅ Echte Authentifizierung |
| **API Key (bei configure)** | OpenClaw Config | ❌ Nur Platzhalter |

**Flow:**
```
OpenClaw
  → sendet: Authorization: Bearer bedrock
LiteLLM
  → ignoriert "bedrock"
  → nutzt AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
  → authentifiziert bei AWS Bedrock
```

**Du kannst eingeben:** `bedrock`, `anything`, `dummy`, ... (beliebig!)

---

## ✅ Erfolgreich wenn:

```bash
openclaw status
```

**Zeigt:**
```
Gateway: ✓ Running
Models: litellm-bedrock ✓
Default: claude-sonnet-4-6 ✓
Agents: 5 (dev, review, security, ops, main)
Health: ✓ All systems operational
```

---

## 🐛 Häufige Probleme

### LiteLLM nicht erreichbar

```bash
systemctl restart litellm-proxy
sleep 5
curl http://localhost:4000/health
```

### Gateway läuft nicht

```bash
pkill -f "openclaw gateway"
openclaw gateway run &
sleep 5
openclaw status
```

### Model nicht gefunden

```bash
# Prüfe LiteLLM-Config
cat /opt/openclaw/config/litellm-config.yaml

# Model-Name muss übereinstimmen:
model_list:
  - model_name: claude-sonnet-4-6  # ← Dieser Name!
```

---

## 📚 Vollständige Dokumentation

- **Detailliert:** [docs/OPENCLAW-CONFIGURE-WALKTHROUGH.md](docs/OPENCLAW-CONFIGURE-WALKTHROUGH.md)
- **Gateway:** [docs/GATEWAY-SETUP.md](docs/GATEWAY-SETUP.md)
- **Integration:** [docs/LITELLM-OPENCLAW-INTEGRATION.md](docs/LITELLM-OPENCLAW-INTEGRATION.md)

---

**Ready to go! 🚀**
