# 🚀 OpenClaw Multi-Agent System - Deployment Guide

Vollständige Schritt-für-Schritt-Anleitung für das Deployment auf Proxmox LXC.

---

## 📋 Übersicht

Dieses Setup erstellt:
- **1x LXC-Container** auf Proxmox (4 CPU, 8GB RAM, 40GB Disk)
- **4x OpenClaw Agents** (Dev, Review, Security, Ops)
- **Custom Skills** für Traefik-Management und Zertifikate
- **Remote-Management** für Traefik auf separatem Server

---

## ⏱️ Zeitaufwand

- **Setup LXC + OpenClaw:** ~10 Minuten (automatisch)
- **Agent-Konfiguration:** ~30 Minuten (Phase 2)
- **Skills & Integration:** ~60 Minuten (Phase 3+4)

**Gesamt:** ~1.5 Stunden für vollständiges Setup

---

## 🎯 Phase 1: LXC Container Setup (JETZT)

### Schritt 1: Repository vorbereiten

```bash
cd /c/Users/Patrick/Downloads/openclaw
```

Struktur prüfen:
```
openclaw/
├── proxmox/
│   ├── deploy.sh              ✓ Deployment-Script
│   ├── setup-openclaw.sh      ✓ OpenClaw-Installation
│   ├── validate.sh            ✓ Validierung
│   └── config/
│       ├── .env.example       ✓ Config-Template
│       └── .env               ✓ Deine Config (anpassen!)
├── agents/                    ⏳ Phase 2
├── skills/                    ⏳ Phase 3
└── docs/                      ✓ Dokumentation
```

### Schritt 2: Proxmox-Zugriff konfigurieren

```bash
# Proxmox IP setzen
export PROXMOX_HOST="192.168.1.10"  # ⚠️ ANPASSEN!

# Optional: Weitere Settings
# export LXC_ID=200
# export LXC_HOSTNAME="openclaw-agents"
# export LXC_NETWORK_IP="dhcp"  # oder "192.168.1.100/24"
```

**Oder** mit .env-Datei:

```bash
cd proxmox/config
cp .env.example .env
nano .env  # PROXMOX_HOST eintragen
source .env
```

### Schritt 3: Validierung durchführen

```bash
cd proxmox
bash validate.sh
```

**Erwartete Ausgabe:**
```
✓ Bash Version 5.2.26
✓ SSH Client verfügbar
✓ PROXMOX_HOST gesetzt: 192.168.1.10
✓ Proxmox Host 192.168.1.10 erreichbar
✓ SSH-Authentifizierung erfolgreich
✓ Proxmox Version: pve-manager/8.1.4
✓ Genügend Speicher verfügbar: 500 GB (benötigt: 40 GB)
✓ deploy.sh vorhanden und ausführbar

✓ Alle Checks erfolgreich! Bereit für Deployment.
```

**Falls Fehler:**
- SSH-Key nicht konfiguriert → `ssh-copy-id root@192.168.1.10`
- Host nicht erreichbar → IP/Firewall prüfen
- Script nicht ausführbar → `chmod +x proxmox/*.sh`

### Schritt 4: Deployment starten

```bash
bash deploy.sh
```

**Was passiert (automatisch):**
1. ✓ Ubuntu 24.04 Template Check/Download (~2 Min falls nicht vorhanden)
2. ✓ LXC-Container erstellen (ID 200 oder nächste freie)
3. ✓ Container starten und initialisieren
4. ✓ Setup-Script in Container kopieren
5. ✓ System-Updates (apt update/upgrade)
6. ✓ Node.js 20 LTS installieren
7. ✓ OpenClaw via npm installieren
8. ✓ Docker installieren
9. ✓ Ansible, GitHub CLI, Python installieren
10. ✓ Security Tools (Trivy, Lynis, Snyk)
11. ✓ Monitoring (Prometheus Node Exporter)
12. ✓ Verzeichnisstruktur erstellen
13. ✓ Systemd Services vorbereiten

