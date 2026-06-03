# OpenClaw Gateway Setup

Vollständige Anleitung zur Konfiguration des OpenClaw Gateway für die Multi-Agent-Umgebung.

## 📋 Übersicht

Das **OpenClaw Gateway** ist der zentrale Service, der:
- Alle Agents verwaltet und orchestriert
- Model-Provider (LiteLLM/Bedrock) anbindet
- Messaging-Channels koordiniert
- API-Zugriff bereitstellt

**Nach dem Deployment** müssen Gateway und Model-Provider konfiguriert werden.

---

## 🚀 Quick Start

### 1. SSH auf Container

```bash
ssh root@192.168.1.11
```

### 2. Gateway Setup

```bash
# Initiales Setup starten
openclaw setup
```

**Das Setup erstellt:**
- `~/.openclaw/openclaw.json` - Haupt-Konfigurationsdatei
- `~/.openclaw/workspace/` - Default-Workspace
- `~/.openclaw/agents/` - Agent-State-Verzeichnisse

### 3. Model-Provider konfigurieren

```bash
# Configuration Wizard starten
openclaw configure
```

**Im Menü:**
1. Wähle **"Models"**
2. Wähle **"Add custom provider"** (da LiteLLM bereits läuft)
3. Eingaben:
   - **Provider Name:** `litellm-bedrock`
   - **Base URL:** `http://localhost:4000`
   - **API Key:** `bedrock`
   - **Default Model:** `claude-sonnet-4-6`

### 4. Gateway starten

```bash
# Gateway im Hintergrund starten
openclaw gateway run &

# Warte 5 Sekunden
sleep 5

# Status prüfen
openclaw status
```

**Expected Output:**
```
Gateway: running
  Port: 18789
  Health: ✓
Models: litellm-bedrock
  Model: claude-sonnet-4-6 ✓
Agents: 5 (main, dev-agent, review-agent, security-agent, ops-agent)
```

---

## 📖 Detaillierte Konfiguration

### Schritt 1: Setup (Erst-Konfiguration)

```bash
openclaw setup
```

**Fragen beim Setup:**

#### 1.1 Gateway Mode

```
? Gateway mode: (Use arrow keys)
❯ local   - Run Gateway on this machine
  remote  - Connect to remote Gateway
  hosted  - Use OpenClaw Cloud (requires account)
```

**Wähle:** `local`

#### 1.2 Workspace Location

```
? Workspace directory: (default: ~/.openclaw/workspace)
```

**Empfehlung:** Standard-Wert verwenden (Enter drücken)

#### 1.3 Model Provider

```
? Primary model provider:
  anthropic     - Claude via Anthropic API
  openai        - GPT models via OpenAI API
  bedrock       - AWS Bedrock (multiple models)
❯ custom        - Custom provider (LiteLLM, Ollama, etc.)
```

**Wähle:** `custom` (weil LiteLLM bereits läuft)

#### 1.4 Custom Provider Details

```
? Provider base URL: http://localhost:4000
? API Key: bedrock
? Default model: claude-sonnet-4-6
```

**Setup Complete!**
```
✓ Configuration saved: ~/.openclaw/openclaw.json
✓ Workspace created: ~/.openclaw/workspace
✓ Gateway ready to start
```

---

### Schritt 2: Model Provider verifizieren

```bash
# Model-Status prüfen
openclaw models status
```

**Expected Output:**
```
Model Providers:
  litellm-bedrock:
    URL: http://localhost:4000
    Status: ✓ Connected
    Models:
      - claude-sonnet-4-6 (default)

Health: All providers operational
```

**Falls Fehler:**

```bash
# LiteLLM-Proxy prüfen
systemctl status litellm-proxy

# LiteLLM-Health-Check
curl http://localhost:4000/health

# Expected: {"healthy":true}
```

---

### Schritt 3: Gateway starten

#### Option A: Vordergrund (für Debugging)

```bash
openclaw gateway run
```

**Output:**
```
2026-06-02T10:30:00.000Z [gateway] loading configuration…
2026-06-02T10:30:00.050Z [gateway] starting HTTP server on port 18789
2026-06-02T10:30:00.100Z [gateway] gateway ready
2026-06-02T10:30:00.150Z [gateway] health check OK
```

**Stoppen:** `Ctrl+C`

#### Option B: Hintergrund (für Production)

```bash
# Gateway starten
openclaw gateway run &

# Process ID speichern
echo $! > /tmp/openclaw-gateway.pid

# Später stoppen
kill $(cat /tmp/openclaw-gateway.pid)
```

#### Option C: Systemd Service (Empfohlen für Production)

```bash
# Service-Datei erstellen
cat > /etc/systemd/system/openclaw-gateway.service <<'EOF'
[Unit]
Description=OpenClaw Gateway
After=network.target litellm-proxy.service
Wants=litellm-proxy.service

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/openclaw gateway run
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren und starten
systemctl daemon-reload
systemctl enable --now openclaw-gateway

# Status prüfen
systemctl status openclaw-gateway
```

