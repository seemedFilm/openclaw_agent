# Update-Strategie für OpenClaw Skills

## Übersicht

Das OpenClaw-System hat **zwei Update-Mechanismen**:

1. **Manuelles Update** (`update.sh`) - Für lokale Entwicklung
2. **Git-basiertes Update** (`update-from-git.sh`) - Für Produktion

## Methode 1: Manuelles Update (Entwicklung)

**Verwendung:** Während der Entwicklung, wenn lokale Änderungen getestet werden sollen.

### Workflow

```bash
# 1. Lokale Änderungen machen
nano skills/cert-manager/lib/certificate_manager.py

# 2. Einzelnes Skill aktualisieren
./update.sh cert-manager

# 3. Testen
curl http://192.168.1.11:5001/api/certs

# 4. Bei Problemen: Rollback
./update.sh rollback cert-manager
```

### Alle Skills aktualisieren

```bash
./update.sh all
```

### Status prüfen

```bash
./update.sh status
```

**Output:**
```
=== cert-manager ===
Active: active (running)
Memory: 45.2M

=== Skill Versionen ===
cert-manager: v1.1.0
traefik-service-manager: no version tag
pihole-dns-manager: v1.0.0

=== Letzte Backups ===
cert-manager-20260625-143022
cert-manager-20260625-120033
```

### Rollback

```bash
# Zeigt verfügbare Backups und fragt welches
./update.sh rollback cert-manager
```

## Methode 2: Git-basiertes Update (Produktion)

**Verwendung:** Nach Git Push, um Änderungen vom Repository zu deployen.

### Workflow

```bash
# 1. Änderungen committen und pushen
git add skills/cert-manager/
git commit -m "Fix bug in certificate_manager.py v1.1.1"
git push origin master

# 2. Auf lokalem Rechner: Update ausführen
./update-from-git.sh

# Das Script:
# - Macht git pull
# - Zeigt Änderungen
# - Erkennt betroffene Skills automatisch
# - Fragt nach Bestätigung
# - Deployed nur geänderte Skills
# - Zeigt Changelog
```

### Was passiert automatisch

1. **Git Pull** vom master Branch
2. **Änderungserkennung** - Welche Skills wurden geändert?
3. **Bestätigung** - "Fortfahren mit Update?"
4. **Backup** - Automatisches Backup aller Skills
5. **Deployment** - rsync zu 192.168.1.11
6. **Service-Restart** - systemctl restart für cert-manager
7. **Verifikation** - Status-Check

### Beispiel-Output

```
====================================================================
  OpenClaw Git-based Update
====================================================================

[14:30:22] ✓ Branch: master
[14:30:22] ✓ Aktueller Commit: 1916787
[14:30:23] ✓ Update erfolgreich: 1916787 → a3f5b21

[14:30:23] Geänderte Dateien:
  📝 Modified:  skills/cert-manager/lib/certificate_manager.py
  📝 Modified:  skills/cert-manager/web/templates/base.html

[14:30:23] Neue Commits:
  a3f5b21 Fix DNS cleanup bug v1.1.1

[14:30:23] Erkenne betroffene Skills...
[14:30:23] Zu aktualisierende Skills:
  - cert-manager

Fortfahren mit Update? (Y/n): y

[14:30:25] ✓ cert-manager aktualisiert
[14:30:26] ✓ Git-based Update abgeschlossen!

====================================================================
  Changelog: 1916787 → a3f5b21
====================================================================
  a3f5b21 - Fix DNS cleanup bug v1.1.1
```

## Update-Strategien im Detail

### Backup-System

**Automatisch vor jedem Update:**
```
/opt/openclaw/backups/
├── cert-manager-20260625-143022/
├── cert-manager-20260625-120033/
├── traefik-service-manager-20260625-091544/
└── pihole-dns-manager-20260624-223011/
```

**Backups enthalten:**
- Komplette Skill-Verzeichnisse
- Konfigurationen
- Scripts
- **Nicht:** Datenbanken (data/) und Logs (logs/)

### Was wird aktualisiert

**cert-manager:**
- Python-Code (lib/, api/, web/)
- Templates (web/templates/)
- Services werden neugestartet
- Datenbank bleibt unverändert

**traefik-service-manager:**
- Bash-Scripts
- Library-Funktionen
- Konfiguration (config.yaml)
- Keine Service-Restarts (stateless)

**pihole-dns-manager:**
- Bash-Scripts
- Library-Funktionen
- Konfiguration (config.yaml)
- Keine Service-Restarts (stateless)

### Deployment-Details

**rsync-Flags:**
```bash
rsync -az --info=progress2 \
    --exclude '.git' \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude 'data/' \
    --exclude 'logs/' \
    skills/cert-manager/ \
    root@192.168.1.11:/opt/openclaw/skills/cert-manager/
```

**Ausgeschlossen:**
- Git-Repository (.git/)
- Python Cache (__pycache__/, *.pyc)
- Datenbanken (data/)
- Logs (logs/)

## Automatisierung

### Cronjob für automatische Updates

