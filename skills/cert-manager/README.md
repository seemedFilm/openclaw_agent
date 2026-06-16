# Cert-Manager

Automatisches SSL-Zertifikat-Management mit Web-Interface und OpenClaw-Integration.

## Features

- **Web-Interface**: Dashboard für Zertifikatsverwaltung (Port 5000)
- **REST API**: FastAPI-Backend für Web-UI und OpenClaw
- **Dual Certificate Sources**: 
  - step-ca für interne Services (192.168.1.3)
  - Let's Encrypt für externe Domains (via Traefik)
- **Automatic Renewal**: Monitoring und Auto-Renewal 30 Tage vor Ablauf
- **Audit-Logging**: Vollständige Operations-History
- **OpenClaw-Integration**: Verwendbar durch ops-agent

## Architektur

```
┌─────────────────────────────────────────────────────────┐
│                    Browser (User)                        │
│           https://certs.internal                         │
└───────────────┬─────────────────────────────────────────┘
                │
                │ HTTPS (Traefik BasicAuth)
                ↓
┌─────────────────────────────────────────────────────────┐
│           Traefik (192.168.1.23)                        │
│           Route: certs.internal → 192.168.1.11:5000     │
└───────────────┬─────────────────────────────────────────┘
                │
                ↓
┌─────────────────────────────────────────────────────────┐
│     OpenClaw Container (192.168.1.11)                   │
│                                                           │
│  ┌────────────────────────────────────────────────┐    │
│  │  Web-UI (Port 5000)                            │    │
│  │  - Dashboard: Zertifikatsübersicht             │    │
│  │  - Erstellen, Erneuern, Löschen                │    │
│  │  - Renewal-Job-Management                      │    │
│  │  - Audit-Log                                    │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │                                      │
│                   │ HTTP (intern)                        │
│                   ↓                                      │
│  ┌────────────────────────────────────────────────┐    │
│  │  FastAPI REST API (Port 5001)                  │    │
│  │  - GET    /api/certs                           │    │
│  │  - POST   /api/certs                           │    │
│  │  - DELETE /api/certs/{hostname}                │    │
│  │  - POST   /api/certs/{hostname}/renew          │    │
│  │  - GET    /api/renewal-jobs                    │    │
│  │  - POST   /api/renewal-jobs                    │    │
│  │  - GET    /api/audit-log                       │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │                                      │
│                   │                                      │
│  ┌────────────────────────────────────────────────┐    │
│  │  Cert-Manager Backend (lib/)                   │    │
│  │  - CertificateManager class                    │    │
│  │  - SSH zu step-ca                              │    │
│  │  - Datenbank (SQLite): Zertifikate + Logs     │    │
│  │  - Renewal-Scheduler                           │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │                                      │
│                   │ Auch nutzbar durch ↓                │
│                   │                                      │
│  ┌────────────────────────────────────────────────┐    │
│  │  OpenClaw ops-agent                            │    │
│  │  - HTTP-Client → REST API                      │    │
│  │  - Scheduled Renewals                          │    │
│  └────────────────────────────────────────────────┘    │
│                                                           │
└───────────────┬───────────────────────────────────────┘
                │
                │ SSH
                ↓
         ┌─────────────────────┐
         │  step-ca Server     │
         │  192.168.1.3        │
         │  /root/create-cert2.sh │
         │  Output: /srv/pki/  │
         └─────────────────────┘
```

## Installation

### 1. Dependencies installieren

```bash
ssh root@192.168.1.11

# Python-Pakete
pip3 install fastapi uvicorn pydantic sqlalchemy python-jose cryptography paramiko

# Frontend-Dependencies (optional)
apt install -y nginx  # Falls static files über nginx
```

### 2. Dateien kopieren

```bash
# Von lokaler Maschine
scp -r skills/cert-manager root@192.168.1.11:/opt/openclaw/skills/
```

### 3. SSH-Keys einrichten

**WICHTIG:** Der SSH-Key wird für zwei Server benötigt:
- **192.168.1.3** (step-ca) - Zertifikatserstellung und Dateiverwaltung
- **192.168.1.23** (Traefik) - Container-Neustart nach Zertifikatsänderungen

