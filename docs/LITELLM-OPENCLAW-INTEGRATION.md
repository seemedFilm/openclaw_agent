# LiteLLM + OpenClaw Integration

Vollständige Anleitung zur Integration von LiteLLM (als Proxy für AWS Bedrock) mit OpenClaw für Claude Sonnet 4.6.

## 📋 Übersicht

Diese Integration ermöglicht:
- ✅ OpenClaw nutzt Claude Sonnet 4.6 via AWS Bedrock
- ✅ LiteLLM übersetzt Bedrock → OpenAI-kompatible API
- ✅ Alle 4 Agents verwenden dasselbe Model
- ✅ Keine direkten Anthropic API-Kosten

**Architektur:**

```
OpenClaw Gateway
    ↓ (OpenAI-kompatible API)
LiteLLM Proxy (localhost:4000)
    ↓ (AWS Bedrock API)
AWS Bedrock eu-central-1
    ↓
Claude Sonnet 4.6 (eu.anthropic.claude-sonnet-4-6)
```

---

## 🚀 Voraussetzungen

### 1. LiteLLM läuft bereits

```bash
ssh root@192.168.1.11
systemctl status litellm-proxy
```

**Expected:**
```
● litellm-proxy.service - LiteLLM Proxy for Amazon Bedrock
     Loaded: loaded
     Active: active (running)
```

### 2. LiteLLM Health Check

```bash
curl -s http://localhost:4000/health
```

**Expected:**
```json
{
  "status": "healthy",
  "model": "claude-sonnet-4-6"
}
```

### 3. Test API Call

```bash
curl -s -X POST http://localhost:4000/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "claude-sonnet-4-6",
    "messages": [{"role": "user", "content": "Say OK"}],
    "max_tokens": 5
  }'
```

**Expected:**
```json
{
  "id": "chatcmpl-...",
  "model": "claude-sonnet-4-6",
  "choices": [{
    "message": {
      "content": "OK",
      "role": "assistant"
    }
  }]
}
```

---

## ⚙️ OpenClaw Konfiguration

### Schritt 1: Initial Setup

```bash
ssh root@192.168.1.11

# Falls noch nicht gemacht:
openclaw setup
```

### Schritt 2: Model Provider konfigurieren

```bash
openclaw configure
```

**Im Menü:**

1. Wähle **"Models"**

2. Wähle **"Add custom provider"**

3. Eingaben:

```
? Provider name: litellm-bedrock
? Base URL: http://localhost:4000
? API key: bedrock
? Default model: claude-sonnet-4-6
```

4. Bestätige mit Enter

**Output:**
```
✓ Provider "litellm-bedrock" added
✓ Default model set to "claude-sonnet-4-6"
✓ Configuration saved
```

### Schritt 3: Verify Configuration

```bash
openclaw models status
```

**Expected:**
```
Model Providers:
  litellm-bedrock:
    URL: http://localhost:4000
    Status: ✓ Connected
    Default Model: claude-sonnet-4-6
```

### Schritt 4: Test Model

```bash
openclaw infer complete \
  --model claude-sonnet-4-6 \
  --prompt "Introduce yourself briefly" \
  --max-tokens 100
```

**Expected:**
```
I'm Claude, an AI assistant created by Anthropic. I'm here to help you 
with a wide range of tasks through thoughtful conversation and analysis.
How can I assist you today?
```

---

## 🔧 Manuelle Config-Bearbeitung

Falls `openclaw configure` nicht funktioniert, kannst du die Config manuell bearbeiten:

```bash
nano ~/.openclaw/openclaw.json
```

**Füge hinzu:**

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
  }
}
```

**Validiere Config:**

```bash
openclaw config validate
```

**Expected:**
```
✓ Configuration is valid
```

---

## 🧪 Testing

### Test 1: Gateway Health mit Model

```bash
# Gateway starten (falls nicht läuft)
openclaw gateway run &

# Warte 5 Sekunden
sleep 5

# Health Check
openclaw health
```

**Expected:**
```json
{
  "status": "healthy",
  "gateway": {
    "status": "running",
    "port": 18789
  },
  "models": {
    "litellm-bedrock": {
      "status": "connected",
      "model": "claude-sonnet-4.6"
    }
  }
}
```

### Test 2: Agent with Model

```bash
# Dev-Agent testen
openclaw agent \
  --to dev-agent \
  --message "Hello, introduce yourself" \
  --deliver
```

**Expected:**
```
Hello! I'm the Development Agent (dev-agent), a senior software engineer
working with Claude Sonnet 4.6 via AWS Bedrock...
```

### Test 3: Interactive TUI

```bash
openclaw tui
```

**Im TUI:**
1. Wähle `dev-agent`
2. Tippe: "What can you help me with?"
3. Erwarte vollständige Antwort

---

## 🔄 Agent-spezifische Model-Konfiguration

Jeder Agent kann ein eigenes Model verwenden:

```bash
# Agent-spezifisches Model setzen
openclaw agents set-model dev-agent claude-sonnet-4-6
openclaw agents set-model review-agent claude-sonnet-4-6
openclaw agents set-model security-agent claude-sonnet-4-6
openclaw agents set-model ops-agent claude-sonnet-4-6
```

**Verify:**

```bash
openclaw agents list
```

**Expected:**
```
Agents:
- dev-agent
  Model: claude-sonnet-4-6 ✓
