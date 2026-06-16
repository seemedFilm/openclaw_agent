# Changelog - Cert-Manager

## [v1.2.0] - 2026-06-15

### Verbesserte Traefik-Integration für interne Services

**Hauptänderung: Automatische Traefik-Konfiguration bei step-ca**

Wenn ein **step-ca Zertifikat** (für interne Services) mit einer **Backend-IP** erstellt wird, erfolgt die Traefik-Integration nun vollautomatisch ohne zusätzliche Checkbox.

#### Neue Features

1. **Intelligente Formular-UX**
   - Backend-IP Feld wird bei step-ca Auswahl visuell hervorgehoben (blauer Rahmen, Hintergrund)
   - Dynamisches Label: "(empfohlen für Traefik-Integration)" bei step-ca
   - Erweiterter Hilfetext erklärt automatisches Verhalten
   - Bei Let's Encrypt bleibt Backend-IP optional ohne Hervorhebung

2. **Automatische Traefik-Integration**
   - Checkbox "Traefik-Konfiguration erstellen" entfernt (nicht mehr nötig)
   - System erkennt automatisch: `step-ca + Backend-IP → Traefik-Integration`
   - Ein Schritt weniger für den Benutzer

3. **Verbessertes Error-Handling**
   - Zertifikat wird erstellt, auch wenn Traefik-Integration fehlschlägt
   - Neue Warnung zeigt partielle Erfolge mit Details
   - Info-Box informiert über Möglichkeit zur manuellen Nachholung
   - Erweitertes Audit-Logging für "warning" Status

4. **Neue Alert-Styles**
   - `.alert-warning`: Gelbe Warnung für nicht-kritische Probleme
   - `.alert-info`: Blaue Info-Box für zusätzliche Hinweise
   - `.alert-success`: Grüne Success-Meldungen
   - Konsistente Border-Left Gestaltung

#### Geänderte Dateien

**Frontend:**
- `web/templates/new_certificate.html`: Formular-Optimierung, JavaScript für dynamische UX
- `web/static/css/style.css`: Neue Alert-Styles

**Backend:**
- `web/app.py`: Automatische `create_traefik_config` Aktivierung, partielle Erfolg-Behandlung
- `lib/certificate_manager.py`: Try-Catch für Traefik-Integration, erweiterte Rückgabewerte

#### Workflow Beispiel

**Vorher (v1.1.0):**
```
1. Hostname eingeben: "myapp.internal"
2. Typ wählen: "step-ca"
3. Backend-IP eingeben: "https://192.168.1.50:8080"
4. ✓ Traefik-Konfiguration erstellen (Checkbox aktivieren)
5. Erstellen
```

**Jetzt (v1.2.0):**
```
1. Hostname eingeben: "myapp.internal"
2. Typ wählen: "step-ca" 
   → Backend-IP Feld wird automatisch hervorgehoben
3. Backend-IP eingeben: "https://192.168.1.50:8080"
   → Traefik-Integration erfolgt automatisch
4. Erstellen
```

#### Vorteile

- **Weniger Klicks**: Checkbox entfernt, automatisches Verhalten
- **Klarere UX**: Visuelle Hinweise zeigen was wichtig ist
- **Robuster**: Zertifikat wird nicht gelöscht wenn nur Traefik fehlschlägt
- **Transparenter**: Besseres Feedback bei partiellen Erfolgen

#### Migration

Keine Breaking Changes. Bestehende Zertifikate unverändert.

---

## [v1.1.0] - 2026-06-12

### Neue Features

#### Backend-IP für Traefik Integration
- **Backend-IP Feld hinzugefügt**: Zertifikate können jetzt mit einer Backend-IP-Adresse verknüpft werden
  - Optionales Feld beim Erstellen eines Zertifikats
  - Format: `https://192.168.1.50:8080` oder `http://192.168.1.51:3000`
  - Wird in der Datenbank gespeichert und in der Zertifikatsübersicht angezeigt