```bash
# Auf OpenClaw Container
ssh-keygen -t ed25519 -C "cert-manager" -f /root/.ssh/cert_manager -N ""

# Public Key auf step-ca Server kopieren
ssh-copy-id -i /root/.ssh/cert_manager.pub root@192.168.1.3

# Public Key auf Traefik Server kopieren
ssh-copy-id -i /root/.ssh/cert_manager.pub root@192.168.1.23

# SSH Config
cat >> /root/.ssh/config <<EOF

Host step-ca
    HostName 192.168.1.3
    User root
    IdentityFile /root/.ssh/cert_manager
    StrictHostKeyChecking no

Host traefik
    HostName 192.168.1.23
    User root
    IdentityFile /root/.ssh/cert_manager
    StrictHostKeyChecking no
EOF

chmod 600 /root/.ssh/config /root/.ssh/cert_manager

# SSH-Zugriff testen
ssh -i /root/.ssh/cert_manager root@192.168.1.3 "echo 'step-ca connection OK'"
ssh -i /root/.ssh/cert_manager root@192.168.1.23 "docker ps --filter name=traefik"
```

### 4. Datenbank initialisieren

```bash
cd /opt/openclaw/skills/cert-manager
python3 api/init_db.py
```

### 5. Systemd Services erstellen

```bash
# REST API Service
cat > /etc/systemd/system/cert-manager-api.service <<'EOF'
[Unit]
Description=Cert-Manager REST API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/skills/cert-manager
ExecStart=/usr/bin/python3 -m uvicorn api.main:app --host 0.0.0.0 --port 5001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Web-UI Service
cat > /etc/systemd/system/cert-manager-web.service <<'EOF'
[Unit]
Description=Cert-Manager Web UI
After=network.target cert-manager-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/skills/cert-manager
ExecStart=/usr/bin/python3 web/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Renewal-Scheduler Service
cat > /etc/systemd/system/cert-manager-renewal.service <<'EOF'
[Unit]
Description=Cert-Manager Renewal Scheduler
After=network.target cert-manager-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/skills/cert-manager
ExecStart=/usr/bin/python3 lib/renewal_scheduler.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Services aktivieren
systemctl daemon-reload
systemctl enable cert-manager-api cert-manager-web cert-manager-renewal
systemctl start cert-manager-api cert-manager-web cert-manager-renewal
```

### 6. Traefik-Route einrichten

```bash
# Über traefik-service-manager
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add \
  --hostname certs.internal \
  --backend http://192.168.1.11:5000
```

**Traefik BasicAuth hinzufügen:**

```bash
# BasicAuth Credentials generieren
apt install -y apache2-utils
htpasswd -nb admin YourPassword | base64

# Auf Traefik-Server (192.168.1.23)
ssh root@192.168.1.23

cat > /docker/volume/traefik/dynamic/middleware-cert-manager-auth.yml <<EOF
http:
  middlewares:
    cert-manager-auth:
      basicAuth:
        users:
          - "admin:\$apr1\$..." # Hier den Hash von htpasswd einfügen
EOF

# Router aktualisieren
nano /docker/volume/traefik/dynamic/certs.internal.yml
# Füge hinzu unter router:
#   middlewares:
#     - cert-manager-auth

docker restart traefik
```

## Verwendung

### Web-Interface

**URL:** `https://certs.internal`  
**Login:** admin / YourPassword (Traefik BasicAuth)

**Features:**
- 📊 Dashboard: Alle Zertifikate mit Status
- ➕ Neues Zertifikat erstellen
- 🔄 Manuelles Renewal
- 🗑️ Zertifikat löschen
- ⚙️ Renewal-Jobs konfigurieren
- 📜 Audit-Log einsehen

### REST API

**Base URL:** `http://localhost:5001/api` (intern)

#### Zertifikate auflisten

```bash
curl http://localhost:5001/api/certs
```

**Response:**
```json
{
  "certificates": [
    {
      "hostname": "myapp.internal",
      "type": "step-ca",
      "status": "valid",
      "created_at": "2026-06-01T10:00:00Z",
      "expires_at": "2027-06-01T10:00:00Z",
      "days_until_expiry": 358,
      "auto_renew": true
    },
    {
      "hostname": "api.example.com",
      "type": "letsencrypt",
      "status": "valid",
      "created_at": "2026-05-15T08:30:00Z",
      "expires_at": "2026-08-13T08:30:00Z",
      "days_until_expiry": 66,
      "auto_renew": true
    }
  ]
}
```

#### Zertifikat erstellen