- review-agent
  Model: claude-sonnet-4-6 ✓
- security-agent
  Model: claude-sonnet-4-6 ✓
- ops-agent
  Model: claude-sonnet-4-6 ✓
```

---

## 🐛 Troubleshooting

### Problem: "Cannot connect to model provider"

**Symptom:**
```bash
openclaw models status
# Error: Cannot connect to http://localhost:4000
```

**Diagnose:**

```bash
# 1. LiteLLM Service prüfen
systemctl status litellm-proxy

# 2. Port prüfen
lsof -i :4000

# 3. Health Check
curl http://localhost:4000/health
```

**Lösung:**

```bash
# LiteLLM neu starten
systemctl restart litellm-proxy

# Warten
sleep 5

# Test
curl http://localhost:4000/health

# Gateway neu starten
pkill -f "openclaw gateway"
openclaw gateway run &
```

### Problem: "Invalid API key"

**Symptom:**
```bash
openclaw infer complete --model claude-sonnet-4-6 --prompt "test"
# Error: 401 Unauthorized
```

**Diagnose:**

LiteLLM erwartet beliebigen API-Key (wird ignoriert), aber OpenClaw muss einen setzen.

**Lösung:**

```bash
# Config prüfen
cat ~/.openclaw/openclaw.json | grep -A 5 "litellm-bedrock"

# API Key muss gesetzt sein (beliebiger Wert)
"apiKey": "bedrock"  # oder "anything"
```

### Problem: "Model not found"

**Symptom:**
```bash
openclaw infer complete --model claude-sonnet-4-6 --prompt "test"
# Error: Model "claude-sonnet-4-6" not found
```

**Diagnose:**

Model-Name in OpenClaw stimmt nicht mit LiteLLM-Config überein.

**Lösung:**

```bash
# 1. LiteLLM Config prüfen
cat /opt/openclaw/config/litellm-config.yaml

# Expected:
model_list:
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-6

# 2. OpenClaw Config prüfen
cat ~/.openclaw/openclaw.json | grep '"id"'

# Expected:
"id": "claude-sonnet-4-6"

# Model-Namen müssen übereinstimmen!
```

### Problem: "Timeout"

**Symptom:**
```bash
openclaw infer complete --model claude-sonnet-4-6 --prompt "Long task..."
# Error: Timeout after 30s
```

**Lösung:**

```bash
# Timeout in OpenClaw Config erhöhen
nano ~/.openclaw/openclaw.json

# Füge hinzu:
{
  "models": {
    "providers": {
      "litellm-bedrock": {
        "timeout": 120000  # 120 Sekunden
      }
    }
  }
}

# Gateway neu starten
pkill -f "openclaw gateway"
openclaw gateway run &
```

### Problem: "Rate limit exceeded"

**Symptom:**
```bash
# Nach mehreren Requests:
Error: 429 Too Many Requests
```

**Ursache:** AWS Bedrock Rate Limits erreicht.

**Lösung:**

```bash
# 1. Warte 60 Sekunden
sleep 60

# 2. Retry Strategy in OpenClaw Config
nano ~/.openclaw/openclaw.json

{
  "models": {
    "providers": {
      "litellm-bedrock": {
        "retries": 3,
        "retryDelay": 2000
      }
    }
  }
}

# 3. Für höhere Limits: AWS Support kontaktieren
```

### Problem: "Gateway token missing/mismatch"

**Symptom:**
```bash
openclaw health
# Error: unauthorized: gateway token missing (provide gateway auth token)
```

**Ursache:** Gateway-Auth ist seit OpenClaw 2026.5.22 standardmäßig aktiviert.

**Lösung:**

```bash
# 1. Automatische Reparatur
openclaw doctor --fix

# Doctor generiert automatisch Token und aktualisiert Config
# Expected: "Gateway token configured."

# 2. Gateway neu starten
systemctl restart openclaw-gateway

# 3. Test
openclaw health
# Expected: Status ohne Auth-Fehler
```

**Hinweis:** `openclaw doctor --fix` ist die empfohlene Methode. Gateway-Auth sorgt für bessere Sicherheit, auch bei localhost-Nutzung.

### Problem: "Pairing required" bei TUI

**Symptom:**
```bash
openclaw tui
# Error: Pairing required. Run `openclaw devices list`, approve your request ID, then reconnect.
```

**Ursache:** Device benötigt erweiterte Scopes (operator.admin, operator.pairing).

**Lösung:**

```bash
# 1. Scopes direkt erweitern (einfachste Methode)
jq '.[].scopes += ["operator.admin", "operator.pairing", "operator.read"] | .[].approvedScopes += ["operator.admin", "operator.pairing", "operator.read"]' ~/.openclaw/devices/paired.json > /tmp/paired.json && mv /tmp/paired.json ~/.openclaw/devices/paired.json