**Dauer:** ~8-10 Minuten

**Erwartete Ausgabe:**
```
==================================================================================
OpenClaw LXC Container erfolgreich erstellt!
==================================================================================

Container Details:
  ID:       200
  Hostname: openclaw-agents
  IP:       192.168.1.50
  CPU:      4 Cores
  RAM:      8192 MB
  Disk:     40 GB

SSH Zugriff:
  ssh root@192.168.1.50

Nächste Schritte:
  1. SSH in Container: ssh root@192.168.1.50
  2. OpenClaw testen: openclaw --version
  3. OpenClaw onboarding: openclaw onboard
  4. Agents konfigurieren (siehe ../agents/)
```

### Schritt 5: Container-Info speichern

```bash
cat proxmox/container-info.txt
```

Ausgabe:
```
CONTAINER_ID=200
CONTAINER_HOSTNAME=openclaw-agents
CONTAINER_IP=192.168.1.50
CREATED=2026-05-23T10:45:00+02:00
```

**⚠️ Speichere diese IP-Adresse für alle weiteren Schritte!**

### Schritt 6: In Container einloggen

```bash
ssh root@192.168.1.50  # IP aus container-info.txt
```

### Schritt 7: OpenClaw initialisieren

```bash
# Im Container
openclaw --version
# Erwartete Ausgabe: openclaw 1.x.x

openclaw onboard
```

**Onboarding-Dialog:**
```
? Select a chat platform:
  › Discord
    Telegram
    Slack
    WhatsApp
    None (API only)

? Enter your Claude API key:
  › sk-ant-... (von https://console.anthropic.com/)

? Enable GitHub integration? Yes
? Enter GitHub token:
  › ghp_... (von https://github.com/settings/tokens)

✓ OpenClaw configured successfully!
```

**API-Keys dauerhaft setzen:**

```bash
# Im Container
cat >> ~/.bashrc << 'EOF'

# OpenClaw API Keys
export ANTHROPIC_API_KEY="sk-ant-..."
export GITHUB_TOKEN="ghp_..."
EOF

source ~/.bashrc
```

### Schritt 8: Smoke Test

```bash
# Im Container
openclaw chat "Hello, teste die Claude-Verbindung"
```

**Erwartete Ausgabe:**
```
Hello! Die Verbindung funktioniert einwandfrei. OpenClaw ist bereit.
```

**✅ Phase 1 abgeschlossen!**

---

## 🎯 Phase 2: Agent-Konfiguration (NÄCHSTER SCHRITT)

Sobald Phase 1 erfolgreich ist, konfigurierst du die 4 Agents:

### Agent-Übersicht

| Agent | Zweck | Hauptaufgaben |
|-------|-------|---------------|
| **Dev-Agent** | Code-Entwicklung | Code-Gen, Git, Refactoring |
| **Review-Agent** | PR-Prüfung | Code-Review, Changelog, Tests |
| **Security-Agent** | Security-Scans | Dependency-Audit, Container-Scan |
| **Ops-Agent** | Monitoring & Traefik | Traefik-Mgmt, Certs, Monitoring |

### Nächste Schritte

```bash
# Auf lokaler Maschine
cd agents

# Folge der Anleitung:
cat README.md
```

Hauptaufgaben in Phase 2:
1. Agent-Definitionen erstellen (`config.yaml` für jeden Agent)
2. System-Prompts definieren (`prompts.md`)
3. Agents in OpenClaw registrieren
4. Systemd Services aktivieren
5. Inter-Agent-Kommunikation testen

**Zeitaufwand:** ~30 Minuten

---

## 🎯 Phase 3: Custom Skills (SPÄTER)

Nach Agent-Setup werden Custom Skills implementiert:

### Traefik-Manager Skill
- Remote SSH-Verbindung zu Traefik-Server
- Config-Management
- Service Reload

### Cert-Manager Skill
- Let's Encrypt ACME-Integration
- Zertifikats-Erneuerung
- Validierung

**Zeitaufwand:** ~45 Minuten

