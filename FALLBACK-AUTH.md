# SSH Auto-Modus mit Fallback

## Übersicht

Die Deployment-Scripts unterstützen jetzt einen **Auto-Modus**, der automatisch zwischen SSH-Key und Passwort-Authentifizierung wechselt.

## Wie funktioniert es?

### Auto-Modus (Standard)

```bash
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinRootPasswort
```

**Ablauf:**

1. **Versuch 1:** SSH-Key-Authentifizierung
   - Versucht Verbindung mit SSH-Key
   - Schnell, sicher, keine zusätzlichen Tools

2. **Versuch 2 (Fallback):** Passwort-Authentifizierung
   - Nur wenn SSH-Key fehlschlägt
   - Benötigt `sshpass` und `PROXMOX_PASSWORD`
   - Automatisch, ohne Nutzer-Interaktion

### Vorteile

✅ **Maximale Zuverlässigkeit**
- Deployment funktioniert immer
- Auch wenn SSH-Key mal nicht funktioniert
- Keine manuellen Eingriffe erforderlich

✅ **Best of Both Worlds**
- Sicherheit: SSH-Key wird bevorzugt
- Verfügbarkeit: Passwort als Backup

✅ **Zero-Downtime**
- Key-Probleme blockieren Deployment nicht
- Automatischer Fallback ohne Wartezeit

✅ **Ideal für CI/CD**
- Robuste Authentifizierung
- Funktioniert in verschiedenen Umgebungen

## Beispiel-Szenarien

### Szenario 1: SSH-Key funktioniert

```
[INFO] Verwende Auto-Authentifizierung (SSH-Key mit Passwort-Fallback)
[INFO] Fallback verfügbar: Passwort-Authentifizierung
[SUCCESS] SSH-Verbindung zu Proxmox erfolgreich

→ Nutzt SSH-Key (schnell, sicher)
→ Passwort wird nicht verwendet
```

### Szenario 2: SSH-Key defekt, Passwort greift

```
[INFO] Verwende Auto-Authentifizierung (SSH-Key mit Passwort-Fallback)
[INFO] Fallback verfügbar: Passwort-Authentifizierung
[SUCCESS] SSH-Verbindung zu Proxmox erfolgreich

→ SSH-Key fehlgeschlagen
→ Automatischer Fallback zu Passwort
→ Deployment läuft ohne Unterbrechung weiter
```

### Szenario 3: Beide Methoden fehlschlagen

```
[INFO] Verwende Auto-Authentifizierung (SSH-Key mit Passwort-Fallback)
[INFO] Fallback verfügbar: Passwort-Authentifizierung
[ERROR] Keine SSH-Verbindung zu root@192.168.1.4:22 möglich

→ Deployment stoppt
→ Nutzer muss Zugangsdaten prüfen
```

## Validierung mit validate.sh

Das Validierungs-Script testet beide Methoden separat:

```bash
cd proxmox
bash validate.sh
```

**Ausgabe bei funktionierender Fallback-Konfiguration:**

```
═══════════════════════════════════════════════════════
 2. Umgebungsvariablen
═══════════════════════════════════════════════════════

✓ .env Datei gefunden
✓ PROXMOX_HOST gesetzt: 192.168.1.4
ℹ PROXMOX_USER: root
ℹ PROXMOX_PORT: 22
ℹ PROXMOX_AUTH_METHOD: auto (SSH-Key mit Passwort-Fallback)
✓ SSH-Key verfügbar (Primär)
✓ PROXMOX_PASSWORD gesetzt (Fallback)
✓ sshpass verfügbar (Fallback)

═══════════════════════════════════════════════════════
 3. Proxmox Verbindung
═══════════════════════════════════════════════════════

ℹ Teste SSH-Authentifizierung...
✓ SSH-Key-Authentifizierung erfolgreich (Primär)
✓ Passwort-Authentifizierung erfolgreich (Fallback)
✓ Proxmox Version: pve-manager/8.0.4/d258a813cfa6b390
✓ Root-Rechte verfügbar
```

## Konfiguration

### Empfohlene Konfiguration (Auto-Modus)

```bash
# proxmox/config/.env

PROXMOX_HOST=192.168.1.4
PROXMOX_USER=root
PROXMOX_PORT=22
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinRootPasswort
```

### Setup-Schritte

1. **SSH-Key einrichten** (Primäre Methode):
   ```bash
   ssh-keygen -t ed25519 -C "openclaw-deployment"
   ssh-copy-id root@192.168.1.4
   ```

2. **sshpass installieren** (Für Fallback):
   ```bash
   sudo apt install sshpass
   ```

3. **`.env` konfigurieren**:
   ```bash
   cd proxmox/config
   cp .env.example .env
   nano .env
   ```
   
   Setze:
   ```
   PROXMOX_AUTH_METHOD=auto
   PROXMOX_PASSWORD=DeinRootPasswort
   ```

4. **Validieren**:
   ```bash
   cd proxmox
   bash validate.sh
   ```

5. **Deployment starten**:
   ```bash
   bash deploy.sh
   ```

## Weitere Modi

Falls du Auto-Modus nicht nutzen möchtest:

### Nur SSH-Key (Höchste Sicherheit)

```bash
PROXMOX_AUTH_METHOD=key
# PROXMOX_PASSWORD=  # nicht erforderlich
```

**Vorteil:** Kein Passwort in Config-Datei  
**Nachteil:** Deployment schlägt bei Key-Problemen fehl

### Nur Passwort (Schnellster Setup)

```bash
PROXMOX_AUTH_METHOD=password
PROXMOX_PASSWORD=DeinRootPasswort
```

**Vorteil:** Kein SSH-Key-Setup erforderlich  
**Nachteil:** Passwort in Config-Datei, benötigt sshpass