# 2. Pending Requests löschen
echo "[]" > ~/.openclaw/devices/pending.json

# 3. Gateway neu starten
systemctl restart openclaw-gateway

# 4. Test
openclaw health
# Expected: Keine Pairing-Fehler

openclaw tui
# Expected: TUI startet
```

**Alternative (wenn jq nicht verfügbar):**
```bash
# Manually edit ~/.openclaw/devices/paired.json
# Add to "scopes" array: "operator.admin", "operator.pairing", "operator.read"
# Add to "approvedScopes" array: "operator.admin", "operator.pairing", "operator.read"
```

---

## 📊 Monitoring

### LiteLLM Metrics

```bash
# Logs ansehen
journalctl -u litellm-proxy -f

# Requests pro Minute
journalctl -u litellm-proxy --since "1 hour ago" | grep "POST /chat/completions" | wc -l
```

### OpenClaw Metrics

```bash
# Gateway Logs
openclaw logs --follow

# Model Usage Stats
openclaw models status --verbose

# Agent Activity
openclaw agents list --with-stats
```

---

## 🔧 Performance-Optimierung

### LiteLLM Caching

```yaml
# /opt/openclaw/config/litellm-config.yaml
model_list:
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: bedrock/eu.anthropic.claude-sonnet-4-6
      aws_region_name: eu-central-1
      cache:
        enabled: true
        ttl: 300  # 5 Minuten
```

### OpenClaw Connection Pooling

```json
{
  "models": {
    "providers": {
      "litellm-bedrock": {
        "maxConcurrency": 5,
        "keepAlive": true
      }
    }
  }
}
```

### Retry Strategy

```json
{
  "models": {
    "providers": {
      "litellm-bedrock": {
        "retries": 3,
        "retryDelay": 1000,
        "retryBackoff": 2
      }
    }
  }
}
```

---

## 🔐 Sicherheit

### LiteLLM nur lokal erreichbar

```bash
# In /etc/systemd/system/litellm-proxy.service
ExecStart=/opt/openclaw/venv/bin/litellm \
  --config /opt/openclaw/config/litellm-config.yaml \
  --host 127.0.0.1 \  # Nur localhost
  --port 4000

systemctl daemon-reload
systemctl restart litellm-proxy
```

### OpenClaw Gateway Authentication

```json
{
  "gateway": {
    "auth": {
      "enabled": true,
      "apiKey": "${OPENCLAW_API_KEY}"
    }
  }
}
```

```bash
# API Key setzen
export OPENCLAW_API_KEY="$(openssl rand -hex 32)"
echo "export OPENCLAW_API_KEY=\"$(openssl rand -hex 32)\"" >> ~/.bashrc
```

### AWS Credentials Rotation

```bash
# Alle 90 Tage rotieren
# 1. Neue AWS Keys erstellen
# 2. In /opt/openclaw/config/litellm.env updaten
# 3. LiteLLM neu starten
systemctl restart litellm-proxy
```

---

## 📚 Weiterführende Dokumentation

- **LiteLLM Setup:** [LITELLM-SETUP.md](LITELLM-SETUP.md)
- **Gateway Setup:** [GATEWAY-SETUP.md](GATEWAY-SETUP.md)
- **Quick Reference:** [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- **LiteLLM Docs:** https://docs.litellm.ai/

---

## ✅ Integration Checklist

- [ ] LiteLLM Proxy läuft: `systemctl status litellm-proxy`
- [ ] Health Check OK: `curl http://localhost:4000/health`
- [ ] OpenClaw Setup complete: `openclaw setup`
- [ ] Model Provider konfiguriert: `openclaw configure`
- [ ] Model Status OK: `openclaw models status`
- [ ] Gateway läuft: `openclaw status`
- [ ] Test erfolgreich: `openclaw infer complete --model claude-sonnet-4-6 --prompt "test"`
- [ ] Agents nutzen Model: `openclaw agents list`
- [ ] Interactive TUI funktioniert: `openclaw tui`

**Wenn alle ✅ → Integration ist vollständig! 🎉**

---

## 🆘 Support

**Bei Problemen:**

1. **LiteLLM Issues:**
   ```bash
   journalctl -u litellm-proxy -n 50 --no-pager
   ```

2. **OpenClaw Issues:**
   ```bash
   openclaw logs --level error
   openclaw doctor --fix
   ```

3. **AWS Bedrock Issues:**
   ```bash
   aws bedrock list-foundation-models --region eu-central-1
   ```

---

**Version:** 1.0.0  
**Letzte Aktualisierung:** 2026-06-02
