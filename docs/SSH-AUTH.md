# SSH-Authentifizierung für Proxmox-Deployment

Dieses Dokument erklärt die verfügbaren Authentifizierungsmethoden für die SSH-Verbindung zum Proxmox-Host.

## Übersicht

Die Deployment-Scripts unterstützen drei Authentifizierungsmodi:

1. **Auto-Modus** (empfohlen) - SSH-Key mit Passwort-Fallback
2. **SSH-Key-Only** - Nur SSH-Key (höchste Sicherheit)
3. **Passwort-Only** - Nur Passwort (schnellster Setup)

## Methode 1: Auto-Modus (Empfohlen)

### Beschreibung
Der Auto-Modus versucht zuerst die SSH-Key-Authentifizierung. Falls diese fehlschlägt (Key nicht konfiguriert, falsche Berechtigung, etc.), wird automatisch auf Passwort-Authentifizierung zurückgegriffen.

### Vorteile
- ✅ **Beste Zuverlässigkeit** - Funktioniert immer
- ✅ **Fallback-Sicherheit** - SSH-Key-Probleme werden automatisch umgangen
- ✅ **Flexibilität** - Ideal für verschiedene Umgebungen
- ✅ **Zero-Downtime** - Deployment funktioniert auch wenn Key-Setup fehlschlägt

### Nachteile
- ⚠️ Passwort muss in `.env` gespeichert werden
- ⚠️ Benötigt `sshpass` für Fallback

### Einrichtung

#### 1. SSH-Key generieren und kopieren (Primär)

```bash
# Ed25519 Key (modern, empfohlen)
ssh-keygen -t ed25519 -C "openclaw-deployment"

# Public Key zum Proxmox Host kopieren
ssh-copy-id root@192.168.1.4
```

#### 2. Passwort als Fallback (Optional aber empfohlen)

```bash
# sshpass installieren
sudo apt install sshpass
```

#### 3. Konfiguration

In `proxmox/config/.env`:

```bash
PROXMOX_HOST=192.168.1.4
PROXMOX_USER=root
PROXMOX_PORT=22
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinRootPasswort  # Als Fallback
```

#### 4. Testen

```bash
cd proxmox
bash validate.sh
```

**Erwartete Ausgabe (beide Methoden funktionieren):**
```
ℹ PROXMOX_AUTH_METHOD: auto (SSH-Key mit Passwort-Fallback)
✓ SSH-Key verfügbar (Primär)
✓ PROXMOX_PASSWORD gesetzt (Fallback)
✓ sshpass verfügbar (Fallback)

ℹ Teste SSH-Authentifizierung...
✓ SSH-Key-Authentifizierung erfolgreich (Primär)
✓ Passwort-Authentifizierung erfolgreich (Fallback)
```

**Erwartete Ausgabe (nur SSH-Key funktioniert):**
```
ℹ PROXMOX_AUTH_METHOD: auto (SSH-Key mit Passwort-Fallback)
✓ SSH-Key verfügbar (Primär)
⚠ PROXMOX_PASSWORD nicht gesetzt (kein Fallback)

ℹ Teste SSH-Authentifizierung...
✓ SSH-Key-Authentifizierung erfolgreich (Primär)
```

**Erwartete Ausgabe (nur Passwort funktioniert):**
```
ℹ PROXMOX_AUTH_METHOD: auto (SSH-Key mit Passwort-Fallback)
⚠ SSH-Key nicht verfügbar
✓ PROXMOX_PASSWORD gesetzt (Fallback)
✓ sshpass verfügbar (Fallback)

ℹ Teste SSH-Authentifizierung...
⚠ SSH-Key-Authentifizierung fehlgeschlagen
✓ Passwort-Authentifizierung erfolgreich (Fallback)
```

## Methode 2: SSH-Key-Only (Höchste Sicherheit)

### Vorteile
- ✅ Höchste Sicherheit
- ✅ Keine Passwörter in Konfigurationsdateien
- ✅ Standardmethode für Produktion
- ✅ Keine zusätzlichen Tools erforderlich

### Nachteile
- ⚠️ Key muss korrekt konfiguriert sein
- ⚠️ Keine Fallback-Option

### Einrichtung

#### 1. SSH-Key generieren (falls nicht vorhanden)

```bash
# Ed25519 Key (modern, empfohlen)
ssh-keygen -t ed25519 -C "openclaw-deployment"

# Oder RSA Key (kompatibel)
ssh-keygen -t rsa -b 4096 -C "openclaw-deployment"
```

**Speicherort:** Drücke Enter für Standard `~/.ssh/id_ed25519` bzw. `~/.ssh/id_rsa`

#### 2. Public Key zum Proxmox-Host kopieren

```bash
ssh-copy-id root@192.168.1.4
```

Oder manuell:

```bash
# Public Key anzeigen
cat ~/.ssh/id_ed25519.pub

# Auf Proxmox Host: Public Key zu authorized_keys hinzufügen
# SSH in Proxmox: ssh root@192.168.1.4
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "DEIN_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 3. Konfiguration

In `proxmox/config/.env`:

```bash
PROXMOX_HOST=192.168.1.4
PROXMOX_USER=root
PROXMOX_PORT=22
PROXMOX_AUTH_METHOD=key
```

#### 4. Testen

```bash
# Sollte ohne Passwort-Eingabe funktionieren
ssh root@192.168.1.4

# Validierungs-Script ausführen
cd proxmox
bash validate.sh
```

## Methode 3: Passwort-Only

### Vorteile
- ✅ Einfache Einrichtung
- ✅ Kein Key-Management erforderlich
- ✅ Funktioniert sofort

### Nachteile
- ⚠️ Passwort in `.env` Datei (muss geschützt werden!)
- ⚠️ Erfordert zusätzliches Tool (`sshpass`)
- ⚠️ Weniger sicher als Key-Auth

### Einrichtung

#### 1. sshpass installieren

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install sshpass
```

**Windows (WSL):**
```bash
sudo apt update
sudo apt install sshpass
```

**macOS:**
```bash
brew install hudochenkov/sshpass/sshpass
```

#### 2. Konfiguration

In `proxmox/config/.env`:

```bash
PROXMOX_HOST=192.168.1.4
PROXMOX_USER=root
PROXMOX_PORT=22
PROXMOX_AUTH_METHOD=password
PROXMOX_PASSWORD=DeinRootPasswort
```

**⚠️ WICHTIG:** Die `.env` Datei ist in `.gitignore` und wird niemals committet!

#### 3. Berechtigungen setzen (Linux/macOS)

```bash
chmod 600 proxmox/config/.env
```

#### 4. Testen

```bash
cd proxmox
bash validate.sh
```

## Validierung

### Erfolgreiche Key-Authentifizierung

```
═══════════════════════════════════════════════════════
 2. Umgebungsvariablen
═══════════════════════════════════════════════════════

✓ .env Datei gefunden
✓ PROXMOX_HOST gesetzt: 192.168.1.4
ℹ PROXMOX_USER: root
ℹ PROXMOX_PORT: 22
ℹ PROXMOX_AUTH_METHOD: key (SSH-Key-Authentifizierung)

═══════════════════════════════════════════════════════
 3. Proxmox Verbindung
═══════════════════════════════════════════════════════

ℹ Teste SSH-Authentifizierung...
✓ SSH-Authentifizierung erfolgreich (SSH-Key)
✓ Proxmox Version: pve-manager/8.0.4/d258a813cfa6b390
✓ Root-Rechte verfügbar
```

### Erfolgreiche Passwort-Authentifizierung

```
═══════════════════════════════════════════════════════
 2. Umgebungsvariablen
═══════════════════════════════════════════════════════

✓ .env Datei gefunden
✓ PROXMOX_HOST gesetzt: 192.168.1.4
ℹ PROXMOX_USER: root
ℹ PROXMOX_PORT: 22
ℹ PROXMOX_AUTH_METHOD: password
✓ PROXMOX_PASSWORD gesetzt
✓ sshpass verfügbar

═══════════════════════════════════════════════════════
 3. Proxmox Verbindung
═══════════════════════════════════════════════════════

ℹ Teste SSH-Authentifizierung...
✓ SSH-Authentifizierung erfolgreich (Passwort)
✓ Proxmox Version: pve-manager/8.0.4/d258a813cfa6b390
✓ Root-Rechte verfügbar
```

## Troubleshooting

### SSH-Key-Authentifizierung schlägt fehl

**Symptom:**
```
✗ SSH-Authentifizierung fehlgeschlagen (SSH-Key)
ℹ Richte SSH-Key-Auth ein mit: ssh-copy-id root@192.168.1.4
```

**Lösungen:**

1. **Key noch nicht kopiert:**
   ```bash
   ssh-copy-id root@192.168.1.4
   ```

2. **Falscher Key verwendet:**
   ```bash
   # Prüfe welche Keys geladen sind
   ssh-add -l
   
   # Key explizit angeben
   ssh -i ~/.ssh/id_ed25519 root@192.168.1.4
   ```

3. **Berechtigungen falsch:**
   ```bash
   # Auf Proxmox Host
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

4. **SSH-Agent Problem:**
   ```bash
   # SSH-Agent starten
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

### Passwort-Authentifizierung schlägt fehl

**Symptom:**
```
✗ sshpass nicht installiert (erforderlich für Passwort-Auth)
ℹ Installation: sudo apt install sshpass
```

**Lösung:**
```bash
sudo apt install sshpass
```

**Symptom:**
```
✗ PROXMOX_PASSWORD nicht gesetzt (erforderlich bei AUTH_METHOD=password)
```

**Lösung:** Setze `PROXMOX_PASSWORD` in `proxmox/config/.env`

**Symptom:**
```
✗ SSH-Authentifizierung fehlgeschlagen (Passwort)
ℹ Prüfe PROXMOX_PASSWORD in .env
```

**Lösungen:**