```bash
# Einfaches Zertifikat (nur für Zertifikatsverwaltung)
curl -X POST http://localhost:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "newapp.internal",
    "type": "step-ca",
    "auto_renew": true
  }'

# Mit Backend-IP (für Traefik Reverse Proxy)
curl -X POST http://localhost:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "newapp.internal",
    "type": "step-ca",
    "backend_ip": "https://192.168.1.50:8080",
    "auto_renew": true
  }'

# Mit automatischer Traefik-Konfiguration
curl -X POST http://localhost:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "newapp.internal",
    "type": "step-ca",
    "backend_ip": "https://192.168.1.50:8080",
    "auto_renew": true,
    "create_traefik_config": true
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Certificate created successfully",
  "certificate": {
    "hostname": "newapp.internal",
    "type": "step-ca",
    "backend_ip": "https://192.168.1.50:8080",
    "cert_path": "/srv/pki/newapp/fullchain.crt",
    "key_path": "/srv/pki/newapp/newapp.key",
    "expires_at": "2027-06-08T15:30:00Z",
    "traefik_config_created": true
  }
}
```

#### Zertifikat erneuern

```bash
curl -X POST http://localhost:5001/api/certs/myapp.internal/renew
```

#### Zertifikat löschen

```bash
curl -X DELETE http://localhost:5001/api/certs/myapp.internal
```

**Was passiert beim Löschen:**
1. ✅ Datenbankeintrag wird gelöscht
2. ✅ Renewal-Jobs werden gelöscht
3. ✅ **Physische Zertifikatsdateien werden vom step-ca Server gelöscht** (`/srv/pki/{hostname}/`)
4. ✅ **Traefik Container wird neu gestartet** (um Zertifikatsänderungen zu laden)

**Response bei Erfolg:**
```json
{
  "success": true,
  "message": "Certificate for myapp.internal deleted successfully"
}
```

**Response bei teilweisem Erfolg (DB gelöscht, aber SSH-Fehler):**
```json
{
  "success": true,
  "message": "Certificate (step-ca) deleted (Warnings: Files could not be deleted: SSH connection failed)"
}
```

**Audit-Log-Status:**
- `success`: Alles erfolgreich
- `partial_success`: DB gelöscht, aber Dateien oder Traefik-Neustart fehlgeschlagen

#### Renewal-Jobs auflisten

```bash
curl http://localhost:5001/api/renewal-jobs
```

**Response:**
```json
{
  "jobs": [
    {
      "id": 1,
      "hostname": "myapp.internal",
      "enabled": true,
      "renew_days_before": 30,
      "last_run": "2026-06-01T03:00:00Z",
      "next_run": "2026-06-02T03:00:00Z",
      "status": "success"
    }
  ]
}
```

#### Renewal-Job erstellen

```bash
curl -X POST http://localhost:5001/api/renewal-jobs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "myapp.internal",
    "renew_days_before": 30,
    "enabled": true
  }'
```

#### Audit-Log abrufen

```bash
curl http://localhost:5001/api/audit-log?limit=50
```

**Response:**
```json
{
  "logs": [
    {
      "id": 123,
      "timestamp": "2026-06-08T14:30:00Z",
      "action": "create_certificate",
      "hostname": "myapp.internal",
      "user": "admin",
      "status": "success",
      "message": "Certificate created successfully"
    }
  ]
}
```

### OpenClaw Integration (ops-agent)

**In ops-agent Prompt/Skill:**

```python
import requests

# Zertifikat erstellen
response = requests.post('http://localhost:5001/api/certs', json={
    'hostname': 'myapp.internal',
    'type': 'step-ca',
    'auto_renew': True
})

if response.json()['success']:
    print(f"Certificate created: {response.json()['certificate']}")
```

**Oder via CLI:**

```bash
# Im ops-agent-Prompt
curl -X POST http://localhost:5001/api/certs -H "Content-Type: application/json" -d '{"hostname":"myapp.internal","type":"step-ca","auto_renew":true}'
```

## Konfiguration

### config/settings.yaml

