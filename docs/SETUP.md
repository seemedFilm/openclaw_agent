# OpenClaw LXC Setup Anleitung

Diese Anleitung führt dich durch die vollständige Installation von OpenClaw auf einem Proxmox LXC-Container.

## 📋 Voraussetzungen

### Proxmox Host
- Proxmox VE 7.0 oder höher
- Mindestens 10 GB freier Speicher auf Storage
- SSH-Zugriff mit Root-Rechten
- Netzwerk-Bridge (standardmäßig `vmbr0`)

### Lokale Maschine
- SSH-Client (bereits auf deinem Windows mit bash vorhanden)
- SSH-Key-basierte Authentifizierung zu Proxmox
- Git (für Updates)

## 🔐 SSH-Zugriff einrichten

Falls noch nicht geschehen, richte SSH-Key-Authentifizierung ein:

```bash
# 1. SSH-Key generieren (falls noch nicht vorhanden)
ssh-keygen -t ed25519 -C "openclaw-deployment"

# 2. Public Key zu Proxmox kopieren
ssh-copy-id root@<PROXMOX-IP>

# 3. Teste Verbindung
ssh root@<PROXMOX-IP> "echo 'SSH erfolgreich'"
```

## 🚀 Installation

### Schritt 1: Umgebungsvariablen setzen

```bash
# Erforderlich
export PROXMOX_HOST="192.168.1.10"  # Deine Proxmox IP

# Optional (mit sinnvollen Defaults)
export PROXMOX_USER="root"          # Default: root
export PROXMOX_PORT="22"            # Default: 22
export LXC_ID="200"                 # Automatisch erhöht falls belegt
export LXC_HOSTNAME="openclaw-agents"
export LXC_CORES="4"
export LXC_MEMORY="8192"            # MB
export LXC_ROOTFS="40"              # GB
export LXC_NETWORK_IP="dhcp"        # oder z.B. "192.168.1.100/24"
```

### Schritt 2: Deployment starten

```bash
cd proxmox
bash deploy.sh
```

Das Script führt automatisch folgende Schritte aus:
1. ✅ Validiert SSH-Verbindung zu Proxmox
2. ✅ Prüft/lädt Ubuntu 24.04 LTS Template
3. ✅ Erstellt LXC-Container mit konfigurierten Ressourcen
4. ✅ Installiert alle Abhängigkeiten (Node.js, Docker, Tools)
5. ✅ Installiert OpenClaw
6. ✅ Richtet Verzeichnisstruktur ein
7. ✅ Speichert Container-Info

### Schritt 3: Container-Info prüfen

Nach erfolgreicher Installation:

```bash
cat proxmox/container-info.txt
```

Ausgabe:
```
CONTAINER_ID=200
CONTAINER_HOSTNAME=openclaw-agents
CONTAINER_IP=192.168.1.50
CREATED=2026-05-23T10:30:00+02:00
```

## 🔧 OpenClaw Konfiguration

### Schritt 4: In Container einloggen

```bash
# IP aus container-info.txt verwenden
ssh root@192.168.1.50
```

### Schritt 5: OpenClaw Onboarding

```bash
# Im Container
openclaw onboard
```

Folge den Anweisungen:
1. Wähle Chat-App (Discord/Slack/Telegram empfohlen für Multi-Agent)
2. Gib Claude API-Key ein
3. Konfiguriere weitere Integrationen (GitHub, etc.)

### Schritt 6: API-Keys konfigurieren

Erstelle Config-Datei:

```bash
# Im Container
mkdir -p ~/.openclaw
nano ~/.openclaw/config.json
```

Beispiel-Config:
```json
{
  "ai": {
    "provider": "anthropic",
    "model": "claude-sonnet-4-6",
    "apiKey": "sk-ant-..."
  },
  "github": {
    "token": "ghp_..."
  },
  "chat": {
    "platform": "discord",
    "token": "..."
  }
}
```

## 🤖 Agents einrichten

Die 4 Agents werden im nächsten Schritt konfiguriert:

```bash
# Auf lokaler Maschine
cd ../agents
# Folge AGENTS.md für Agent-Konfiguration
```

## 🔍 Troubleshooting

### Problem: SSH-Verbindung zu Proxmox schlägt fehl

```bash
# Teste manuelle Verbindung
ssh -v root@<PROXMOX-IP>

# Prüfe ob SSH-Agent läuft
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519
```

### Problem: Container startet nicht

```bash
# Auf Proxmox Host
pct status 200
pct start 200
pct enter 200  # Console-Zugriff
```

### Problem: OpenClaw Installation fehlgeschlagen

```bash
# Im Container
npm cache clean --force
npm install -g openclaw --verbose
```

### Problem: Netzwerk im Container nicht verfügbar

```bash
# Auf Proxmox Host
pct set 200 -net0 name=eth0,bridge=vmbr0,ip=dhcp
pct reboot 200
```

## 📊 Container-Verwaltung

### Container Status prüfen

```bash
# Auf Proxmox Host
pct status 200
pct list
```

### Container stoppen/starten

```bash
pct stop 200
pct start 200
pct reboot 200
```

### Container löschen (Vorsicht!)

```bash
pct stop 200
pct destroy 200
```

## 🔄 Updates

### OpenClaw updaten

```bash
# Im Container
npm update -g openclaw
openclaw --version
```

### System-Updates

```bash
# Im Container
apt update && apt upgrade -y
```

## 📈 Monitoring

### Container-Ressourcen

```bash
# Auf Proxmox Host
pct exec 200 -- htop
```

### Node Exporter (Prometheus)

Der Container exportiert Metriken auf Port 9100:
```bash
curl http://<CONTAINER-IP>:9100/metrics
```

## 🔐 Sicherheit

### Firewall-Status

```bash
# Im Container
ufw status verbose
```

### Offene Ports

```bash
# Im Container
ss -tulpn
```

### Docker-Security

```bash
# Im Container
docker ps
docker stats
```

## 📚 Weitere Ressourcen

- [OpenClaw Dokumentation](https://docs.openclaw.ai/)
- [Agent-Konfiguration](../agents/AGENTS.md)
- [Custom Skills](../skills/README.md)
- [Traefik Integration](../skills/traefik-manager/README.md)

## 🆘 Support

Bei Problemen:
1. Prüfe Logs: `journalctl -xe`
2. Prüfe OpenClaw Logs: `~/.openclaw/logs/`
3. GitHub Issues: [openclaw/openclaw](https://github.com/openclaw/openclaw/issues)