1. **Passwort falsch:**
   - Prüfe das Passwort in `.env`
   - Teste manuell: `ssh root@192.168.1.4`

2. **SSH-Konfiguration blockiert Passwort-Auth:**
   ```bash
   # Auf Proxmox Host: /etc/ssh/sshd_config prüfen
   sudo grep "^PasswordAuthentication" /etc/ssh/sshd_config
   
   # Falls "no", ändern zu "yes"
   sudo nano /etc/ssh/sshd_config
   # PasswordAuthentication yes
   
   sudo systemctl restart sshd
   ```

3. **Sonderzeichen im Passwort:**
   - Verwende einfache Passwörter ohne `'`, `"`, `$`, `\`
   - Oder escape Sonderzeichen korrekt

### Beide Methoden schlagen fehl

**Symptom:**
```
✗ Proxmox Host 192.168.1.4 antwortet nicht auf Ping
✗ SSH-Port 22 TCP-Check fehlgeschlagen
```

**Lösungen:**

1. **IP-Adresse prüfen:**
   ```bash
   ping 192.168.1.4
   ```

2. **Proxmox läuft nicht / falsche IP:**
   - Prüfe IP in Proxmox-Konsole
   - Prüfe Netzwerk-Konfiguration

3. **Firewall blockiert:**
   ```bash
   # Auf Proxmox Host
   iptables -L INPUT -v -n | grep 22
   ```

4. **SSH-Service läuft nicht:**
   ```bash
   # Auf Proxmox Host
   systemctl status sshd
   systemctl status ssh
   ```

## Wechsel zwischen Modi

### Zu Auto-Modus (Empfohlen)

In `proxmox/config/.env`:

```bash
PROXMOX_AUTH_METHOD=auto
PROXMOX_PASSWORD=DeinPasswort  # Als Fallback
```

SSH-Key einrichten (falls nicht vorhanden):
```bash
ssh-keygen -t ed25519
ssh-copy-id root@192.168.1.4
```

### Von Auto zu Key-Only

In `proxmox/config/.env`:

```bash
# Ändere
PROXMOX_AUTH_METHOD=auto

# Zu
PROXMOX_AUTH_METHOD=key
# PROXMOX_PASSWORD=  # Kann bleiben (wird ignoriert)
```

### Von Auto zu Password-Only

In `proxmox/config/.env`:

```bash
# Ändere
PROXMOX_AUTH_METHOD=auto

# Zu
PROXMOX_AUTH_METHOD=password
PROXMOX_PASSWORD=DeinPasswort  # Erforderlich
```

## Best Practices

### Sicherheit

1. **Nutze SSH-Key-Authentifizierung** wo möglich
2. **Schütze `.env` Datei:**
   ```bash
   chmod 600 proxmox/config/.env
   ```
3. **Niemals `.env` committen** (ist bereits in `.gitignore`)
4. **Rotiere Passwörter regelmäßig** (bei Passwort-Auth)
5. **Nutze starke Passwörter** (mindestens 16 Zeichen)

### Deployment-Umgebungen

**Entwicklung / Test:**
- Passwort-Auth ist akzeptabel
- Schnelle Einrichtung

**Produktion:**
- **NUR SSH-Key-Authentifizierung**
- Keine Passwörter in Dateien
- Verwende SSH-Agent Forwarding

### CI/CD

Für automatisierte Deployments:

```bash
# GitHub Actions / GitLab CI
# Setze SSH_PRIVATE_KEY als Secret
# Lade Key temporär

echo "$SSH_PRIVATE_KEY" > /tmp/deploy_key
chmod 600 /tmp/deploy_key
ssh-add /tmp/deploy_key

# Deployment
cd proxmox
PROXMOX_AUTH_METHOD=key bash deploy.sh

# Cleanup
rm /tmp/deploy_key
```

## Zusammenfassung

| Modus | Sicherheit | Setup | Zuverlässigkeit | Fallback | Empfohlen für |
|-------|-----------|-------|-----------------|----------|---------------|
| **Auto** | ✅ Hoch | ⚠️ Mittel | ✅✅✅ Perfekt | ✅ Ja | **Alle Szenarien** |
| **Key-Only** | ✅✅ Sehr hoch | ⚠️ Aufwändig | ⚠️ Anfällig | ❌ Nein | Produktion mit stabiler Infrastruktur |
| **Password-Only** | ⚠️ Mittel | ✅ Einfach | ✅ Gut | ❌ Nein | Schnelle Tests, Entwicklung |

**Empfehlung:** 
- **Auto-Modus** für alle Produktions- und Entwicklungsumgebungen
- Beste Zuverlässigkeit durch Fallback
- SSH-Key wird bevorzugt verwendet (Sicherheit)
- Passwort greift nur bei Key-Problemen (Verfügbarkeit)

---

**Weitere Dokumentation:**
- [DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md) - Vollständige Deployment-Anleitung
- [START-HERE.md](../START-HERE.md) - Schnelleinstieg
- [SETUP.md](SETUP.md) - Detaillierte Installations-Dokumentation