---

### Schritt 4: Agents verifizieren

```bash
# Alle Agents anzeigen
openclaw agents list
```

**Expected Output:**
```
Agents:
- main (default)
  Model: claude-sonnet-4-6
  Workspace: ~/.openclaw/workspace
  
- dev-agent
  Model: claude-sonnet-4-6
  Workspace: /opt/openclaw/workspaces/dev-agent
  
- review-agent
  Model: claude-sonnet-4-6
  Workspace: /opt/openclaw/workspaces/review-agent
  
- security-agent
  Model: claude-sonnet-4-6
  Workspace: /opt/openclaw/workspaces/security-agent
  
- ops-agent
  Model: claude-sonnet-4-6
  Workspace: /opt/openclaw/workspaces/ops-agent
```

---

## 🧪 Gateway Testing

### Test 1: Gateway Health

```bash
openclaw health
```

**Expected:**
```json
{
  "status": "healthy",
  "gateway": {
    "version": "2026.5.22",
    "uptime": 120,
    "port": 18789
  },
  "models": {
    "litellm-bedrock": {
      "status": "connected",
      "latency": 45
    }
  },
  "agents": {
    "total": 5,
    "active": 0
  }
}
```

### Test 2: Agent Interaction

```bash
# Terminal UI starten
openclaw tui
```

**Im TUI:**
1. Wähle `dev-agent` aus der Agent-Liste
2. Tippe: "Hello, can you introduce yourself?"
3. Erwarte Antwort vom dev-agent

**Oder via CLI:**

```bash
# Einzelner Agent-Request
openclaw agent \
  --to dev-agent \
  --message "Hello, introduce yourself" \
  --deliver
```

**Expected Response:**
```
Hello! I'm the Development Agent (dev-agent), a senior software engineer 
specialized in code development, debugging, and refactoring. I work with 
Claude Sonnet 4.6 via AWS Bedrock and can help you with:

- Feature implementation
- Bug fixing and debugging
- Code refactoring
- Git operations
- Test-driven development

How can I help you today?
```

### Test 3: Model Provider Test

```bash
# Direkter Model-Test
openclaw infer complete \
  --model claude-sonnet-4-6 \
  --prompt "Say OK" \
  --max-tokens 5
```

**Expected:**
```
OK
```

---

## ⚙️ Erweiterte Konfiguration

### Config-Datei direkt bearbeiten

```bash
# Öffne Config
nano ~/.openclaw/openclaw.json
```

**Struktur:**

```json
{
  "gateway": {
    "mode": "local",
    "port": 18789,
    "host": "0.0.0.0"
  },
  "models": {
    "providers": {
      "litellm-bedrock": {
        "type": "openai-compatible",
        "baseUrl": "http://localhost:4000",
        "apiKey": "bedrock",
        "models": {
          "claude-sonnet-4-6": {
            "id": "claude-sonnet-4-6",
            "maxTokens": 4096,
            "default": true
          }
        }
      }
    },
    "defaultProvider": "litellm-bedrock",
    "defaultModel": "claude-sonnet-4-6"
  },
  "agents": {
    "main": {
      "workspace": "/root/.openclaw/workspace",
      "agentDir": "/root/.openclaw/agents/main/agent"
    },
    "dev-agent": {
      "workspace": "/opt/openclaw/workspaces/dev-agent",
      "agentDir": "/root/.openclaw/agents/dev-agent/agent",
      "model": "claude-sonnet-4-6"
    },
    "review-agent": {
      "workspace": "/opt/openclaw/workspaces/review-agent",
      "agentDir": "/root/.openclaw/agents/review-agent/agent",
      "model": "claude-sonnet-4-6"
    },
    "security-agent": {
      "workspace": "/opt/openclaw/workspaces/security-agent",
      "agentDir": "/root/.openclaw/agents/security-agent/agent",
      "model": "claude-sonnet-4-6"
    },
    "ops-agent": {
      "workspace": "/opt/openclaw/workspaces/ops-agent",
      "agentDir": "/root/.openclaw/agents/ops-agent/agent",
      "model": "claude-sonnet-4-6"
    }
  },
  "workspace": "/root/.openclaw/workspace"
}
```

**Nach Änderungen:**

```bash
# Config validieren
openclaw config validate

# Gateway neu starten
systemctl restart openclaw-gateway  # oder: kill + start
```

---

## 🔧 Gateway-Management

### Status & Monitoring

```bash
# Gateway-Status
openclaw status

# Detaillierter Health-Check
openclaw health --verbose

# Logs ansehen
openclaw logs

# Logs folgen
openclaw logs --follow

# Nur Fehler
openclaw logs --level error
```

### Gateway neu starten

```bash
# Systemd
systemctl restart openclaw-gateway

# Manuell
pkill -f "openclaw gateway"
openclaw gateway run &
```

### Gateway stoppen

```bash
# Systemd
systemctl stop openclaw-gateway

# Manuell
pkill -f "openclaw gateway"
```

---