#### Automatische Traefik-Konfiguration
- **Integration mit traefik-service-manager**: 
  - Neue Checkbox "Traefik-Konfiguration automatisch erstellen" im Web-UI
  - API-Parameter `create_traefik_config: bool`
  - Ruft automatisch `traefik-service-manager.sh` auf
  - Erstellt vollständige Traefik-Service-Konfiguration in einem Schritt

### Geänderte Dateien

#### Datenbank
- **api/init_db.py**: 
  - `backend_ip TEXT` Spalte zu `certificates` Tabelle hinzugefügt
  - Migration für bestehende Datenbanken implementiert

#### Backend
- **lib/certificate_manager.py**:
  - `create_certificate()`: Neue Parameter `backend_ip` und `create_traefik_config`
  - `_create_step_ca_cert()`: Backend-IP in DB speichern
  - `_create_letsencrypt_cert()`: Backend-IP in DB speichern
  - `_create_traefik_service()`: Neue Methode für Traefik-Integration
  - `list_certificates()`: Backend-IP im Response enthalten
  - `get_certificate()`: Backend-IP im Response enthalten

#### API
- **api/main.py**:
  - `CreateCertificateRequest`: Neue Felder `backend_ip` und `create_traefik_config`
  - `/api/certs` POST: Validierung und Verarbeitung der neuen Parameter

#### Web-UI
- **web/app.py**:
  - `/certificates/new` POST: Backend-IP und Traefik-Checkbox-Handling
  - Validierung: Backend-IP erforderlich wenn Traefik-Config gewünscht
  
- **web/templates/new_certificate.html**:
  - Neues Eingabefeld für Backend-IP mit Validierung
  - Neue Checkbox "Traefik-Konfiguration automatisch erstellen"
  - JavaScript-Validierung für korrekte Nutzung
  
- **web/templates/certificates.html**:
  - Neue Spalte "Backend-IP" in der Zertifikatsübersicht
  - Anzeige der Backend-IP als Code-Block oder "-" wenn nicht vorhanden

#### Dokumentation
- **README.md**:
  - API-Beispiele mit Backend-IP erweitert
  - Datenbank-Schema aktualisiert
  - Workflow-Beschreibungen angepasst

### Verwendung

#### Web-UI
```
1. Neues Zertifikat erstellen
2. Hostname eingeben: z.B. "myapp.internal"
3. Backend-IP eingeben: z.B. "https://192.168.1.50:8080"
4. Optional: "Traefik-Konfiguration automatisch erstellen" aktivieren
5. Erstellen klicken
→ Zertifikat wird erstellt UND Traefik-Service wird automatisch konfiguriert
```

#### API
```bash
curl -X POST http://localhost:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{
    "hostname": "myapp.internal",
    "type": "step-ca",
    "backend_ip": "https://192.168.1.50:8080",
    "auto_renew": true,
    "create_traefik_config": true
  }'
```

### Vorteile

1. **Single-Click-Deployment**: Ein Klick erstellt Zertifikat + Traefik-Config
2. **Nachvollziehbarkeit**: Backend-IP wird in DB gespeichert und ist sichtbar
3. **Audit-Trail**: Traefik-Konfigurationserstellung wird im Audit-Log erfasst
4. **Flexibilität**: Backend-IP ist optional, bestehende Workflows funktionieren weiterhin

### Migration

Für bestehende Installationen:
```bash
cd /opt/openclaw/skills/cert-manager
python3 api/init_db.py  # Führt automatisch Migration aus
systemctl restart cert-manager-api cert-manager-web
```

### Breaking Changes

Keine - alle neuen Features sind optional und abwärtskompatibel.

---

## [v1.0.0] - 2026-06-08

### Initial Release
- Zertifikatsverwaltung für step-ca und Let's Encrypt
- Web-Interface (Port 5000)
- REST API (Port 5001)
- Automatisches Renewal
- Audit-Logging
- OpenClaw Integration
