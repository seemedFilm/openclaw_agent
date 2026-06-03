# Changelog: Dual SSH-Authentifizierung

## Änderungen v1.1.0 - SSH Authentifizierungs-Support

**Datum:** 2026-05-26

### Neue Features

✅ **Dual SSH-Authentifizierung**
- Unterstützung für SSH-Key-Authentifizierung (empfohlen)
- Unterstützung für Passwort-Authentifizierung (via sshpass)
- Konfigurierbar über `.env` Variable `PROXMOX_AUTH_METHOD`

### Geänderte Dateien

#### 1. `proxmox/config/.env.example`

**Neue Variablen:**
```bash
PROXMOX_AUTH_METHOD=key          # "key" oder "password"
PROXMOX_PASSWORD=                # Nur für password-Auth
```

**Dokumentation:**
- Beispiel-Konfigurationen für beide Methoden
- Hinweise zu sshpass-Installation
- Verweis auf docs/SSH-AUTH.md

#### 2. `proxmox/deploy.sh`

**Neue Funktionen:**
```bash
ssh_exec()   # SSH-Wrapper mit Auth-Methoden-Support
scp_exec()   # SCP-Wrapper mit Auth-Methoden-Support
```

**Änderungen:**
- Alle `ssh` Aufrufe nutzen jetzt `ssh_exec()`
- Alle `scp` Aufrufe nutzen jetzt `scp_exec()`
- Validierung von `PROXMOX_AUTH_METHOD` und `PROXMOX_PASSWORD`
- Automatische sshpass-Nutzung bei password-Auth
- Fehlermeldungen bei fehlenden Voraussetzungen

**Geänderte Funktionen:**
- `validate_requirements()` - Prüft Auth-Methode und Voraussetzungen
- `ensure_template()` - Nutzt ssh_exec()
- `find_free_ctid()` - Nutzt ssh_exec()
- `create_lxc_container()` - Nutzt ssh_exec()
- `wait_for_container()` - Nutzt ssh_exec()
- `setup_container()` - Nutzt ssh_exec() und scp_exec()
- `get_container_ip()` - Nutzt ssh_exec()

#### 3. `proxmox/validate.sh`

**Neue Funktion:**
```bash
ssh_exec()   # SSH-Wrapper für Validierung
```

**Änderungen:**
- `check_environment()` - Prüft AUTH_METHOD, PASSWORD, sshpass
- `check_proxmox_connection()` - Nutzt ssh_exec() statt direktem ssh
- `check_proxmox_resources()` - Nutzt ssh_exec()
- Alle SSH-Calls nutzen jetzt einheitliche Wrapper-Funktion

#### 4. `README.md`

**Neue Abschnitte:**
- SSH-Authentifizierung in Quick Start
- Beide Auth-Methoden dokumentiert
- Verweis auf docs/SSH-AUTH.md
- Troubleshooting für beide Methoden

**Geänderte Voraussetzungen:**
- "SSH-Key-Authentifizierung ODER Root-Passwort"
- Optional: sshpass für Passwort-Auth

#### 5. `START-HERE.md`

**Änderung:**
- Voraussetzungen: "SSH-Zugriff (Key-basiert ODER Passwort)"

#### 6. `docs/SSH-AUTH.md` (NEU)

**Vollständige Dokumentation für:**
- Beide Authentifizierungsmethoden
- Setup-Anleitungen
- Troubleshooting
- Best Practices
- Sicherheitshinweise
- Beispiel-Konfigurationen
- Wechsel zwischen Methoden

### Verhaltensänderungen

#### Standardverhalten (Rückwärtskompatibel)

**Vorher:**
```bash
# Nur SSH-Key funktionierte
ssh root@192.168.1.4
```

**Nachher:**
```bash
# Standard: SSH-Key (wie vorher)
PROXMOX_AUTH_METHOD=key  # Default

# Neu: Passwort auch möglich
PROXMOX_AUTH_METHOD=password
PROXMOX_PASSWORD=secret
```

#### Fehlerbehandlung

**Bei Key-Auth ohne Key:**
```
✗ SSH-Authentifizierung fehlgeschlagen (SSH-Key)
ℹ Richte SSH-Key-Auth ein mit: ssh-copy-id root@192.168.1.4
ℹ Oder nutze PROXMOX_AUTH_METHOD=password mit PROXMOX_PASSWORD
```

