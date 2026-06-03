# OpenClaw Multi-Agent System

Diese Verzeichnis enthält die Konfigurationen für die 4 spezialisierten OpenClaw-Agents.

## 🤖 Agent-Übersicht

### 1. Dev-Agent (`dev-agent/`)
**Aufgabe:** Code-Entwicklung mit Claude Code Integration

**Capabilities:**
- Code-Generierung und Refactoring
- Git-Operationen
- File-Management
- Claude Code Session-Management
- Syntax- und Logik-Checks

**Tools:**
- Claude Code CLI
- Git
- Programmiersprachen-spezifische Tools
- Linters & Formatters

---

### 2. Review-Agent (`review-agent/`)
**Aufgabe:** Pull Request Prüfung und Code-Qualität

**Capabilities:**
- PR-Analyse via GitHub API
- Code-Review nach Best Practices
- Changelog-Generierung
- Dependency-Updates prüfen
- Test-Coverage-Analyse

**Tools:**
- GitHub CLI (`gh`)
- Code-Quality Tools
- Diff-Analyse
- Testing Frameworks

---

### 3. Security-Agent (`security-agent/`)
**Aufgabe:** Security Scanning und Config-Audits

**Capabilities:**
- Dependency-Scanning (npm audit, Snyk)
- Container-Security (Trivy)
- Config-Audit (Lynis)
- Secrets-Detection
- Traefik Security-Config Check
- SSL/TLS Zertifikats-Validierung

**Tools:**
- Trivy (Container Scanning)
- Lynis (System Audit)
- npm audit / Snyk
- SSL Labs API
- Custom Security Rules

---

### 4. Ops-Agent (`ops-agent/`)
**Aufgabe:** System-Monitoring und Traefik-Management