---

## 🎯 Phase 4: Traefik-Integration (SPÄTER)

### Voraussetzungen
- Separater Server mit Traefik
- SSH-Zugriff von OpenClaw-Container zum Traefik-Server
- Bestehende Traefik-Konfiguration

### Setup
1. SSH-Key auf Traefik-Server hinterlegen
2. Ops-Agent Traefik-Config beibringen
3. Cert-Manager mit ACME verbinden
4. Monitoring aufsetzen

**Zeitaufwand:** ~30 Minuten

---

## 📊 Status-Tracking

### ✅ Abgeschlossen
- [x] Repository-Struktur
- [x] Deployment-Scripts (deploy.sh, setup-openclaw.sh)
- [x] Validierungs-Script
- [x] Dokumentation (SETUP.md, QUICKSTART.md)
- [x] .env Konfiguration

### ⏳ In Arbeit (Phase 1)
- [ ] LXC-Container erstellen
- [ ] OpenClaw installieren
- [ ] Container testen

### 📅 Geplant
- [ ] Phase 2: Agents
- [ ] Phase 3: Skills
- [ ] Phase 4: Traefik

---

## 🆘 Troubleshooting

### Problem 1: SSH-Verbindung zu Proxmox schlägt fehl

**Symptom:**
```
Permission denied (publickey).
```

**Lösung:**
```bash
ssh-keygen -t ed25519 -C "openclaw-proxmox"
ssh-copy-id root@192.168.1.10
ssh root@192.168.1.10 "echo 'Test OK'"
```

### Problem 2: Template-Download schlägt fehl

**Symptom:**
```
ERROR: unable to download template
```

**Lösung:**
```bash
# Auf Proxmox Host
pveam update
pveam available | grep ubuntu-24.04
pveam download local ubuntu-24.04-standard_24.04-1_amd64.tar.zst
```

### Problem 3: Container startet nicht

**Symptom:**
```
pct status 200: Container not running
```

**Lösung:**
```bash
# Auf Proxmox Host
pct start 200
pct enter 200  # Console-Zugriff
journalctl -xe  # Logs prüfen
```

### Problem 4: OpenClaw Onboarding schlägt fehl

**Symptom:**
```
Error: Invalid API key
```

**Lösung:**
- Prüfe API-Key: https://console.anthropic.com/
- Teste Key: `curl -H "x-api-key: $ANTHROPIC_API_KEY" https://api.anthropic.com/v1/messages`
- Firewall-Regeln prüfen (ausgehend Port 443)

---

## 📚 Weiterführende Dokumentation

- **Quick Start:** [docs/QUICKSTART.md](docs/QUICKSTART.md)
- **Ausführliches Setup:** [docs/SETUP.md](docs/SETUP.md)
- **Agent-Config:** [agents/README.md](agents/README.md)
- **Skills:** [skills/README.md](skills/README.md)
- **OpenClaw Docs:** https://docs.openclaw.ai/

---

## ✅ Checkliste vor Deployment

- [ ] Proxmox erreichbar (Ping erfolgreich)
- [ ] SSH-Key-Auth konfiguriert (`ssh-copy-id`)
- [ ] `PROXMOX_HOST` Variable gesetzt
- [ ] Genügend Speicher verfügbar (40 GB+)
- [ ] Scripts ausführbar (`chmod +x proxmox/*.sh`)
- [ ] Claude API-Key bereit (https://console.anthropic.com/)
- [ ] GitHub Token bereit (für Review-Agent)

---

## 🎉 Nach erfolgreichem Deployment

**Du hast jetzt:**
- ✅ Voll funktionsfähigen OpenClaw LXC-Container
- ✅ Node.js 20, Docker, Ansible, Tools installiert
- ✅ OpenClaw konfiguriert und getestet
- ✅ Basis für 4-Agent-System

**Nächster Schritt:**
```bash
cd agents
cat README.md  # Phase 2 starten
```

---

**Viel Erfolg! 🚀**
