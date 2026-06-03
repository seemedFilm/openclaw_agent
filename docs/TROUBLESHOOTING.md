# 🔧 Troubleshooting Guide

Alle während des Deployments gelösten Probleme und ihre Lösungen.

---

## Problem 1: LiteLLM Port 8000 → 4000 Migration

### Symptom
```bash
openclaw configure
# Menu shows: "Default proxy runs on http://localhost:4000"
# But LiteLLM läuft auf Port 8000
```

### Ursache
- LiteLLM wurde initial auf Port 8000 konfiguriert
- OpenClaw erwartet standardmäßig Port 4000
- Manuelle Config-Anpassung wäre nötig gewesen

### Lösung

**1. Systemd Service anpassen:**
```bash
nano /etc/systemd/system/litellm-proxy.service

# Ändere ExecStart:
ExecStart=/opt/openclaw/venv/bin/litellm --config /opt/openclaw/config/litellm-config.yaml --port 4000
```

**2. Environment File anpassen:**
```bash
nano /opt/openclaw/config/litellm.env

# Ändere:
LITELLM_PORT=4000
```

**3. Service neu starten:**
```bash
systemctl daemon-reload
systemctl restart litellm-proxy
sleep 5
curl http://localhost:4000/health
# Expected: {"status":"healthy"}
```