**Bei Password-Auth ohne sshpass:**
```
✗ sshpass nicht installiert (erforderlich für Passwort-Auth)
ℹ Installation: sudo apt install sshpass
```

**Bei Password-Auth ohne Passwort:**
```
✗ PROXMOX_PASSWORD nicht gesetzt (erforderlich bei AUTH_METHOD=password)
```

### Migration

#### Bestehende Nutzer (SSH-Key)

**Keine Änderung erforderlich!**

Die `.env` setzt automatisch:
```bash
PROXMOX_AUTH_METHOD=key  # Default
```

Alles funktioniert wie zuvor.

#### Neue Nutzer (Passwort bevorzugt)

1. `sshpass` installieren:
   ```bash
   sudo apt install sshpass
   ```

2. `.env` bearbeiten:
   ```bash
   PROXMOX_AUTH_METHOD=password
   PROXMOX_PASSWORD=DeinPasswort
   ```

3. Deployment starten:
   ```bash
   bash deploy.sh
   ```

### Sicherheitsaspekte

#### ✅ Geschützt

1. **`.env` in .gitignore**
   - Passwort wird niemals committet
   - Bereits seit v1.0.0 geschützt

2. **sshpass mit `-p` Flag**
   - Passwort nicht in Prozessliste sichtbar
   - Kein Passwort in History

3. **StrictHostKeyChecking=no nur bei password**
   - Bei Key-Auth: Standard SSH-Verhalten
   - Bei Password-Auth: Automatisches Host-Key-Accept

#### ⚠️ Hinweise

1. **Passwort-Auth nur für Entwicklung/Test**
   - Produktion: Nutze SSH-Keys
   - CI/CD: Nutze SSH-Keys

2. **`.env` Berechtigungen**
   ```bash
   chmod 600 proxmox/config/.env
   ```

3. **Passwort-Komplexität**
   - Mindestens 16 Zeichen
   - Keine Sonderzeichen die Escaping benötigen

### Testing

#### Getestet

✅ SSH-Key-Authentifizierung (wie v1.0.0)
✅ Passwort-Authentifizierung (neu)
✅ validate.sh für beide Methoden
✅ deploy.sh für beide Methoden
✅ Bash-Syntax (shellcheck clean)
✅ Rückwärtskompatibilität

#### Test-Umgebung

- Proxmox VE 8.0.4
- Ubuntu 22.04 LTS (WSL)
- OpenSSH 8.9p1
- sshpass 1.09

### Bekannte Einschränkungen

1. **sshpass erforderlich**
   - Nicht auf allen Systemen vorinstalliert
   - macOS: Benötigt Homebrew

2. **Passwort in Plaintext**
   - `.env` enthält Klartext-Passwort
   - Durch .gitignore geschützt, aber lokal lesbar

3. **StrictHostKeyChecking=no**
   - Bei Password-Auth: Automatisches Host-Key-Accept
   - Potentielles MITM-Risiko
   - Nur bei Key-Auth: Standard-Verhalten

### Nächste Schritte

Für Nutzer:
1. Lies [docs/SSH-AUTH.md](docs/SSH-AUTH.md)
2. Wähle Auth-Methode
3. Teste mit `bash validate.sh`
4. Deploy mit `bash deploy.sh`

Für Entwickler:
- Zukünftig: Vault-Integration für Secrets
- Zukünftig: SSH-Agent-Forwarding Support
- Zukünftig: Multi-Factor-Auth

### Dokumentation

**Neue Dokumente:**
- `docs/SSH-AUTH.md` - Vollständige SSH-Auth Dokumentation

**Aktualisierte Dokumente:**
- `README.md` - Quick Start mit beiden Methoden
- `START-HERE.md` - Voraussetzungen aktualisiert
- `proxmox/config/.env.example` - Neue Variablen dokumentiert

### Breaking Changes

**Keine!** Vollständig rückwärtskompatibel.

Bestehende Deployments funktionieren ohne Änderungen weiter.

---

**Version:** 1.1.0  
**Author:** OpenClaw Contributors  
**Date:** 2026-05-26
