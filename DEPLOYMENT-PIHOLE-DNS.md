# Pi-hole DNS Manager - Deployment-Anleitung

## Was wurde implementiert?

**Cert-Manager v1.1.0** mit vollständiger Pi-hole DNS-Integration.

### Vollständiger Workflow:

```
1. User erstellt Zertifikat via Web-UI
   http://192.168.1.11:5000
   ↓
2. cert-manager erstellt Zertifikat
   step-ca Server (192.168.1.3)
   ↓
3. traefik-service-manager erstellt Config
   Traefik Server (192.168.1.23)
   ↓
4. pihole-dns-manager erstellt DNS-Eintrag  ← NEU!
   Pi-hole Server (192.168.1.7)
   ↓
5. ✓ Service erreichbar: https://myapp.internal
```

## Deployment-Schritte

### 1. SSH-Zugriff zu Pi-hole einrichten

**Pi-hole v6 hat kein API-Token-System - verwende SSH:**

```bash
# SSH zum OpenClaw-Container
ssh root@192.168.1.11

# SSH-Key generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "openclaw-pihole" -N "" -f ~/.ssh/id_ed25519

# Public Key zu Pi-hole kopieren
ssh-copy-id root@192.168.1.7

# Test SSH-Verbindung
ssh root@192.168.1.7 "cat /etc/pihole/custom.list"
```

### 2. pihole-dns-manager deployen

```bash
# Von lokalem Rechner
cd skills/pihole-dns-manager
bash deploy-skill.sh 192.168.1.11
```

### 3. pihole-dns-manager testen

```bash
# SSH zum Container
ssh root@192.168.1.11

# Test SSH-Verbindung
cd /opt/openclaw/skills/pihole-dns-manager
./pihole-dns-manager.sh test

# Erwartete Ausgabe:
# 🔗 Teste Pi-hole SSH-Verbindung...
#    Host: 192.168.1.7
#    User: root
#    Custom-List: /etc/pihole/custom.list
#    Methode: ssh
#    ✓ SSH-Verbindung OK
#    ✓ custom.list zugreifbar
#    ✓ pihole Command verfügbar
#    Version: Pi-hole v6.x.x
```

### 4. cert-manager aktualisieren

```bash
# Von lokalem Rechner
scp skills/cert-manager/lib/certificate_manager.py root@192.168.1.11:/opt/openclaw/skills/cert-manager/lib/
scp skills/cert-manager/web/templates/base.html root@192.168.1.11:/opt/openclaw/skills/cert-manager/web/templates/

# Auf Container: Services neustarten
ssh root@192.168.1.11 "systemctl restart cert-manager-api cert-manager-web"

# Prüfe Status
ssh root@192.168.1.11 "systemctl status cert-manager-api cert-manager-web"
```

## End-to-End Test

### Test 1: Zertifikat mit Pi-hole DNS erstellen

```bash
# Von lokalem Rechner
curl -X POST http://192.168.1.11:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "pihole-test.internal",
    "type": "step-ca",
    "create_traefik_config": true,
    "backend_ip": "https://192.168.1.50:8080"
  }'
```

**Erwartete Response:**
```json
{
  "success": true,
  "message": "Certificate created successfully",
  "traefik_config_created": true,
  "traefik_url": "https://pihole-test.internal",
  "pihole_dns_created": true
}
```

### Test 2: DNS-Auflösung prüfen

```bash
# Test DNS via Pi-hole
dig pihole-test.internal @192.168.1.7

# Erwartete Antwort:
# ;; ANSWER SECTION:
# pihole-test.internal. 3600 IN A 192.168.1.23
```

### Test 3: HTTPS-Zugriff testen

```bash
# Von lokalem Rechner (mit Pi-hole als DNS)
curl -k https://pihole-test.internal/

# Sollte Backend erreichen (192.168.1.50:8080)
```

### Test 4: Zertifikat löschen (inkl. DNS-Cleanup)

```bash
# Via API
curl -X DELETE http://192.168.1.11:5001/api/certs/pihole-test.internal

# Prüfe DNS-Eintrag entfernt
dig pihole-test.internal @192.168.1.7
# Sollte NXDOMAIN oder keine A-Record zurückgeben
```

## Troubleshooting

### ERROR: SSH-Verbindung fehlgeschlagen

```bash
# Test SSH-Verbindung
ssh root@192.168.1.11
ssh root@192.168.1.7

# Falls fehlgeschlagen: Public Key Error
# → Kopiere SSH-Key nochmal
ssh-copy-id root@192.168.1.7

# Test erneut
ssh root@192.168.1.7 "cat /etc/pihole/custom.list"
```

### ERROR: custom.list nicht gefunden

