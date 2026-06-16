# Cert-Manager Quick Start

Schnelleinstieg in 5 Minuten.

## Installation

### 1. Deployment (von lokaler Maschine)

```bash
cd skills/cert-manager
bash deploy.sh
```

Das Script:
- Kopiert alle Dateien per rsync
- Installiert Python-Dependencies
- Erstellt SSH-Keys für step-ca
- Initialisiert die Datenbank
- Installiert Systemd-Services
- Startet alle Services

### 2. SSH-Key auf step-ca Server kopieren

```bash
# Der Public Key wird während des Deployments angezeigt
# Führe auf 192.168.1.3 aus:
echo '<PUBLIC-KEY>' >> /root/.ssh/authorized_keys
```

### 3. Traefik-Route einrichten

```bash
ssh root@192.168.1.11

/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add \
  --hostname certs.internal \
  --backend http://192.168.1.11:5000
```

### 4. BasicAuth konfigurieren (optional aber empfohlen)

```bash
# Auf lokalem Rechner
htpasswd -nb admin YourSecurePassword | base64

# Auf Traefik-Server (192.168.1.23)
ssh root@192.168.1.23

cat > /docker/volume/traefik/dynamic/middleware-cert-manager-auth.yml <<EOF
http:
  middlewares:
    cert-manager-auth:
      basicAuth:
        users:
          - "admin:\$apr1\$HASH_HIER_EINFÜGEN"
EOF

# Router aktualisieren
nano /docker/volume/traefik/dynamic/certs.internal.yml
# Füge hinzu unter router:
#   middlewares:
#     - cert-manager-auth

docker restart traefik
```

## Verwendung

### Web-Interface öffnen

```
https://certs.internal
```

Login: admin / YourSecurePassword (falls BasicAuth aktiviert)

### Neues Zertifikat erstellen (Web-UI)

1. Klicke **"Neues Zertifikat"**
2. Hostname: `myapp.internal`
3. Typ: **step-ca** (Auto-gewählt bei .internal)
4. Auto-Renewal: ✓ aktivieren
5. Klicke **"Erstellen"**

→ Zertifikat wird auf 192.168.1.3 erstellt  
→ Verfügbar unter `/srv/pki/myapp/`

### Zertifikat über API erstellen

```bash
curl -X POST http://localhost:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "myapp.internal",
    "type": "step-ca",
    "auto_renew": true
  }'
```

### Alle Zertifikate auflisten

```bash
curl http://localhost:5001/api/certs | jq
```

### Zertifikat manuell erneuern

```bash
curl -X POST http://localhost:5001/api/certs/myapp.internal/renew
```

## OpenClaw Integration (ops-agent)

### Zertifikat erstellen

```python
import requests

response = requests.post('http://localhost:5001/api/certs', json={
    'hostname': 'myapp.internal',
    'type': 'step-ca',
    'auto_renew': True
})

cert = response.json()['certificate']
print(f"Zertifikat erstellt: {cert['cert_path']}")
```

### Ablaufende Zertifikate prüfen

```python
import requests

response = requests.get('http://localhost:5001/api/certs')
certs = response.json()['certificates']

expiring = [c for c in certs if c['days_until_expiry'] < 30]
for cert in expiring:
    print(f"⚠️ {cert['hostname']} läuft in {cert['days_until_expiry']} Tagen ab")
```

## Monitoring

### Service-Status prüfen

```bash
systemctl status cert-manager-api
systemctl status cert-manager-web
systemctl status cert-manager-renewal
```

### Logs ansehen

```bash
# API Logs
journalctl -u cert-manager-api -f

# Renewal-Scheduler Logs
tail -f /opt/openclaw/skills/cert-manager/logs/renewal_scheduler.log

# Application Logs
tail -f /opt/openclaw/skills/cert-manager/logs/cert_manager.log
```

### Statistiken

```bash
curl http://localhost:5001/api/stats | jq
```

Output:
```json
{
  "total": 5,
  "valid": 4,
  "expiring_soon": 1,
  "expired": 0,
  "by_type": {
    "step_ca": 3,
    "letsencrypt": 2
  }
}
```

## Troubleshooting

### API nicht erreichbar

```bash
systemctl restart cert-manager-api
journalctl -u cert-manager-api -n 50
```

### Zertifikatserstellung schlägt fehl

```bash
# SSH zu step-ca testen
ssh -i /root/.ssh/cert_manager root@192.168.1.3 "ls -la /root/create-cert2.sh"

# Manuell testen
ssh root@192.168.1.3 "/root/create-cert2.sh testhost"
```

### Renewal-Scheduler läuft nicht

```bash
systemctl restart cert-manager-renewal
tail -f /opt/openclaw/skills/cert-manager/logs/renewal_scheduler.log
```

## Nächste Schritte

1. **Mehr Zertifikate hinzufügen** über Web-UI
2. **Auto-Renewal testen:** Warte 24h oder simuliere mit niedrigerem `check_interval_hours`
3. **Traefik-Integration:** Nutze erstellte Zertifikate in Traefik-Configs
4. **OpenClaw-Integration:** Verwende API im ops-agent für automatisierte Workflows

## Weitere Dokumentation

- **[README.md](README.md)** - Vollständige Dokumentation
- **[../traefik-service-manager/README.md](../traefik-service-manager/README.md)** - Traefik-Integration
- **[../../agents/ops-agent/README.md](../../agents/ops-agent/README.md)** - ops-agent Dokumentation