## 🐛 Troubleshooting

### Problem: Gateway startet nicht

**Symptom:**
```bash
openclaw gateway run
# Error: Address already in use (port 18789)
```

**Lösung:**

```bash
# 1. Check ob Gateway bereits läuft
ps aux | grep "openclaw gateway"

# 2. Alten Process killen
pkill -f "openclaw gateway"

# 3. Port prüfen
lsof -i :18789

# 4. Gateway mit Force-Flag starten
openclaw gateway run --force
```

### Problem: Model Provider nicht erreichbar

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
curl http://localhost:4000/health

# 3. Logs prüfen
journalctl -u litellm-proxy -n 50 --no-pager
```

**Lösung:**

```bash
# LiteLLM neu starten
systemctl restart litellm-proxy

# Warten bis ready
sleep 5

# Gateway neu starten
systemctl restart openclaw-gateway
```

### Problem: Agent antwortet nicht

**Symptom:**
```bash
openclaw agent --to dev-agent --message "test"
# Timeout after 30s
```

**Diagnose:**

```bash
# 1. Gateway läuft?
openclaw status

# 2. Model Provider erreichbar?
openclaw models status

# 3. Agent existiert?
openclaw agents list | grep dev-agent

# 4. Logs prüfen
openclaw logs --level error
```

**Lösung:**

```bash
# 1. Gateway neu starten
systemctl restart openclaw-gateway

# 2. Direkt testen
openclaw infer complete --model claude-sonnet-4-6 --prompt "test"

# 3. Falls Model-Problem: LiteLLM prüfen
systemctl status litellm-proxy
```

### Problem: Config ungültig

**Symptom:**
```bash
openclaw gateway run
# Error: Invalid configuration
```

**Lösung:**

```bash
# 1. Config validieren
openclaw config validate

# 2. Config anzeigen
openclaw config file

# 3. Backup wiederherstellen
cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json

# 4. Neu konfigurieren
openclaw configure
```

---

## 📊 Performance-Tuning

### Gateway-Performance

```bash
# In ~/.openclaw/openclaw.json
{
  "gateway": {
    "maxConnections": 100,
    "requestTimeout": 30000,
    "keepAliveTimeout": 5000
  }
}
```

### Model-Provider-Optimierung

```bash
# Parallel Requests aktivieren
{
  "models": {
    "providers": {
      "litellm-bedrock": {
        "maxConcurrency": 5,
        "timeout": 60000,
        "retries": 3
      }
    }
  }
}
```

---

## 🔐 Sicherheit

### Gateway Firewall

```bash
# Nur lokaler Zugriff (Standard)
{
  "gateway": {
    "host": "127.0.0.1",  # Nur localhost
    "port": 18789
  }
}

# Oder via UFW
ufw allow from 127.0.0.1 to any port 18789
ufw deny 18789
```

### Gateway Auth-Token

**Standard (seit OpenClaw 2026.5.22):**
Gateway-Auth ist standardmäßig aktiviert mit Token-basierter Authentifizierung. Der Token wird automatisch von `openclaw doctor --fix` generiert.

```bash
# Gateway mit Auth (automatisch nach openclaw doctor --fix)
{
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "automatisch-generierter-token"
    }
  }
}
```

**Für lokale Entwicklung (optional):**
Falls du Auth deaktivieren möchtest (nur bei localhost-Nutzung empfohlen):

```bash
# NICHT EMPFOHLEN - nur für reine lokale Dev-Umgebung
{
  "gateway": {
    "mode": "local",
    "auth": null  # oder Abschnitt weglassen
  }
}

# Dann Gateway neu starten
systemctl restart openclaw-gateway
```

**Hinweis:** `openclaw doctor --fix` aktiviert automatisch Token-Auth für bessere Sicherheit. Nutze diese Standardkonfiguration.

---

## 📚 Weiterführende Dokumentation

- **LiteLLM Setup:** [LITELLM-SETUP.md](LITELLM-SETUP.md)
- **Agent Deployment:** [AGENT-DEPLOYMENT.md](AGENT-DEPLOYMENT.md)
- **Quick Reference:** [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- **OpenClaw Docs:** https://docs.openclaw.ai/

---

## ✅ Checkliste: Gateway Setup

Nach dem Setup sollten alle Punkte ✅ sein:

- [ ] `openclaw setup` erfolgreich ausgeführt
- [ ] `~/.openclaw/openclaw.json` existiert
- [ ] Model Provider konfiguriert (LiteLLM)
- [ ] `openclaw models status` zeigt "connected"
- [ ] Gateway läuft: `openclaw status` zeigt "running"
- [ ] Alle 5 Agents sichtbar: `openclaw agents list`
- [ ] Agent-Test erfolgreich: `openclaw tui` funktioniert
- [ ] Health-Check OK: `openclaw health` zeigt "healthy"

**Wenn alle ✅ → Gateway ist produktionsbereit! 🎉**

---

**Version:** 1.0.0  
**Letzte Aktualisierung:** 2026-06-02
