# Traefik Service Manager

Automatisches Traefik Service Management mit integrierter Zertifikatserstellung für das OpenClaw Multi-Agent System.

## Features

- **Automatische Service-Typ-Erkennung**: `.internal` → step-ca Zertifikat, sonst Let's Encrypt
- **Zertifikatserstellung**: Integrierte step-ca-Zertifikatserstellung via SSH
- **Traefik-Konfiguration**: Auto-generiert Router und Service Configs
- **Rollback-Support**: Automatischer Rollback bei Fehlern
- **Audit-Logging**: Vollständige Operations-History

## Architektur

### Infrastruktur

- **192.168.1.3**: step-ca Zertifikatsserver
  - Script: `/root/create-cert2.sh {hostname}`
  - Output: `/srv/pki/{hostname}/` (*.crt, *.key, fullchain.crt)

- **192.168.1.23**: Traefik Docker-Server
  - Config: `/docker/volume/traefik/dynamic/`
  - Container: `traefik`

- **Shared Storage**: `/srv/pki` via Proxmox Bind Mount

### Service-Typen

**Externe Services** (z.B. `api.diefamilielang.de`):
- Let's Encrypt Zertifikat via Traefik certResolver
- Automatische HTTP→HTTPS Weiterleitung
- Standard-Middlewares: `redirect-https`, `secure`

**Interne Services** (z.B. `myapp.internal`):
- Zertifikat von step-ca Server
- Zertifikat-Referenz in `tls.yml`
- Keine certResolver-Konfiguration

## Installation

### 1. Verzeichnisstruktur

```bash
# Auf OpenClaw Container (192.168.1.11)
mkdir -p /opt/openclaw/skills/traefik-service-manager/{lib,examples}
```

### 2. Dateien kopieren

```bash
# Von lokalem Repo
scp -r skills/traefik-service-manager/* root@192.168.1.11:/opt/openclaw/skills/traefik-service-manager/
```

### 3. Executable-Rechte

```bash
ssh root@192.168.1.11
chmod +x /opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh
chmod +x /opt/openclaw/skills/traefik-service-manager/lib/*.sh
```

### 4. SSH-Keys einrichten

```bash
# Auf OpenClaw Container
ssh-keygen -t ed25519 -C "openclaw-skills" -f /root/.ssh/openclaw_skills -N ""

# Public Key kopieren
ssh-copy-id -i /root/.ssh/openclaw_skills.pub root@192.168.1.3
ssh-copy-id -i /root/.ssh/openclaw_skills.pub root@192.168.1.23

# SSH Config
cat >> /root/.ssh/config <<EOF

Host step-ca
    HostName 192.168.1.3
    User root
    IdentityFile /root/.ssh/openclaw_skills

Host traefik-server
    HostName 192.168.1.23
    User root
    IdentityFile /root/.ssh/openclaw_skills
EOF

chmod 600 /root/.ssh/config /root/.ssh/openclaw_skills
```

## Verwendung

### Externen Service hinzufügen

```bash
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add \
  --hostname api.diefamilielang.de \
  --backend https://192.168.1.50:8080
```

**Was passiert:**
1. Validierung von Hostname und Backend
2. Traefik-Config mit certResolver: letsencrypt wird erstellt
3. Config wird auf Traefik-Server deployed
4. Traefik-Container wird neugestartet
5. Let's Encrypt erstellt Zertifikat beim ersten HTTPS-Zugriff

### Internen Service hinzufügen

```bash
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add \
  --hostname myapp.internal \
  --backend https://192.168.1.51:3000
```

**Was passiert:**
1. Validierung von Hostname und Backend
2. SSH zu step-ca Server (192.168.1.3)
3. Ausführung: `/root/create-cert2.sh myapp`
4. Zertifikat wird in `/srv/pki/myapp/` erstellt
5. `tls.yml` wird erweitert mit Zertifikats-Referenz
6. Traefik-Config ohne certResolver wird erstellt
7. Config wird deployed, Traefik neugestartet

### Service entfernen

```bash
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh remove \
  --hostname api.diefamilielang.de
```

**Was passiert:**
1. Config-Backup erstellen
2. Service-Config löschen
3. Bei internen Services: Eintrag aus `tls.yml` entfernen
4. Traefik neu starten

### Services auflisten

```bash
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh list
```

### Zertifikate auflisten

```bash
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh certs
```

## Integration mit ops-agent

### Direkt via SSH

```bash
# Vom OpenClaw ops-agent
ssh root@192.168.1.11 '/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add --hostname api.example.com --backend https://192.168.1.50:8080'
```

### In ops-agent prompts.md

```markdown
## Traefik Service Manager Skill

Zum Hinzufügen von Traefik-Diensten:

ssh root@192.168.1.11 '/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add --hostname <FQDN> --backend <URL>'

Das Skill erkennt automatisch:
- Externe Domains → Let's Encrypt
- Interne Domains (.internal) → step-ca Zertifikat
```

## Konfiguration

Bearbeite `config.yaml` für:
- SSH-Hosts und Credentials
- Traefik-Pfade und Container-Name
- Default-Middlewares
- Zertifikats-Einstellungen
- Behavior-Flags

## Workflows

### Externe Service Flow

