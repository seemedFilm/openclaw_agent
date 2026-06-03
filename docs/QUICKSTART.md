# 🚀 OpenClaw LXC Quick Start

Die schnellste Methode, um OpenClaw auf Proxmox zum Laufen zu bringen.

## ⚡ 3-Minuten-Setup

### 1. Proxmox-IP setzen

```bash
export PROXMOX_HOST="192.168.1.10"  # Deine Proxmox IP hier eintragen
```

### 2. Deployment starten

```bash
cd proxmox
bash deploy.sh
```

### 3. Container-IP notieren

```bash
cat proxmox/container-info.txt
```

Beispiel-Ausgabe:
```
CONTAINER_ID=200
CONTAINER_HOSTNAME=openclaw-agents
CONTAINER_IP=192.168.1.50
```

### 4. In Container einloggen

```bash
ssh root@192.168.1.50  # IP aus Schritt 3
```

### 5. OpenClaw initialisieren

```bash
openclaw onboard
```

**Fertig!** 🎉 OpenClaw läuft jetzt in deinem LXC-Container.

## 🔑 API-Keys konfigurieren

### Claude API Key

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Oder dauerhaft in `~/.bashrc`:
```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
```

### GitHub Token (für Review-Agent)

```bash
gh auth login
```

## 📊 Nächste Schritte

### Agents einrichten

Die 4 spezialisierten Agents konfigurieren:

```bash
# Auf lokaler Maschine (nicht im Container)
cd ../agents
# Folge der Anleitung in agents/README.md
```

### Ersten Agent testen

```bash
# Im Container
openclaw chat "Hallo, ich bin der Dev-Agent"
```

### Systemd Service aktivieren

```bash
# Im Container
systemctl enable openclaw-agent@dev
systemctl start openclaw-agent@dev
systemctl status openclaw-agent@dev
```

## 🔍 Wichtige Befehle

```bash
# OpenClaw Version
openclaw --version

# Hilfe anzeigen
openclaw --help

# Status aller Agents
systemctl list-units "openclaw-agent@*"

# Logs ansehen
journalctl -u openclaw-agent@dev -f

# Container-Ressourcen prüfen
htop
```

## 🆘 Probleme?

Siehe [SETUP.md](SETUP.md) für ausführliche Troubleshooting-Anleitung.

**Häufigste Fehler:**
- ❌ SSH-Verbindung schlägt fehl → Prüfe SSH-Keys: `ssh-copy-id root@PROXMOX_IP`
- ❌ Template nicht gefunden → Script lädt es automatisch herunter (dauert ~2 Min)
- ❌ Container-ID belegt → Script wählt automatisch nächste freie ID
