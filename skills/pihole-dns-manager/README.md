# Pi-hole DNS Manager Skill

Verwaltet DNS-Einträge in Pi-hole für automatische DNS-Auflösung von Traefik-Services.

## Zweck

Wenn ein Zertifikat mit Traefik-Integration erstellt wird:
1. Cert-Manager erstellt Zertifikat via step-ca
2. Traefik-Service-Manager erstellt Traefik-Config
3. **Pi-hole-DNS-Manager fügt DNS-Record hinzu** ← Dieser Skill
4. Service ist über Hostname erreichbar (z.B. `https://myapp.internal`)

## Konfiguration

### config.yaml

```yaml
pihole:
  host: "192.168.1.7"
  api_endpoint: "http://192.168.1.7/admin/api.php"
  api_token_env: "PIHOLE_API_TOKEN"
  traefik_ip: "192.168.1.23"
```

### API-Token setzen

**Empfohlen (Environment Variable):**
```bash
export PIHOLE_API_TOKEN="your-token-here"
```

**Oder direkt in config.yaml (NICHT empfohlen):**
```yaml
pihole:
  api_token: "your-token-here"
```

### API-Token generieren

1. Öffne Pi-hole Web-Interface: `http://192.168.1.7/admin`
2. Login mit Admin-Passwort
3. Settings → API → Generate Token
4. Kopiere Token

## Usage

### DNS-Record hinzufügen

```bash
# Mit Default-IP (Traefik aus config.yaml)
./pihole-dns-manager.sh add --hostname myapp.internal

# Mit custom IP
./pihole-dns-manager.sh add --hostname myapp.internal --ip 192.168.1.100
```

### DNS-Record entfernen

```bash
./pihole-dns-manager.sh remove --hostname myapp.internal
```

### Alle Records auflisten

```bash
./pihole-dns-manager.sh list
```

### Prüfen ob Record existiert

```bash
./pihole-dns-manager.sh check --hostname myapp.internal
```

### API-Verbindung testen

```bash
./pihole-dns-manager.sh test
```

## Integration mit cert-manager

Der cert-manager ruft dieses Skill automatisch auf nach erfolgreicher Traefik-Config-Erstellung.

**In `certificate_manager.py`:**
```python
# Nach _create_traefik_service() Erfolg:
if backend_ip:
    self._add_pihole_dns(hostname, TRAEFIK_IP)
```

## Troubleshooting

### ERROR: Pi-hole API Token nicht gefunden

```bash
# Prüfe Environment-Variable
echo $PIHOLE_API_TOKEN

# Falls leer, setze Token
export PIHOLE_API_TOKEN="your-token-here"
```

### ERROR: Pi-hole API nicht erreichbar

```bash
# Teste Netzwerk-Verbindung
ping 192.168.1.7

# Teste HTTP-Zugriff
curl http://192.168.1.7/admin/api.php?status

# Prüfe ob Pi-hole läuft
ssh root@192.168.1.7 "systemctl status pihole-FTL"
```

### DNS-Record wird nicht aufgelöst

```bash
# Test DNS-Auflösung via Pi-hole
dig myapp.internal @192.168.1.7

# Prüfe ob Record in Pi-hole existiert
./pihole-dns-manager.sh check --hostname myapp.internal

# Liste alle Custom-DNS-Records
./pihole-dns-manager.sh list
```

## Deployment

```bash
# Kopiere Skill zum OpenClaw-Container
scp -r skills/pihole-dns-manager root@192.168.1.11:/opt/openclaw/skills/

# Teste auf Container
ssh root@192.168.1.11
cd /opt/openclaw/skills/pihole-dns-manager
export PIHOLE_API_TOKEN="your-token"
./pihole-dns-manager.sh test
```

## Logs

Logs werden geschrieben nach:
- `/var/log/pihole-dns-manager.log` (wenn logging enabled in config.yaml)
- stdout/stderr (interaktive Verwendung)

## Security

⚠️ **API-Token schützen:**
- NIEMALS in Git committen
- Nur via Environment-Variable
- Alternativ: `/opt/openclaw/.env` verwenden

✅ **Best Practice:**
```bash
# In /opt/openclaw/.env
PIHOLE_API_TOKEN="your-token-here"

# In systemd Service-File
EnvironmentFile=/opt/openclaw/.env
```

## Version

v1.0.0 - Initial Release