```bash
# Prüfe Pi-hole Installation
ssh root@192.168.1.7 "ls -la /etc/pihole/"

# custom.list sollte existieren
# Falls nicht: Pi-hole neu installieren oder Pfad in config.yaml anpassen
```

### pihole_dns_created: false in Response

```bash
# Prüfe Audit-Log
curl http://192.168.1.11:5001/api/audit-log | jq '.[-5:]'

# Suche nach:
# "action": "add_pihole_dns"
# "status": "failed" oder "warning"

# Häufige Ursachen:
# 1. API-Token fehlt oder falsch
# 2. Pi-hole nicht erreichbar
# 3. DNS-Record existiert bereits (wird als warning geloggt, nicht als error)
```

### DNS-Record wird nicht aufgelöst

```bash
# 1. Prüfe ob Record in Pi-hole existiert
ssh root@192.168.1.11 "/opt/openclaw/skills/pihole-dns-manager/pihole-dns-manager.sh list"

# 2. Prüfe DNS-Server Konfiguration
# Clients müssen Pi-hole (192.168.1.7) als DNS-Server verwenden

# 3. DNS-Cache leeren (auf Client)
# Windows: ipconfig /flushdns
# Linux: sudo systemd-resolve --flush-caches
# macOS: sudo dscacheutil -flushcache
```

## SSH-Key Management für systemd Services

Falls cert-manager als systemd-Service läuft, stelle sicher dass der SSH-Key zugreifbar ist:

**Service-User:** root (Standard)
**SSH-Key:** `/root/.ssh/id_ed25519`

```bash
# Prüfe SSH-Key existiert
ssh root@192.168.1.11 "ls -la ~/.ssh/"

# Test von systemd-Service Context
ssh root@192.168.1.11 "sudo -u root ssh -T root@192.168.1.7 'cat /etc/pihole/custom.list'"
```

Kein Environment-File notwendig - SSH-Key wird automatisch verwendet!

## Logs

### cert-manager Audit-Log (Pi-hole-Aktionen)

```bash
# Letzte 20 Einträge
curl http://192.168.1.11:5001/api/audit-log | jq '.[-20:]'

# Nur Pi-hole-Aktionen
curl http://192.168.1.11:5001/api/audit-log | jq '.[] | select(.action | contains("pihole"))'

# Fehlerhafte Pi-hole-Aktionen
curl http://192.168.1.11:5001/api/audit-log | jq '.[] | select(.action | contains("pihole")) | select(.status == "failed")'
```

### pihole-dns-manager Logs

```bash
# stdout/stderr (bei manueller Ausführung)
ssh root@192.168.1.11 "/opt/openclaw/skills/pihole-dns-manager/pihole-dns-manager.sh test"

# Systemd-Logs (falls als Service)
ssh root@192.168.1.11 "journalctl -u cert-manager-api -f | grep pihole"
```

## Warum `systemctl status openclaw-agent@*` keinen Output gibt

**Antwort:** Die OpenClaw Agents sind **nicht implementiert**.

- OpenClaw CLI existiert nicht (`/usr/bin/openclaw` fehlt)
- Systemd-Services `openclaw-agent@*.service` existieren nicht
- Die Agent-Dokumentation in `agents/` ist nur Konzept/Vision

**Stattdessen:**
- ✅ Skill-basierte Lösung implementiert
- ✅ cert-manager + traefik-service-manager + pihole-dns-manager
- ✅ Einfacher, wartbarer, vollständig ausreichend

Siehe: `agents/README.md` für Details.

## Änderungsübersicht v1.1.0

**Neue Dateien:**
- `skills/pihole-dns-manager/` (komplett neu)
  - pihole-dns-manager.sh - Hauptscript
  - lib/pihole-api.sh - API-Wrapper
  - config.yaml - Konfiguration
  - deploy-skill.sh - Deployment-Script
  - examples/test-pihole-api.sh - Test-Suite
  - README.md - Dokumentation

**Geänderte Dateien:**
- `skills/cert-manager/lib/certificate_manager.py`
  - `_add_pihole_dns()` - Neue Funktion
  - `_remove_pihole_dns()` - Neue Funktion
  - Integration in `create_certificate()`
  - Integration in `delete_certificate()`
  
- `skills/cert-manager/web/templates/base.html`
  - Version: v1.0.9 → v1.1.0

- `agents/README.md`
  - Status dokumentiert: "Konzept-Phase, nicht implementiert"
  - Alternative Skill-basierte Lösung beschrieben

**Git Commit:**
```
4b1d121 - Add Pi-hole DNS Manager integration v1.1.0
```

## Nächste Schritte

1. ✅ Deployment durchführen (siehe oben)
2. ✅ Pi-hole API-Token setzen
3. ✅ End-to-End Test durchführen
4. 📝 Produktiv nutzen!

Bei Problemen: Siehe Troubleshooting-Sektion oder Audit-Log prüfen.
