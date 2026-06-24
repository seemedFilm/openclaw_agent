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
  access_method: "ssh"  # SSH-basiert (empfohlen, v5/v6 kompatibel)
  ssh_user: "root"
  custom_list: "/etc/pihole/custom.list"
  traefik_ip: "192.168.1.23"
```

### SSH-Zugriff einrichten

**Pi-hole v6 hat kein API-Token-System mehr - verwende SSH:**

```bash
# Von OpenClaw-Container (192.168.1.11) zu Pi-hole (192.168.1.7)
ssh root@192.168.1.11

# SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "openclaw-pihole" -N "" -f ~/.ssh/id_ed25519

# Public Key zu Pi-hole kopieren
ssh-copy-id root@192.168.1.7

# Test SSH-Verbindung
ssh root@192.168.1.7 "cat /etc/pihole/custom.list"
```

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

### ERROR: SSH-Verbindung fehlgeschlagen

```bash
# Teste SSH-Verbindung
ssh root@192.168.1.7

# Falls fehlgeschlagen: Kopiere SSH-Key
ssh root@192.168.1.11
ssh-copy-id root@192.168.1.7

# Test erneut
ssh root@192.168.1.7 "cat /etc/pihole/custom.list"
```

### ERROR: custom.list nicht gefunden

```bash
# Prüfe Pi-hole Installation
ssh root@192.168.1.7 "ls -la /etc/pihole/"

# custom.list sollte existieren
# Falls nicht: Pi-hole ist nicht korrekt installiert
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

⚠️ **SSH-Key schützen:**
- Private Key nur auf OpenClaw-Container
- Nicht in Git committen
- Regelmäßig rotieren

✅ **Best Practice:**
```bash
# SSH-Key mit Passphrase
ssh-keygen -t ed25519 -C "openclaw-pihole"

# Nur Public Key zu Pi-hole kopieren
ssh-copy-id root@192.168.1.7

# Private Key bleibt auf 192.168.1.11
```

## Version

v1.0.0 - Initial Release