## Sicherheitsaspekte

### Was ist sicher?

✅ **Auto-Modus bevorzugt SSH-Key**
- Passwort nur bei Key-Fehler verwendet
- SSH-Key-Authentifizierung wird immer zuerst versucht

✅ **`.env` ist geschützt**
- In `.gitignore` seit v1.0.0
- Wird niemals ins Git-Repository committet

✅ **Passwort nicht in Prozessliste**
- `sshpass -p` übergibt Passwort sicher
- Nicht in `ps aux` sichtbar

### Best Practices

1. **Nutze Auto-Modus in Produktion**
   - Beste Balance zwischen Sicherheit und Verfügbarkeit

2. **Schütze `.env` Datei**
   ```bash
   chmod 600 proxmox/config/.env
   ```

3. **Rotiere Passwörter regelmäßig**
   - Alle 90 Tage ändern
   - Nach Team-Wechseln

4. **Nutze starke Passwörter**
   - Mindestens 16 Zeichen
   - Keine Shell-Sonderzeichen (`$`, `'`, `"`, `\`)

5. **Teste beide Methoden**
   ```bash
   bash validate.sh  # Zeigt Status beider Methoden
   ```

## Troubleshooting

### Auto-Modus funktioniert nicht

**Problem:** Beide Authentifizierungsmethoden schlagen fehl

**Lösung:**

1. **Prüfe SSH-Key:**
   ```bash
   ssh root@192.168.1.4
   ```
   Falls Fehler: `ssh-copy-id root@192.168.1.4`

2. **Prüfe Passwort:**
   ```bash
   sshpass -p 'DeinPasswort' ssh root@192.168.1.4
   ```
   Falls Fehler: Passwort in `.env` prüfen

3. **Prüfe sshpass:**
   ```bash
   which sshpass
   ```
   Falls nicht installiert: `sudo apt install sshpass`

### Fallback wird nicht genutzt

**Symptom:** Deployment schlägt fehl obwohl Passwort gesetzt

**Prüfen:**

```bash
cd proxmox
bash validate.sh
```

**Mögliche Ursachen:**

1. `sshpass` nicht installiert:
   ```
   ⚠ sshpass nicht installiert (Fallback deaktiviert)
   ```
   Lösung: `sudo apt install sshpass`

2. `PROXMOX_PASSWORD` nicht gesetzt:
   ```
   ⚠ PROXMOX_PASSWORD nicht gesetzt (kein Fallback)
   ```
   Lösung: Passwort in `.env` eintragen

3. Falsches Passwort:
   ```
   ⚠ Passwort-Authentifizierung fehlgeschlagen
   ```
   Lösung: Passwort in `.env` korrigieren

## Migration

### Von Key-Only zu Auto-Modus

**Vorher (.env):**
```bash
PROXMOX_AUTH_METHOD=key
```

**Nachher (.env):**
```bash
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinRootPasswort  # Neu hinzufügen
```

Installiere sshpass:
```bash
sudo apt install sshpass
```

### Von Password-Only zu Auto-Modus

**Vorher (.env):**
```bash
PROXMOX_AUTH_METHOD=password
PROXMOX_PASSWORD=DeinRootPasswort
```

**Nachher (.env):**
```bash
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinRootPasswort  # Bleibt gleich
```

Richte SSH-Key ein:
```bash
ssh-keygen -t ed25519
ssh-copy-id root@192.168.1.4
```

**Ergebnis:** Deployment nutzt jetzt SSH-Key (schneller, sicherer), Passwort als Fallback

## Technische Details

### Implementierung in deploy.sh

```bash
ssh_exec() {
    local auth_method="$PROXMOX_AUTH_METHOD"

    # Auto-Modus: Versuche erst Key, dann Passwort
    if [[ "$auth_method" == "auto" ]]; then
        # Versuch 1: SSH-Key
        if ssh -o BatchMode=yes -o ConnectTimeout=5 \
            -p "${PROXMOX_PORT}" "${PROXMOX_USER}@${PROXMOX_HOST}" "$@" 2>/dev/null; then
            return 0  # Erfolg mit SSH-Key
        fi

        # Versuch 2: Passwort als Fallback
        if [[ -n "$PROXMOX_PASSWORD" ]] && command -v sshpass &> /dev/null; then
            sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no \
                -p "${PROXMOX_PORT}" "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
            return $?  # Exit-Code von sshpass
        fi

        return 1  # Beide Methoden fehlgeschlagen
    fi
    
    # ... Key-Only / Password-Only Modi ...
}
```

### Vorteile der Implementierung

- **Keine Latenz:** SSH-Key wird sofort versucht
- **Silent Fallback:** Passwort nur bei Key-Fehler
- **Exit-Codes:** Korrekte Fehlerbehandlung
- **Logging:** Klare Ausgaben für Debugging

## Zusammenfassung

**Auto-Modus bietet:**

✅ Maximale Zuverlässigkeit (Key + Password Fallback)  
✅ Best Practice Sicherheit (Key bevorzugt)  
✅ Zero-Downtime Deployment (automatischer Fallback)  
✅ Einfache Konfiguration (ein Setting für beide)  
✅ Ideal für Produktion und Entwicklung

**Empfehlung:**

```bash
PROXMOX_AUTH_METHOD=auto  # Default seit v1.1.0
PROXMOX_PASSWORD=...      # Als Fallback setzen
```

---

**Weitere Informationen:**
- [docs/SSH-AUTH.md](docs/SSH-AUTH.md) - Vollständige SSH-Authentifizierungs-Dokumentation
- [README.md](README.md) - Projekt-Übersicht
- [CHANGELOG-SSH-AUTH.md](CHANGELOG-SSH-AUTH.md) - Änderungshistorie