```yaml
# SSL-Zertifikat-Management
certificate:
  step_ca:
    host: "192.168.1.3"
    user: "root"
    script_path: "/root/create-cert2.sh"
    output_path: "/srv/pki"
    ssh_key: "/root/.ssh/cert_manager"
    default_validity_days: 365
  
  letsencrypt:
    provider: "traefik"
    # Let's Encrypt wird durch Traefik verwaltet
    # Keine direkte Erstellung hier, nur Monitoring

# Traefik Integration (für Container-Neustart nach Zertifikatsänderungen)
traefik:
  host: "192.168.1.23"
  user: "root"
  ssh_key: "/root/.ssh/cert_manager"
  container_name: "traefik"

# Auto-Renewal
renewal:
  enabled: true
  check_interval_hours: 24
  renew_days_before: 30
  retry_on_failure: true
  max_retries: 3

# API
api:
  host: "0.0.0.0"
  port: 5001
  cors_origins:
    - "http://localhost:5000"
    - "https://certs.internal"

# Web-UI
web:
  host: "0.0.0.0"
  port: 5000
  title: "Cert-Manager"

# Database
database:
  type: "sqlite"
  path: "data/cert_manager.db"

# Logging
logging:
  level: "INFO"
  file: "logs/cert_manager.log"
  format: "json"
  audit_retention_days: 365
```

## Datenbank-Schema

**SQLite Datenbank:** `data/cert_manager.db`

### Tabelle: certificates

```sql
CREATE TABLE certificates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,  -- 'step-ca' or 'letsencrypt'
    backend_ip TEXT,     -- Backend-Server IP für Traefik (z.B. https://192.168.1.50:8080)
    cert_path TEXT,
    key_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    auto_renew BOOLEAN DEFAULT 1,
    last_renewed_at TIMESTAMP,
    status TEXT DEFAULT 'valid'  -- 'valid', 'expiring', 'expired', 'error'
);
```

### Tabelle: renewal_jobs

```sql
CREATE TABLE renewal_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    renew_days_before INTEGER DEFAULT 30,
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    status TEXT,  -- 'success', 'failed', 'pending'
    error_message TEXT,
    FOREIGN KEY (hostname) REFERENCES certificates(hostname)
);
```

### Tabelle: audit_log

```sql
CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action TEXT NOT NULL,  -- 'create', 'renew', 'delete', 'update'
    hostname TEXT NOT NULL,
    user TEXT,  -- 'web-ui', 'ops-agent', 'renewal-scheduler'
    status TEXT NOT NULL,  -- 'success', 'failed'
    message TEXT,
    details TEXT  -- JSON mit zusätzlichen Infos
);
```

## Workflows

### Workflow 1: Neues Zertifikat erstellen (Web-UI)

```
1. User navigiert zu https://certs.internal
2. Klickt "Neues Zertifikat"
3. Gibt Hostname ein (z.B. "newapp.internal")
4. Wählt Typ: step-ca oder Let's Encrypt
5. Optional: Gibt Backend-IP ein (z.B. "https://192.168.1.50:8080")
6. Optional: Aktiviert "Traefik-Konfiguration automatisch erstellen"
7. Aktiviert Auto-Renewal
8. Klickt "Erstellen"

→ Frontend sendet POST /api/certs mit backend_ip und create_traefik_config
→ Backend führt aus:
  - Validierung von Hostname und Backend-IP
  - SSH zu step-ca Server
  - Ausführung von /root/create-cert2.sh newapp
  - Verifizierung: /srv/pki/newapp/*.crt existiert
  - DB-Eintrag erstellen (inkl. backend_ip)
  - Falls create_traefik_config=true:
    * Führe traefik-service-manager.sh aus
    * Erstelle Traefik-Service-Konfiguration automatisch
  - Audit-Log schreiben
  - Renewal-Job erstellen (falls auto_renew=true)
→ Response an Frontend
→ Dashboard aktualisiert
```

### Workflow 2: Automatisches Renewal (Scheduled)

```
Renewal-Scheduler läuft alle 24 Stunden:

1. Query DB: SELECT * FROM certificates WHERE 
   auto_renew=1 AND 
   julianday(expires_at) - julianday('now') <= renew_days_before

2. Für jedes ablaufende Zertifikat:
   - Prüfe Typ (step-ca oder letsencrypt)
   - step-ca: SSH zu 192.168.1.3, run create-cert2.sh
   - letsencrypt: API-Call an Traefik für Renewal
   - Update DB: last_renewed_at, expires_at
   - Update renewal_job: last_run, next_run, status
   - Audit-Log: 'renew', 'renewal-scheduler', 'success'

3. Bei Fehler:
   - Retry nach 1 Stunde (max 3x)
   - Audit-Log: 'renew', 'renewal-scheduler', 'failed', error_message
   - Optional: Alert an ops-agent
```

