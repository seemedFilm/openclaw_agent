# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

OpenClaw Multi-Agent System für Proxmox - Automatisiertes Certificate Management mit vollständiger DNS-Integration.

**Aktueller Status:** Production-Ready (v1.1.0)
- Container: 192.168.1.11 (openclaw-agents)
- **OpenClaw Agents sind NICHT deployed** - Dokumentation nur als Konzept
- **Skills sind die tatsächliche Implementierung**
- **WICHTIG:** cert-manager ist jetzt eigenständiges Projekt → [CertFlow](https://github.com/seemedFilm/certflow)

## Architecture

### Skills-basierte Automation (statt Agents)

Das System verwendet **Skills** (Bash/Python-Scripts), keine KI-Agents.

**WICHTIG:** Das cert-manager Skill wurde zu einem eigenständigen Produkt migriert:
- **Neues Projekt:** [CertFlow v2.0.0](https://github.com/seemedFilm/certflow)
- **Deployed als:** `/opt/certflow/` (parallel zu `/opt/openclaw/`)
- **Services:** `certflow-api`, `certflow-web`, `certflow-renewal`
- **Ports:** 5000 (Web), 5001 (API)

**Kritische Skills (jetzt in CertFlow):**
1. **certflow** (192.168.1.11:5000/5001) - **[Eigenständiges Projekt](https://github.com/seemedFilm/certflow)**
   - Web-UI (Flask) + REST API (FastAPI)
   - Python: `certflow/lib/certificate_manager.py`
   - Orchestriert Traefik + Pi-hole Integration

2. **traefik-service-manager** (192.168.1.23)
   - Bash-Script für Traefik Reverse Proxy Config
   - SSH-basiert zu Traefik-Server
   - Erstellt/löscht YAML-Configs in `/docker/volume/traefik/dynamic/`

3. **pihole-dns-manager** (192.168.1.7)
   - Bash-Script für Pi-hole DNS (v5/v6 kompatibel)
   - SSH-basiert, bearbeitet `/etc/pihole/custom.list`
   - **Kein API-Token** - nur SSH-Key-Auth

### Remote Server

**Kritische IPs (in config.yaml Files):**
- `192.168.1.3` - step-ca Certificate Authority (script: `/root/create-cert.sh`)
- `192.168.1.7` - Pi-hole DNS Server
- `192.168.1.11` - OpenClaw Container (cert-manager läuft hier)
- `192.168.1.23` - Traefik Reverse Proxy Server

### Datenfluss bei Zertifikatserstellung

```python
# In certificate_manager.py:
create_certificate()
  ↓ SSH
step-ca erstellt Zertifikat (192.168.1.3)
  ↓ subprocess.run
_create_traefik_service()  # Ruft traefik-service-manager.sh auf
  ↓ SSH
Traefik-Config erstellt (192.168.1.23)
  ↓ subprocess.run
_add_pihole_dns()  # Ruft pihole-dns-manager.sh auf
  ↓ SSH
DNS-Eintrag in Pi-hole (192.168.1.7)
```

## Common Commands

### Skills deployen

**HINWEIS:** cert-manager ist jetzt CertFlow - siehe [certflow Repository](https://github.com/seemedFilm/certflow)

```bash
# CertFlow deployen (neues eigenständiges Projekt)
cd /path/to/certflow
export CERTFLOW_HOST="192.168.1.11"
bash deploy.sh

# Pi-hole DNS Manager deployen
cd skills/pihole-dns-manager
bash deploy-skill.sh 192.168.1.11

# Traefik Service Manager deployen
cd skills/traefik-service-manager
bash deploy-skill.sh 192.168.1.11
```

### Services verwalten

```bash
# Status prüfen (auf 192.168.1.11)
ssh root@192.168.1.11 "systemctl status certflow-api certflow-web certflow-renewal"

# Logs ansehen
ssh root@192.168.1.11 "journalctl -u certflow-api -f"

# Services neustarten nach Code-Änderungen
ssh root@192.168.1.11 "systemctl restart certflow-api certflow-web"
```

### Testen

```bash
# End-to-End Test: Zertifikat erstellen
curl -X POST http://192.168.1.11:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "test.internal",
    "type": "step-ca",
    "create_traefik_config": true,
    "backend_ip": "https://192.168.1.50:8080"
  }'

# Erwartete Response: "pihole_dns_created": true

# Prüfe DNS-Eintrag
ssh root@192.168.1.11 "ssh root@192.168.1.7 'grep test.internal /etc/pihole/custom.list'"

# Prüfe Audit-Log
curl http://192.168.1.11:5001/api/audit-log | grep -A5 add_pihole_dns

# Zertifikat löschen (inkl. DNS-Cleanup)
curl -X DELETE http://192.168.1.11:5001/api/certs/test.internal
```

### SSH-Setup (für neue Skills)

```bash
# Von OpenClaw-Container zu Remote-Server
ssh root@192.168.1.11
ssh-keygen -t ed25519 -C "openclaw-<service>" -N "" -f ~/.ssh/id_ed25519
ssh-copy-id root@<remote-server-ip>
```

## Development Workflow

### Neue Funktion in cert-manager hinzufügen

1. **Lokale Änderung:**
   ```bash
   # Editiere Python-Code
   nano skills/cert-manager/lib/certificate_manager.py
   ```

2. **Version erhöhen:**
   ```bash
   # In skills/cert-manager/web/templates/base.html
   # v1.1.0 → v1.1.1
   ```

3. **Deployment:**
   ```bash
   scp skills/cert-manager/lib/certificate_manager.py root@192.168.1.11:/opt/openclaw/skills/cert-manager/lib/
   scp skills/cert-manager/web/templates/base.html root@192.168.1.11:/opt/openclaw/skills/cert-manager/web/templates/
   ssh root@192.168.1.11 "systemctl restart cert-manager-api cert-manager-web"
   ```

4. **Git Commit:**
   ```bash
   git add skills/cert-manager/
   git commit -m "Description v1.1.1

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   git push origin master
   ```

### Neues Skill erstellen

Orientiere dich an `skills/pihole-dns-manager/` Struktur:

```
skills/new-skill/
├── new-skill.sh              # Hauptscript
├── lib/
│   └── api.sh               # Helper-Funktionen
├── config.yaml              # Konfiguration (Server-IPs, SSH-User)
├── deploy-skill.sh          # Deployment-Script
├── examples/
│   └── test-*.sh            # Test-Scripts
└── README.md
```

**Wichtig:**
- Alle Remote-Operations via SSH (kein API-Token)
- `subprocess.run()` mit `stdin=subprocess.PIPE` in Python
- SSH-Flags: `-T` für non-interactive (außer bei step-ca!)
- Error-Handling: Logge Fehler, aber brich nicht immer ab

## Critical Implementation Details

### subprocess.run() für SSH-basierte Skills

```python
# In certificate_manager.py - Richtig:
result = subprocess.run(
    [script_path, "command", "--arg", "value"],
    stdin=subprocess.PIPE,      # Wichtig für non-interactive
    capture_output=True,
    text=True,
    timeout=30
)

# SSH-Fehler filtern (aus stderr):
stderr_lines = result.stderr.split('\n')
filtered = [l for l in stderr_lines if not l.startswith('Warning: Permanently added')]
```

### SSH zu step-ca (Spezialfall)

```bash
# In traefik-service-manager/lib/cert-manager.sh
# KEIN -T flag, weil step-cli interaktiv ist!
ssh root@192.168.1.3 "bash /root/create-cert.sh hostname < /dev/null"

# step ca certificate MUSS --force flag haben:
step ca certificate "${COMMON_NAME}" "${CRT_FILE}" "${KEY_FILE}" \
    --provisioner-password-file=/srv/pki/.provisioner_password --force
```

### Pi-hole v6 DNS-Management

```bash
# Kein API - direkte Config-File-Bearbeitung via SSH
ssh root@192.168.1.7 "echo '192.168.1.23 hostname.internal' >> /etc/pihole/custom.list"
ssh root@192.168.1.7 "pihole restartdns reload"

# Entfernen:
ssh root@192.168.1.7 "sed -i '/ hostname.internal$/d' /etc/pihole/custom.list"
```

### Traefik Config Struktur

```yaml
# /docker/volume/traefik/dynamic/hostname-internal.yml
http:
  routers:
    hostname-internal:
      rule: "Host(`hostname.internal`)"
      service: hostname-internal
      tls: {}
  services:
    hostname-internal:
      loadBalancer:
        servers:
          - url: "https://backend-ip"

# tls.yml (für interne Services):
tls:
  certificates:
    - certFile: /srv/pki/hostname/fullchain.crt
      keyFile: /srv/pki/hostname/hostname.key
```

## Common Pitfalls

1. **`systemctl status openclaw-agent@*` gibt keinen Output**
   - OpenClaw Agents existieren NICHT
   - Nur Skills sind deployed
   - Siehe `agents/README.md` für Status

2. **Pi-hole API-Token fehlt**
   - Pi-hole v6 hat kein API-Token-System
   - Verwende SSH mit Key-Auth
   - Config in `skills/pihole-dns-manager/config.yaml`: `access_method: ssh`

3. **Traefik-Config bleibt nach Zertifikats-Löschung**
   - Seit v1.0.9 wird `_delete_traefik_service()` automatisch aufgerufen
   - Prüfe Audit-Log: `action: delete_traefik_service`

4. **SSH TTY-Fehler "error allocating terminal"**
   - Verwende `-T` flag für alle SSH-Calls (außer step-ca!)
   - `subprocess.run()` braucht `stdin=subprocess.PIPE`
   - Root Cause oft: `step ca certificate` ohne `--force` flag

5. **Version-Nummer nicht aktualisiert**
   - User-Anforderung: **Bei jeder Änderung Version erhöhen**
   - Datei: `skills/cert-manager/web/templates/base.html` Zeile 27
   - Format: `v1.1.0` → `v1.1.1` (semantic versioning)

## File Locations

### Auf OpenClaw-Container (192.168.1.11)

```
/opt/openclaw/
├── skills/
│   ├── cert-manager/           # Port 5000 (Web), 5001 (API)
│   │   ├── api/main.py        # FastAPI REST API
│   │   ├── web/app.py         # Flask Web-UI
│   │   ├── lib/certificate_manager.py  # Business Logic
│   │   └── data/cert_manager.db        # SQLite Datenbank
│   ├── traefik-service-manager/
│   │   └── traefik-service-manager.sh
│   └── pihole-dns-manager/
│       └── pihole-dns-manager.sh
└── .env                       # Sensitive Config (gitignored)
```

### Auf step-ca (192.168.1.3)

```
/root/create-cert.sh           # Zertifikats-Erstellungs-Script
/srv/pki/<hostname>/           # Zertifikatsspeicher
```

### Auf Traefik (192.168.1.23)

```
/docker/volume/traefik/
├── dynamic/
│   ├── <hostname>-internal.yml  # Service Configs
│   └── tls.yml                  # TLS-Zertifikats-Mappings
└── traefik.yml                  # Haupt-Config
```

### Auf Pi-hole (192.168.1.7)

```
/etc/pihole/custom.list        # Custom DNS-Records
```

## Git Workflow

**Immer Co-Authored-By Tag verwenden:**

```bash
git commit -m "Beschreibung der Änderung

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Branch:** `master` (main branch)
**Remote:** `https://github.com/seemedFilm/openclaw_agent.git`

## Documentation

- `README.md` - Projekt-Overview
- `DEPLOYMENT-PIHOLE-DNS.md` - Pi-hole Integration Anleitung
- `agents/README.md` - Status: Agents nicht implementiert, Skills als Alternative
- `skills/*/README.md` - Skill-spezifische Dokumentation
- `docs/` - Deployment-Guides, Troubleshooting

## Wichtige Config-Dateien

- `skills/cert-manager/config/settings.yaml` - Cert-Manager Konfiguration
- `skills/traefik-service-manager/config.yaml` - Traefik Server IPs
- `skills/pihole-dns-manager/config.yaml` - Pi-hole Server IP, SSH-User

**Alle enthalten Server-IPs - bei Änderungen aktualisieren!**