```
1. Validate Input
2. Detect External Service (no .internal)
3. Generate Config:
   - certResolver: letsencrypt
   - Middlewares: redirect-https, secure
4. Deploy to Traefik
5. Restart Traefik
6. Let's Encrypt auto-issues cert on first HTTPS access
```

### Interne Service Flow

```
1. Validate Input
2. Detect Internal Service (.internal suffix)
3. SSH to step-ca (192.168.1.3)
4. Run: /root/create-cert2.sh {hostname}
5. Verify cert in /srv/pki/{hostname}/
6. Update tls.yml with cert path
7. Generate config WITHOUT certResolver
8. Deploy to Traefik
9. Restart Traefik
```

## Troubleshooting

### Zertifikatserstellung schlägt fehl

**Problem:** `ERROR: Certificate creation failed`

**Lösungen:**
1. Prüfe SSH-Zugriff zu 192.168.1.3:
   ```bash
   ssh root@192.168.1.3 "ls -la /root/create-cert2.sh"
   ```

2. Prüfe `/srv/pki` Permissions:
   ```bash
   ssh root@192.168.1.3 "ls -la /srv/pki"
   ```

3. Manuell testen:
   ```bash
   ssh root@192.168.1.3 "/root/create-cert2.sh testhost"
   ssh root@192.168.1.3 "ls -la /srv/pki/testhost/"
   ```

### Traefik nimmt Config nicht an

**Problem:** Service nicht erreichbar nach Deployment

**Lösungen:**
1. Prüfe Traefik-Logs:
   ```bash
   ssh root@192.168.1.23 "docker logs traefik --tail 50"
   ```

2. Validiere Config-Syntax:
   ```bash
   ssh root@192.168.1.23 "cat /docker/volume/traefik/dynamic/{hostname}.yml"
   ```

3. Prüfe Traefik-Dashboard:
   ```
   http://192.168.1.23:8080/dashboard/
   ```

### Zertifikat nicht auf Traefik zugänglich

**Problem:** `ERROR: Certificate not accessible on Traefik server`

**Lösungen:**
1. Prüfe Proxmox Bind Mount:
   ```bash
   # Auf Proxmox Host
   ls -la /srv/pki

   # Auf Traefik Server
   ssh root@192.168.1.23 "ls -la /srv/pki"
   ```

2. Prüfe LXC Container Mount-Points:
   ```bash
   pct config 111  # OpenClaw Container
   pct config <traefik-lxc-id>
   ```

### Rollback fehlgeschlagen

**Problem:** Änderungen können nicht rückgängig gemacht werden

**Lösungen:**
1. Manueller Rollback:
   ```bash
   ssh root@192.168.1.23
   cd /docker/volume/traefik/dynamic/backup
   ls -lt  # Finde letztes Backup
   cp TIMESTAMP/*.yml /docker/volume/traefik/dynamic/
   docker restart traefik
   ```

## Sicherheit

### SSH-Key Permissions

```bash
chmod 600 /root/.ssh/openclaw_skills
chmod 600 /root/.ssh/config
```

### Input Validation

- Hostname: FQDN-Regex-Validierung
- Backend: URL-Format-Prüfung
- Command-Injection-Schutz: Keine Shell-Expansion in User-Input

### Backup-Strategie

- Automatisches Backup vor jeder Änderung
- Retention: 30 Tage
- Cleanup-Befehl:
  ```bash
  find /docker/volume/traefik/dynamic/backup -mtime +30 -delete
  ```

## Entwicklung

### Verzeichnisstruktur

```
traefik-service-manager/
├── traefik-service-manager.sh    # Hauptscript
├── config.yaml                    # Konfiguration
├── README.md                      # Diese Datei
├── lib/
│   ├── cert-manager.sh           # Zertifikatsverwaltung
│   ├── traefik-config.sh         # Config-Generator
│   └── validator.sh              # Input-Validierung
└── examples/
    ├── add-external-example.sh   # Beispiel: Extern
    └── add-internal-example.sh   # Beispiel: Intern
```

### Testing

```bash
# Unit Tests (Input-Validierung)
source lib/validator.sh
validate_hostname "api.example.com"
validate_backend "https://192.168.1.50:8080"

# Integration Test: Externer Service
./traefik-service-manager.sh add \
  --hostname test.diefamilielang.de \
  --backend https://192.168.1.50:8080

curl -I https://test.diefamilielang.de

./traefik-service-manager.sh remove --hostname test.diefamilielang.de

# Integration Test: Interner Service
./traefik-service-manager.sh add \
  --hostname testapp.internal \
  --backend https://192.168.1.51:3000

curl -I https://testapp.internal

./traefik-service-manager.sh remove --hostname testapp.internal
```

## Zukünftige Erweiterungen

- **Web-Interface**: Flask/FastAPI-basiertes UI
- **Monitoring**: Prometheus-Metriken Export
- **Health-Checks**: Automatische Backend-Erreichbarkeitsprüfung
- **Multi-Backend**: Load-Balancing über mehrere Backends
- **Certificate Monitoring**: Warnung bei ablaufenden Zertifikaten

## Lizenz

MIT License - Teil des OpenClaw Multi-Agent Systems

## Support

Bei Problemen:
1. Prüfe [Troubleshooting](#troubleshooting)
2. Logs prüfen: `/opt/openclaw/logs/traefik-service-manager.log`
3. Issue erstellen im OpenClaw Repository