### Workflow 3: OpenClaw ops-agent nutzt API

```python
# Im ops-agent-Code
import requests

def create_cert_for_service(hostname: str):
    """Erstelle Zertifikat für neuen Service"""
    
    # Bestimme Typ
    cert_type = "step-ca" if hostname.endswith(".internal") else "letsencrypt"
    
    # API-Call
    response = requests.post('http://localhost:5001/api/certs', json={
        'hostname': hostname,
        'type': cert_type,
        'auto_renew': True
    })
    
    if response.json()['success']:
        cert_info = response.json()['certificate']
        return cert_info
    else:
        raise Exception(f"Cert creation failed: {response.json()['message']}")
```

## Monitoring

### Zertifikats-Status prüfen

```bash
# Via API
curl http://localhost:5001/api/certs | jq '.certificates[] | select(.days_until_expiry < 30)'

# Via CLI-Tool
/opt/openclaw/skills/cert-manager/cli.py status --expiring-soon
```

### Renewal-Job-Status

```bash
curl http://localhost:5001/api/renewal-jobs | jq '.jobs[] | select(.status == "failed")'
```

### Logs

```bash
# Application Logs
tail -f /opt/openclaw/skills/cert-manager/logs/cert_manager.log

# Systemd Logs
journalctl -u cert-manager-api -f
journalctl -u cert-manager-renewal -f
```

## Troubleshooting

### API nicht erreichbar

```bash
# Service-Status prüfen
systemctl status cert-manager-api

# Port prüfen
netstat -tulpn | grep 5001

# Logs
journalctl -u cert-manager-api -n 50
```

### Zertifikatserstellung schlägt fehl

```bash
# SSH zu step-ca testen
ssh -i /root/.ssh/cert_manager root@192.168.1.3 "ls -la /root/create-cert2.sh"

# Manuell testen
ssh root@192.168.1.3 "/root/create-cert2.sh testhost"

# Audit-Log prüfen
curl http://localhost:5001/api/audit-log | jq '.logs[] | select(.status == "failed")'
```

### Zertifikatslöschung schlägt teilweise fehl

**Problem:** Zertifikat wurde aus DB gelöscht, aber Dateien bleiben auf step-ca Server oder Traefik wurde nicht neu gestartet.

**Diagnose:**
```bash
# Prüfe SSH-Zugriff auf step-ca
ssh -i /root/.ssh/cert_manager root@192.168.1.3 "ls -la /srv/pki/"

# Prüfe SSH-Zugriff auf Traefik
ssh -i /root/.ssh/cert_manager root@192.168.1.23 "docker ps"

# Prüfe Audit-Log für Details
curl http://localhost:5001/api/audit-log | jq '.logs[] | select(.action == "delete_certificate")'
```

**Lösung:**
```bash
# Manuelle Datei-Bereinigung
ssh root@192.168.1.3 "rm -rf /srv/pki/{hostname}"

# Manueller Traefik-Neustart
ssh root@192.168.1.23 "docker restart traefik"

# SSH-Key-Berechtigungen prüfen
ls -la /root/.ssh/cert_manager  # Sollte 600 sein
```

### Renewal-Scheduler läuft nicht

```bash
systemctl status cert-manager-renewal
journalctl -u cert-manager-renewal -n 100

# Manuelles Renewal testen
curl -X POST http://localhost:5001/api/certs/myapp.internal/renew
```

## Sicherheit

### SSH-Keys

```bash
chmod 600 /root/.ssh/cert_manager
chmod 600 /root/.ssh/config
```

### Traefik BasicAuth

Credentials niemals in Git committen:

```bash
# .gitignore
skills/cert-manager/config/basicauth.txt
```

### API-Zugriff

API ist nur intern erreichbar (0.0.0.0:5001, nicht über Traefik exposed).

Web-UI wird über Traefik mit BasicAuth geschützt.

## Zukünftige Erweiterungen

- **Multi-User-Support**: User-Management mit Rollen
- **Notifications**: E-Mail/Slack bei ablaufenden Zertifikaten
- **Metrics**: Prometheus-Export für Monitoring
- **Certificate Revocation**: Widerruf von Zertifikaten
- **Backup/Restore**: Automatische Backups der Datenbank

## Lizenz

MIT License - Teil des OpenClaw Multi-Agent Systems