**Capabilities:**
- Traefik Config-Management (Remote Server)
- SSL-Zertifikats-Erneuerung (Let's Encrypt)
- System-Monitoring (CPU, RAM, Disk)
- Log-Analyse
- Alerting
- Backup-Verification

**Tools:**
- Ansible (für Remote-Management)
- SSH (für Traefik-Server)
- Prometheus Node Exporter
- Docker (für Traefik-Container)
- Certbot / ACME Client

---

## 📁 Struktur

```
agents/
├── README.md              # Diese Datei
├── dev-agent/
│   ├── config.yaml        # Agent-Konfiguration
│   ├── prompts.md         # System-Prompts
│   ├── skills/            # Dev-spezifische Skills
│   └── README.md          # Detaillierte Dokumentation
├── review-agent/
│   ├── config.yaml
│   ├── prompts.md
│   ├── rules/             # Review-Regeln
│   └── README.md
├── security-agent/
│   ├── config.yaml
│   ├── prompts.md
│   ├── policies/          # Security-Policies
│   └── README.md
└── ops-agent/
    ├── config.yaml
    ├── prompts.md
    ├── playbooks/         # Ansible Playbooks
    └── README.md
```

## 🚀 Setup

### Voraussetzungen

Der OpenClaw LXC-Container muss bereits installiert sein (siehe `../proxmox/`).

### 1. Agent-Definitionen kopieren

```bash
# Von lokaler Maschine
cd agents

# Kopiere alle Agent-Configs in den Container
scp -r dev-agent review-agent security-agent ops-agent \
    root@<CONTAINER-IP>:/opt/openclaw/agents/
```

### 2. Im Container: Agents registrieren

```bash
# SSH in Container
ssh root@<CONTAINER-IP>

# Wechsle in OpenClaw-Verzeichnis
cd /opt/openclaw/agents

# Registriere Agents bei OpenClaw
openclaw agent register dev-agent --config dev-agent/config.yaml
openclaw agent register review-agent --config review-agent/config.yaml
openclaw agent register security-agent --config security-agent/config.yaml
openclaw agent register ops-agent --config ops-agent/config.yaml

# Prüfe registrierte Agents
openclaw agent list
```

### 3. Systemd Services aktivieren

```bash
# Dev-Agent
systemctl enable openclaw-agent@dev
systemctl start openclaw-agent@dev

# Review-Agent
systemctl enable openclaw-agent@review
systemctl start openclaw-agent@review

# Security-Agent
systemctl enable openclaw-agent@security
systemctl start openclaw-agent@security

# Ops-Agent
systemctl enable openclaw-agent@ops
systemctl start openclaw-agent@ops

# Status prüfen
systemctl status openclaw-agent@*
```

## 🔧 Konfiguration

### API-Keys setzen

Alle Agents benötigen Zugriff auf bestimmte APIs:

```bash
# Claude API (alle Agents)
export ANTHROPIC_API_KEY="sk-ant-..."

# GitHub (Review-Agent)
gh auth login

# Snyk (Security-Agent)
snyk auth

# Traefik Server SSH (Ops-Agent)
# Siehe ops-agent/README.md für SSH-Key-Setup
```

### Agent-spezifische Konfiguration

Jeder Agent hat eine `config.yaml`:

```yaml
# Beispiel: dev-agent/config.yaml
agent:
  name: "dev-agent"
  description: "Code Development Agent"
  model: "claude-sonnet-4-6"
  
skills:
  - name: "git-ops"
    enabled: true
  - name: "code-gen"
    enabled: true
    
memory:
  persistent: true
  scope: "project"
  
triggers:
  - event: "file_changed"
    action: "analyze"
  - event: "commit"
    action: "lint"
```

## 🔗 Inter-Agent-Kommunikation

Agents können untereinander kommunizieren via Shared Memory:

```javascript
// Dev-Agent schreibt
await claw.memory.set('last-commit', { 
    sha: 'abc123',
    files: ['src/app.js'],
    timestamp: Date.now()
});

// Review-Agent liest
const lastCommit = await claw.memory.get('last-commit');
// Führe Review durch...
```

### Kommunikations-Flow

```
┌──────────────┐
│  Dev-Agent   │────┐
└──────────────┘    │
                    ↓
              Shared Memory
                    ↓
┌──────────────┐    │    ┌────────────────┐
│Review-Agent  │←───┴───→│ Security-Agent │
└──────────────┘         └────────────────┘
       │                         │
       └────────┬────────────────┘
                ↓
         ┌─────────────┐
         │  Ops-Agent  │
         └─────────────┘
```

## 📊 Monitoring

### Agent-Status prüfen

```bash
# Alle Agents
systemctl status openclaw-agent@*

# Einzelner Agent
systemctl status openclaw-agent@dev
```

### Logs ansehen

```bash
# Realtime Logs
journalctl -u openclaw-agent@dev -f

# Letzte 100 Zeilen
journalctl -u openclaw-agent@dev -n 100

# Alle Agent-Logs
journalctl -u "openclaw-agent@*" -f
```

### Agent-Metriken

OpenClaw exportiert Metriken für Prometheus:

```bash
curl http://localhost:9100/metrics | grep openclaw
```

## 🧪 Testing

### Einzelnen Agent testen

```bash
# Dev-Agent
openclaw agent test dev-agent --prompt "Erstelle eine Hello-World-Funktion"

# Review-Agent mit PR
openclaw agent test review-agent --pr "https://github.com/user/repo/pull/123"

# Security-Agent mit Pfad
openclaw agent test security-agent --scan "/opt/app"

# Ops-Agent
openclaw agent test ops-agent --check "traefik-status"
```

### Agent-Interaktion testen

```bash
# Terminal 1: Dev-Agent
openclaw chat --agent dev-agent

# Terminal 2: Review-Agent
openclaw chat --agent review-agent

# Terminal 3: Shared Memory Monitor
watch -n 1 'openclaw memory list'
```

## 🎯 Nächste Schritte

1. ✅ LXC Container Setup (erledigt via `proxmox/deploy.sh`)
2. ⏳ **Agent-Definitionen erstellen** (nächster Schritt)
3. ⏳ Custom Skills implementieren
4. ⏳ Traefik-Integration konfigurieren
5. ⏳ Monitoring Dashboard aufsetzen

## 📚 Weitere Ressourcen

- **Dev-Agent:** [dev-agent/README.md](dev-agent/README.md)
- **Review-Agent:** [review-agent/README.md](review-agent/README.md)
- **Security-Agent:** [security-agent/README.md](security-agent/README.md)
- **Ops-Agent:** [ops-agent/README.md](ops-agent/README.md)
- **Skills:** [../skills/README.md](../skills/README.md)
- **OpenClaw Docs:** https://docs.openclaw.ai/

## 🆘 Troubleshooting

### Agent startet nicht

```bash
# Logs prüfen
journalctl -u openclaw-agent@dev -n 50

# Config validieren
openclaw agent validate dev-agent

# Neu starten
systemctl restart openclaw-agent@dev
```

### Agent reagiert nicht

```bash
# Process prüfen
ps aux | grep openclaw

# Memory prüfen
free -h

# Disk prüfen
df -h
```

### Inter-Agent-Kommunikation funktioniert nicht

```bash
# Shared Memory prüfen
openclaw memory list
openclaw memory get <key>

# Permissions prüfen
ls -la ~/.openclaw/memory/
```
