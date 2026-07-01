# OpenClaw Multi-Agent System für Proxmox

Automatisiertes Deployment eines OpenClaw-basierten Multi-Agent-Systems auf Proxmox LXC mit 4 spezialisierten Agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success)](docs/DEPLOYMENT-SUCCESS.md)
[![Model](https://img.shields.io/badge/Model-Claude%20Sonnet%204.6-blue)](https://www.anthropic.com/claude)

## 🎯 Überblick

Dieses Projekt richtet einen vollautomatischen OpenClaw LXC-Container auf Proxmox ein mit:

- **4 spezialisierten Agents:**
  - **Dev-Agent:** Code-Entwicklung mit Claude Code
  - **Review-Agent:** PR-Prüfung und Code-Qualität
  - **Security-Agent:** Dependency & Config Scanning
  - **Ops-Agent:** System-Monitoring & Traefik-Management

- **Vollständige Infrastruktur:**
  - OpenClaw 2026.5.22+
  - Node.js 20 LTS, Docker, Ansible
  - LiteLLM Proxy (Port 4000) für Amazon Bedrock
  - **Claude Sonnet 4.6** via AWS Bedrock (eu-central-1)
  - GitHub CLI, Python, Security Tools

## ✅ Production Ready

**Status:** Vollständig deployed und getestet  
**Deployment:** 2026-06-02 - 2026-06-03  
**Container:** 192.168.1.11 (openclaw-agents)

**Erfolgreiche Tests:**
- ✅ Dev-Agent: TypeScript Password-Checker mit 18 Tests
- ✅ Review-Agent: Professional-Grade Code-Review
- ✅ Gateway: Token-Auth aktiv und funktional
- ✅ Model: Claude Sonnet 4.6 via Bedrock

📖 **[Deployment Success Report](docs/DEPLOYMENT-SUCCESS.md)** | 🔧 **[Troubleshooting](docs/TROUBLESHOOTING.md)** | 🧪 **[Agent Testing](docs/AGENT-TESTING.md)**

## 📋 Voraussetzungen

### Proxmox Host
- Proxmox VE 7.0+
- SSH-Zugriff mit Root-Rechten
- 40 GB freier Storage
- Ubuntu 24.04 LTS Template (wird automatisch geladen)

### API-Keys
- Amazon Bedrock API-Zugriff (oder Claude API Key)
- Optional: GitHub Token für Review-Agent

### Lokale Maschine
- SSH-Client
- SSH-Key mit Passwort-Fallback (empfohlen) - siehe [Fallback-Dokumentation](FALLBACK-AUTH.md)
- Bash (Linux/macOS/WSL)
- `sshpass` für Fallback-Authentifizierung: `sudo apt install sshpass`

## 🚀 Quick Start

### 1. Repository klonen

```bash
git clone <your-repo-url>
cd openclaw
```

### 2. Konfiguration

```bash
cd proxmox/config
cp .env.example .env
nano .env
```

**Mindestens erforderlich:**
```bash
PROXMOX_HOST=192.168.1.10          # Deine Proxmox IP
PROXMOX_AUTH_METHOD=auto           # "auto", "key" oder "password"
PROXMOX_PASSWORD=DeinRootPasswort  # Als Fallback (empfohlen)
AWS_ACCESS_KEY_ID=AKIA...          # Bedrock Access Key
AWS_SECRET_ACCESS_KEY=...          # Bedrock Secret Key
AWS_REGION_NAME=us-east-1          # AWS Region
```

### 3. SSH-Zugriff einrichten

**Option A: Auto-Modus mit Fallback (empfohlen)**
```bash
# SSH-Key einrichten (Primär)
ssh-keygen -t ed25519
ssh-copy-id root@<PROXMOX_HOST>

# sshpass installieren (Fallback)
sudo apt install sshpass

# In .env:
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinRootPasswort  # Wird nur als Fallback verwendet
```

**Option B: Nur SSH-Key**
```bash
ssh-keygen -t ed25519
ssh-copy-id root@<PROXMOX_HOST>

# In .env:
PROXMOX_AUTH_METHOD=key
```

**Option C: Nur Passwort**
```bash
sudo apt install sshpass

# In .env:
PROXMOX_AUTH_METHOD=password
PROXMOX_PASSWORD=DeinRootPasswort
```

Siehe [docs/SSH-AUTH.md](docs/SSH-AUTH.md) für Details.

### 4. Deployment starten

```bash
cd proxmox
bash validate.sh    # Optional: Voraussetzungen prüfen
bash deploy.sh
```

**Dauer:** ~10-15 Minuten

## 📊 Was wird installiert?

Der LXC-Container (ID 111) erhält:

| Komponente | Version | Beschreibung |
|------------|---------|--------------|
| **OpenClaw** | 2026.5.22+ | Multi-Agent Framework |
| **Node.js** | 20 LTS | Runtime für OpenClaw |
| **Docker** | Latest | Container-Runtime |
| **LiteLLM** | Latest | Proxy für Bedrock API |
| **Ansible** | 2.16+ | Automation für Ops-Agent |
| **GitHub CLI** | 2.92+ | PR-Management |
| **Python** | 3.12+ | Scripts & Tools |
| **Security Tools** | - | Trivy, Lynis, Snyk |

**Ressourcen:**
- CPU: 4 Cores
- RAM: 8 GB
- Disk: 40 GB
- OS: Ubuntu 24.04 LTS

## 🔧 Nach dem Deployment

### Container-Zugriff

```bash
# Direkter SSH-Zugriff (nach Key-Setup)
ssh root@192.168.1.11

# Via Proxmox
ssh root@<PROXMOX_HOST>
pct enter 111
```

### LiteLLM für Bedrock konfigurieren

```bash
ssh root@192.168.1.11

# AWS Credentials
cp /opt/openclaw/config/litellm.env.example /opt/openclaw/config/litellm.env
nano /opt/openclaw/config/litellm.env

# Service starten
systemctl enable --now litellm-proxy
systemctl status litellm-proxy
```

### OpenClaw Onboarding

```bash
# Environment setzen
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="bedrock"

# Onboarding
openclaw onboard
```

## 📁 Projektstruktur

```
openclaw/
├── README.md                   # Diese Datei
├── DEPLOYMENT-GUIDE.md         # Ausführliche Anleitung
├── START-HERE.md               # Schnelleinstieg
├── .gitignore                  # Git-Ignore-Regeln
│
├── proxmox/                    # Proxmox LXC Deployment
│   ├── deploy.sh              # Hauptscript
│   ├── setup-openclaw.sh      # Container-Setup
│   ├── validate.sh            # Pre-Flight Checks
│   └── config/
│       ├── .env.example       # Konfiguration Template
│       └── .env               # Deine Config (nicht in Git!)
│
├── agents/                     # Agent-Definitionen (Phase 2)
│   ├── dev-agent/
│   ├── review-agent/
│   ├── security-agent/
│   └── ops-agent/
│
├── skills/                     # Custom Skills (Phase 3)
│   ├── traefik-manager/
│   └── cert-manager/
│
└── docs/                       # Zusätzliche Dokumentation
    ├── QUICKSTART.md
    ├── SETUP.md
    └── BEDROCK-SETUP.md
```

## 🐛 Troubleshooting

### SSH-Verbindung schlägt fehl

```bash
# Option 1: SSH-Key einrichten (empfohlen)
ssh-keygen -t ed25519
ssh-copy-id root@<PROXMOX_HOST>

# Option 2: Passwort-Authentifizierung
sudo apt install sshpass
# Setze PROXMOX_AUTH_METHOD=password in .env
```

Siehe [docs/SSH-AUTH.md](docs/SSH-AUTH.md) für Details.

### Template nicht gefunden

Das Script lädt das Ubuntu 24.04 Template automatisch. Falls Fehler:

```bash
# Manuell auf Proxmox
pveam update
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

### Deployment schlägt fehl

```bash
# Logs prüfen
cd proxmox
bash validate.sh  # Zeigt Probleme

# Container-Logs (auf Proxmox)
pct status 111
journalctl -xe
```

## 📚 Dokumentation

- **[START-HERE.md](START-HERE.md)** - Schnelleinstieg (3 Minuten)
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Vollständige Anleitung
- **[FALLBACK-AUTH.md](FALLBACK-AUTH.md)** - SSH Auto-Modus mit Fallback (NEU)
- **[docs/SSH-AUTH.md](docs/SSH-AUTH.md)** - SSH-Authentifizierung (Key vs. Passwort)
- **[docs/SETUP.md](docs/SETUP.md)** - Detaillierte Installation
- **[docs/BEDROCK-SETUP.md](docs/BEDROCK-SETUP.md)** - Bedrock/LiteLLM Details
- **[agents/README.md](agents/README.md)** - Agent-Konfiguration

## 🗺️ Roadmap

### ✅ Phase 1: Infrastruktur (Fertig)
- [x] Proxmox LXC Deployment
- [x] OpenClaw Installation
- [x] Docker, Ansible, Tools
- [x] LiteLLM Proxy für Bedrock

### ✅ Phase 2: Agents (Fertig)
- [x] Dev-Agent Definition & Prompts (.claude.md)
- [x] Review-Agent Definition (.claude.md)
- [x] Security-Agent Definition (.claude.md)
- [x] Ops-Agent Definition (.claude.md)
- [x] Agent-Testing (Password-Checker ✅, Code-Review ✅)

### ✅ Phase 3: Skills (Abgeschlossen)
- [x] **Traefik Service Manager Skill** - Automatisches Service Management mit Zertifikatserstellung
  - Externe Services mit Let's Encrypt
  - Interne Services mit step-ca Zertifikaten
  - Automatische Config-Generierung und Deployment
- [x] **Cert-Manager Skill** - **MIGRIERT ZU EIGENSTÄNDIGEM PROJEKT**
  - **Neues Projekt:** [CertFlow v2.0.0](https://github.com/seemedFilm/certflow)
  - Web-Dashboard + REST API
  - Dual Sources: step-ca + Let's Encrypt
  - Auto-Renewal & Audit-Logging
  - Pi-hole DNS Integration (v6 kompatibel)

### ⏳ Phase 4: Integration (Geplant)
- [ ] Traefik Docker-Integration
- [ ] Monitoring Dashboard
- [ ] Alerting

## 🤝 Mitwirken

Beiträge sind willkommen! Bitte:

1. Fork das Repository
2. Erstelle einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Commit deine Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Push zum Branch (`git push origin feature/AmazingFeature`)
5. Öffne einen Pull Request

## 📝 Lizenz

MIT License - siehe [LICENSE](LICENSE) Datei

## 🔗 Links

- [OpenClaw Dokumentation](https://docs.openclaw.ai/)
- [Proxmox VE Docs](https://pve.proxmox.com/pve-docs/)
- [LiteLLM Docs](https://docs.litellm.ai/)
- [Amazon Bedrock](https://aws.amazon.com/bedrock/)

## ⚠️ Sicherheitshinweise

- **Niemals** Credentials in Git committen
- `.env` ist in `.gitignore` - halte sie privat
- Nutze SSH-Keys statt Passwörter
- Rotiere AWS Keys regelmäßig (alle 90 Tage)
- Review PRs vor dem Merge (nutze Review-Agent!)

## 🆘 Support

Bei Problemen:

1. Prüfe [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) Troubleshooting
2. Prüfe [Issues](../../issues) für bekannte Probleme
3. Erstelle ein neues Issue mit Details

---

**Viel Erfolg mit deinem OpenClaw Multi-Agent System! 🚀**