```bash
# Auf lokalem Rechner oder CI/CD Server
# Täglich um 03:00 Uhr
0 3 * * * cd /path/to/openclaw && ./update-from-git.sh 2>&1 | tee -a update.log
```

### Git Hooks

**Pre-Push Hook** (Optional):

```bash
#!/bin/bash
# .git/hooks/pre-push

# Prüfe ob Version erhöht wurde bei cert-manager Änderungen
if git diff --name-only HEAD origin/master | grep -q "skills/cert-manager/"; then
    if ! git diff HEAD origin/master skills/cert-manager/web/templates/base.html | grep -q "v[0-9]"; then
        echo "ERROR: Version nicht erhöht in base.html!"
        exit 1
    fi
fi
```

## Troubleshooting

### Update schlägt fehl

```bash
# 1. Prüfe SSH-Verbindung
ssh root@192.168.1.11

# 2. Prüfe Logs
ssh root@192.168.1.11 "journalctl -u cert-manager-api -n 50"

# 3. Rollback
./update.sh rollback cert-manager

# 4. Manuell debuggen
ssh root@192.168.1.11
cd /opt/openclaw/skills/cert-manager
/opt/openclaw/venv/bin/python3 api/main.py
```

### Services starten nicht

```bash
# Status prüfen
ssh root@192.168.1.11 "systemctl status cert-manager-api -l"

# Manuell starten
ssh root@192.168.1.11 "systemctl start cert-manager-api"

# Fehler in Logs
ssh root@192.168.1.11 "journalctl -u cert-manager-api -f"
```

### Git Pull schlägt fehl

```bash
# Lokale Änderungen verwerfen
git reset --hard origin/master

# Oder: Lokale Änderungen stashen
git stash
git pull origin master
git stash pop
```

### Rollback funktioniert nicht

```bash
# Manuell von Backup wiederherstellen
ssh root@192.168.1.11

# Zeige Backups
ls -lt /opt/openclaw/backups/

# Restore
rm -rf /opt/openclaw/skills/cert-manager
cp -r /opt/openclaw/backups/cert-manager-20260625-143022 /opt/openclaw/skills/cert-manager

# Services neustarten
systemctl restart cert-manager-api cert-manager-web
```

## Best Practices

### Development Workflow

```bash
# 1. Feature-Branch erstellen (optional)
git checkout -b feature/new-feature

# 2. Änderungen machen
nano skills/cert-manager/lib/certificate_manager.py

# 3. Lokal testen
./update.sh cert-manager
# Test...

# 4. Version erhöhen
nano skills/cert-manager/web/templates/base.html
# v1.1.0 → v1.1.1

# 5. Commit
git add skills/cert-manager/
git commit -m "Add new feature v1.1.1

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# 6. Push
git push origin master  # oder feature/new-feature

# 7. Production Update
./update-from-git.sh
```

### Hotfix Workflow

```bash
# Bei kritischem Bug in Production:

# 1. Schneller Fix
nano skills/cert-manager/lib/certificate_manager.py

# 2. Direkt deployen (ohne git)
./update.sh cert-manager

# 3. Testen
curl http://192.168.1.11:5001/api/certs

# 4. Wenn OK: Committen
git add skills/cert-manager/
git commit -m "Hotfix: Critical bug v1.1.1"
git push origin master
```

### Version-Management

**Semantic Versioning:**
- `v1.0.0` → Initial Release
- `v1.0.1` → Bugfix
- `v1.1.0` → New Feature
- `v2.0.0` → Breaking Change

**Bei jeder Änderung erhöhen:**
```bash
# In skills/cert-manager/web/templates/base.html Zeile 27
<p>Cert-Manager v1.1.1 | OpenClaw Multi-Agent System</p>
```

## Monitoring

### Update-Logs

```bash
# Letzte Updates anzeigen
ssh root@192.168.1.11 "ls -lt /opt/openclaw/backups/ | head -10"

# Service-Logs nach Update
ssh root@192.168.1.11 "journalctl -u cert-manager-api --since '10 minutes ago'"
```

### Health-Checks nach Update

```bash
# 1. Services laufen?
./update.sh status

# 2. API erreichbar?
curl http://192.168.1.11:5001/api/certs

# 3. Web-UI erreichbar?
curl http://192.168.1.11:5000

# 4. Audit-Log zeigt neue Version?
curl http://192.168.1.11:5001/api/audit-log | tail -5
```

## Zusammenfassung

| Methode | Use-Case | Backup | Restart | Zeitaufwand |
|---------|----------|--------|---------|-------------|
| `update.sh all` | Development, alle Skills | ✅ Ja | ✅ Ja | ~30s |
| `update.sh cert-manager` | Single Skill Update | ✅ Ja | ✅ Ja | ~10s |
| `update-from-git.sh` | Production Deployment | ✅ Ja | ✅ Ja | ~45s |
| `update.sh rollback` | Fehler beheben | ❌ Nein | ✅ Ja | ~5s |
| Individuelle deploy-*.sh | Initial Setup | ❌ Nein | ✅ Ja | ~60s |

**Empfehlung:**
- **Entwicklung:** `update.sh <skill>`
- **Production:** `update-from-git.sh`
- **Notfall:** `update.sh rollback <skill>`