**4. Dokumentation aktualisieren:**
- Alle Vorkommen von `8000` → `4000` in docs/*

### Ergebnis
✅ LiteLLM läuft auf Port 4000  
✅ OpenClaw verbindet ohne manuelle Config  
✅ Dokumentation konsistent

---

## Problem 2: Gateway Auth Token Missing

### Symptom
```bash
openclaw health
# Error: unauthorized: gateway token missing (provide gateway auth token)
```

### Ursache
- OpenClaw 2026.5.22 aktiviert standardmäßig Token-Auth
- Kein Token in Config gesetzt
- Gateway verweigert Verbindung

### Lösung

**Automatische Reparatur via Doctor:**
```bash
openclaw doctor --fix
```

**Was Doctor macht:**
1. Generiert Token automatisch
2. Updated Config: `gateway.auth.token = "[auto-generated]"`
3. Setzt Auth-Mode: `gateway.auth.mode = "token"`
4. Erstellt Backup der alten Config

**Nach Doctor:**
```bash
systemctl restart openclaw-gateway
openclaw health
# Expected: Keine Auth-Fehler mehr
```

### Alternative (Manuell - NICHT empfohlen)

**Auth deaktivieren (nur für pure lokale Dev):**
```bash
# WARNUNG: Sicherheitsrisiko!
jq '.gateway.auth = null' ~/.openclaw/openclaw.json > /tmp/oc.json
mv /tmp/oc.json ~/.openclaw/openclaw.json
systemctl restart openclaw-gateway
```

### Ergebnis
✅ Gateway läuft mit Token-Auth  
✅ CLI verbindet erfolgreich  
✅ Sicher auch bei localhost-Nutzung

---

## Problem 3: Model Claude Opus 4.6 → Sonnet 4.6

### Symptom
```bash
openclaw tui
# Output: [assistant turn failed before producing content]

# Logs:
journalctl -u openclaw-gateway | grep error
# Error: Invalid model name passed in model=claude-opus-4-6
```

### Ursache
- `openclaw configure` setzte `claude-opus-4-6` als Default
- LiteLLM bietet nur `claude-sonnet-4-6` an (Bedrock EU Region)
- Model-Name-Mismatch → 400 Error

### Lösung

**1. Default Model korrigieren:**
```bash
jq '.agents.defaults.model.primary = "litellm/claude-sonnet-4-6"' ~/.openclaw/openclaw.json > /tmp/oc.json
mv /tmp/oc.json ~/.openclaw/openclaw.json
```

**2. Model-Provider korrigieren:**
```bash
jq '.models.providers.litellm.models[0].id = "claude-sonnet-4-6"' ~/.openclaw/openclaw.json > /tmp/oc.json
mv /tmp/oc.json ~/.openclaw/openclaw.json
```

**3. Agent-Models korrigieren:**
```bash
for i in 1 2 3 4; do
  jq ".agents.list[$i].model = \"litellm/claude-sonnet-4-6\"" ~/.openclaw/openclaw.json > /tmp/oc.json
  mv /tmp/oc.json ~/.openclaw/openclaw.json
done
```

**4. Gateway neu starten:**
```bash
systemctl restart openclaw-gateway
openclaw agent --agent main --message "Test"
# Expected: Antwort vom Agent
```

### Ergebnis
✅ Alle Agents nutzen Sonnet 4.6  
✅ Model-Calls erfolgreich  
✅ Keine 400-Errors mehr

---

## Problem 4: Device Pairing - Scopes fehlen

### Symptom
```bash
openclaw tui
# Error: Pairing required. Run `openclaw devices list`, approve your request ID, then reconnect.

openclaw devices list
# Shows: Pending request, needs operator.admin + operator.pairing scopes
```

### Ursache
- Device hatte nur `operator.write` Scope
- TUI benötigt zusätzlich: `operator.admin`, `operator.pairing`, `operator.read`
- Jeder `openclaw`-Aufruf generiert neue Request-ID (Catch-22)

### Lösung

**1. Scopes direkt in paired.json erweitern:**
```bash
jq '.[].scopes += ["operator.admin", "operator.pairing", "operator.read"] | .[].approvedScopes += ["operator.admin", "operator.pairing", "operator.read"]' ~/.openclaw/devices/paired.json > /tmp/paired.json
mv /tmp/paired.json ~/.openclaw/devices/paired.json
```

**2. Pending Requests löschen:**
```bash
echo "[]" > ~/.openclaw/devices/pending.json
```

**3. Gateway neu starten:**
```bash
systemctl restart openclaw-gateway
```

**4. Verifizieren:**
```bash
openclaw devices list
# Expected: Paired device mit allen Scopes, keine Pending Requests

openclaw tui
# Expected: TUI startet ohne Pairing-Error
```

### Ergebnis
✅ Device hat alle benötigten Scopes  
✅ TUI funktioniert  
✅ Keine Pairing-Requests mehr

---

## Problem 5: Agent Bootstrap - Identität fehlt

### Symptom
```bash
openclaw agent --agent dev-agent --message "Wer bist du?"
# Response: "Hey — ich bin noch ein unbeschriebenes Blatt. Kein Name, kein Charakter..."
```

### Ursache
- Agents hatten keine Bootstrap-Instruktionen
- Keine `.claude.md` Files in Agent-Directories
- Agents starteten mit "frischer Slate"

### Lösung

**1. .claude.md Files erstellen:**

**Für dev-agent:**
```bash
cat > ~/.openclaw/agents/dev-agent/agent/.claude.md << 'EOF'
# System Instructions

You are the **Development Agent (dev-agent)**, a senior software engineer specialized in code development, debugging, and refactoring.

## Your Identity
- Name: Dev-Agent
- Role: Senior Software Engineer
- Model: Claude Sonnet 4.6 via AWS Bedrock

## Your Capabilities
1. Code Generation
2. Debugging
3. Refactoring
4. Git Operations
5. Testing
6. Documentation

## Communication Style
- Professional but approachable
- Code-first: show code before explaining
- Use German language

Do NOT ask for your name - you already know who you are.
EOF
```

**Für alle anderen Agents analog erstellen.**

**2. Gateway neu starten:**
```bash
systemctl restart openclaw-gateway
```

**3. Testen:**
```bash
openclaw agent --agent dev-agent --message "Wer bist du?"
# Expected: Agent stellt sich vor (nutzt .claude.md Instruktionen)
```

### Hinweis
Agents zeigen Bootstrap-Verhalten beim **ersten Kontakt**. Bei konkreten Aufgaben nutzen sie automatisch ihre .claude.md Instruktionen.

### Ergebnis
✅ Alle Agents haben Bootstrap-Files  
✅ System-Instruktionen vorhanden  
✅ Agents kennen ihre Rolle

---

## Problem 6: systemd Service - Binary Path falsch

### Symptom
```bash
systemctl status openclaw-gateway
# Status: failed
# Error: ExecStart=/usr/local/bin/openclaw not found (code=203/EXEC)
```

### Ursache
- Service-Datei hatte falschen Pfad `/usr/local/bin/openclaw`
- Tatsächlicher Pfad: `/bin/openclaw`

### Lösung

```bash
# Binary-Pfad finden
which openclaw
# Output: /bin/openclaw

# Service-Datei korrigieren
nano /etc/systemd/system/openclaw-gateway.service
# Ändere ExecStart=/bin/openclaw gateway run

# Reload + Restart
systemctl daemon-reload
systemctl restart openclaw-gateway
systemctl status openclaw-gateway
# Expected: active (running)
```

### Ergebnis
✅ Service startet erfolgreich  
✅ Korrekter Binary-Pfad

---

## Häufige Fehler & Quick Fixes

### Error: "Cannot connect to model provider"
```bash
# Check LiteLLM
systemctl status litellm-proxy
curl http://localhost:4000/health

# Fix
systemctl restart litellm-proxy
```

### Error: "Unknown model: openai/claude-sonnet-4-6"
```bash
# Check Model-Name in Config
cat ~/.openclaw/openclaw.json | jq '.agents.defaults.model'

# Fix: Sollte sein "litellm/claude-sonnet-4-6"
jq '.agents.defaults.model.primary = "litellm/claude-sonnet-4-6"' ~/.openclaw/openclaw.json > /tmp/oc.json
mv /tmp/oc.json ~/.openclaw/openclaw.json
systemctl restart openclaw-gateway
```

### Error: "Gateway not running"
```bash
# Check Status
systemctl status openclaw-gateway

# Check Logs
journalctl -u openclaw-gateway -n 50 --no-pager

# Fix
systemctl restart openclaw-gateway
```

### Error: "Config validation failed"
```bash
# Validate Config
openclaw config validate

# Backup wiederherstellen
cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json

# Oder Doctor reparieren lassen
openclaw doctor --fix
```

---

## Debug-Commands

**System-Status:**
```bash
# Gateway
systemctl status openclaw-gateway

# LiteLLM
systemctl status litellm-proxy

# Health
openclaw health

# Agents
openclaw agents list
```

**Logs:**
```bash
# Gateway Logs
journalctl -u openclaw-gateway -f

# LiteLLM Logs
journalctl -u litellm-proxy -f

# Nur Errors
journalctl -u openclaw-gateway --since "1 hour ago" | grep -i error
```

**Config:**
```bash
# Config anzeigen
cat ~/.openclaw/openclaw.json | jq '.'

# Config validieren
openclaw config validate

# Model-Config
cat ~/.openclaw/openclaw.json | jq '.models'
```

---

**Version:** 1.0.0  
**Last Update:** 2026-06-03
