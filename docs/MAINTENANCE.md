# 🛠️ Maintenance Guide

Wartung, Updates und Backup-Strategien für das OpenClaw Multi-Agent-System.

---

## 📅 Regelmäßige Wartung

### Täglich

**Health Checks:**
```bash
ssh root@192.168.1.11

# System Health
openclaw health

# Gateway Status
systemctl status openclaw-gateway

# LiteLLM Status
systemctl status litellm-proxy

# Disk Space
df -h /

# Memory Usage
free -h
```

**Expected Output:**
- Gateway: active (running)
- LiteLLM: active (running)
- Health: All agents available
- Disk: < 70% usage
- Memory: < 80% usage

### Wöchentlich

**Log Review:**
```bash
# Gateway Errors (letzte Woche)
journalctl -u openclaw-gateway --since "7 days ago" | grep -i error | tail -50

# LiteLLM Errors
journalctl -u litellm-proxy --since "7 days ago" | grep -i error | tail -50

# Failed Agent Requests
journalctl -u openclaw-gateway --since "7 days ago" | grep "failed before reply"
```

**Config Backup:**
```bash
# OpenClaw Config
cp ~/.openclaw/openclaw.json ~/.openclaw/backups/openclaw-$(date +%Y%m%d).json

# LiteLLM Config
cp /opt/openclaw/config/litellm-config.yaml /opt/openclaw/config/backups/litellm-$(date +%Y%m%d).yaml
```

### Monatlich

**Updates:**
```bash
# System Updates
apt update && apt upgrade -y

# OpenClaw Update
openclaw update

# LiteLLM Update
/opt/openclaw/venv/bin/pip install --upgrade litellm

# Node.js (falls nötig)
n latest

# Restart Services
systemctl restart openclaw-gateway litellm-proxy
```

**Cleanup:**
```bash
# Alte Logs (älter als 30 Tage)
journalctl --vacuum-time=30d

# Alte Backups (älter als 90 Tage)
find ~/.openclaw/backups -name "openclaw-*.json" -mtime +90 -delete

# Npm Cache (in Workspaces)
cd /opt/openclaw/workspaces/dev-agent && npm cache clean --force
```

---

## 🔄 Update-Prozeduren

### OpenClaw Update

**Vorbereitung:**
```bash
# Backup erstellen
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.pre-update

# Aktuellen Status notieren
openclaw --version
openclaw agents list > ~/agents-pre-update.txt
```

**Update durchführen:**
```bash
# Update
openclaw update

# Oder manuell via npm
npm update -g @anthropic-ai/openclaw

# Verify
openclaw --version
```

**Post-Update:**
```bash
# Gateway neu starten
systemctl restart openclaw-gateway

# Health Check
openclaw health

# Agents prüfen
openclaw agents list
diff ~/agents-pre-update.txt <(openclaw agents list)
```

**Rollback (falls nötig):**
```bash
# Config wiederherstellen
cp ~/.openclaw/openclaw.json.pre-update ~/.openclaw/openclaw.json

# Ältere Version installieren
npm install -g @anthropic-ai/openclaw@<version>

# Gateway neu starten
systemctl restart openclaw-gateway
```

### LiteLLM Update

**Vorbereitung:**
```bash
# Backup
cp /opt/openclaw/config/litellm-config.yaml /opt/openclaw/config/litellm-config.yaml.backup

# Aktuelle Version
/opt/openclaw/venv/bin/litellm --version
```

**Update:**
```bash
# Update via pip
/opt/openclaw/venv/bin/pip install --upgrade litellm

# Verify
/opt/openclaw/venv/bin/litellm --version
```

**Post-Update:**
```bash
# Service neu starten
systemctl restart litellm-proxy

# Health Check
curl http://localhost:4000/health

# Test API Call
curl -s -X POST http://localhost:4000/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "claude-sonnet-4-6", "messages": [{"role": "user", "content": "OK"}], "max_tokens": 5}'
```

### System Updates (Ubuntu)

```bash
# Updates prüfen
apt update
apt list --upgradable

# Upgrade
apt upgrade -y

# Falls Kernel-Update:
reboot

# Nach Reboot: Services prüfen
systemctl status openclaw-gateway litellm-proxy
```

---

## 💾 Backup-Strategie

### Kritische Dateien

**OpenClaw Config:**
- `~/.openclaw/openclaw.json`
- `~/.openclaw/devices/paired.json`
- `~/.openclaw/agents/*/agent/.claude.md`

**LiteLLM Config:**
- `/opt/openclaw/config/litellm-config.yaml`
- `/opt/openclaw/config/litellm.env`

**Systemd Services:**
- `/etc/systemd/system/openclaw-gateway.service`
- `/etc/systemd/system/litellm-proxy.service`

### Backup-Script

```bash
#!/bin/bash
# backup-openclaw.sh

BACKUP_DIR="/opt/openclaw/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# OpenClaw Config
cp ~/.openclaw/openclaw.json "$BACKUP_DIR/"
cp ~/.openclaw/devices/paired.json "$BACKUP_DIR/"

# Agent Bootstrap Files
mkdir -p "$BACKUP_DIR/agents"
for agent in dev-agent review-agent security-agent ops-agent; do
  if [ -f ~/.openclaw/agents/$agent/agent/.claude.md ]; then
    cp ~/.openclaw/agents/$agent/agent/.claude.md "$BACKUP_DIR/agents/$agent.claude.md"
  fi
done

# LiteLLM Config
cp /opt/openclaw/config/litellm-config.yaml "$BACKUP_DIR/"
cp /opt/openclaw/config/litellm.env "$BACKUP_DIR/"

# Systemd Services
cp /etc/systemd/system/openclaw-gateway.service "$BACKUP_DIR/"
cp /etc/systemd/system/litellm-proxy.service "$BACKUP_DIR/"

# Create tarball
cd /opt/openclaw/backups
tar -czf "openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"

echo "Backup created: openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

# Alte Backups löschen (älter als 30 Tage)
find /opt/openclaw/backups -name "openclaw-backup-*.tar.gz" -mtime +30 -delete
```

**Ausführbar machen und testen:**
```bash
chmod +x /opt/openclaw/backup-openclaw.sh
/opt/openclaw/backup-openclaw.sh
```

**Cronjob für tägliche Backups:**
```bash
# Crontab editieren
crontab -e

# Täglich um 3 Uhr
0 3 * * * /opt/openclaw/backup-openclaw.sh >> /var/log/openclaw-backup.log 2>&1
```

### Restore-Prozedur

```bash
# Backup extrahieren
cd /opt/openclaw/backups
tar -xzf openclaw-backup-YYYYMMDD-HHMMSS.tar.gz

# Config wiederherstellen
cp YYYYMMDD-HHMMSS/openclaw.json ~/.openclaw/
cp YYYYMMDD-HHMMSS/paired.json ~/.openclaw/devices/

# Agent Bootstrap Files
for agent in dev-agent review-agent security-agent ops-agent; do
  cp YYYYMMDD-HHMMSS/agents/$agent.claude.md ~/.openclaw/agents/$agent/agent/.claude.md
done

# LiteLLM Config
cp YYYYMMDD-HHMMSS/litellm-config.yaml /opt/openclaw/config/
cp YYYYMMDD-HHMMSS/litellm.env /opt/openclaw/config/

# Services wiederherstellen
cp YYYYMMDD-HHMMSS/openclaw-gateway.service /etc/systemd/system/
cp YYYYMMDD-HHMMSS/litellm-proxy.service /etc/systemd/system/

# Reload + Restart
systemctl daemon-reload
systemctl restart openclaw-gateway litellm-proxy

# Verify
openclaw health
```

---

## 📊 Monitoring

### Performance Metrics

**Gateway Performance:**
```bash
# Response Time Monitoring
journalctl -u openclaw-gateway --since "1 hour ago" | grep "res ✓" | tail -20

# Average Response Time
journalctl -u openclaw-gateway --since "1 day ago" | grep -oP 'res ✓ \S+ \K\d+ms' | awk '{sum+=$1; n++} END {print sum/n "ms avg"}'
```

**LiteLLM Metrics:**
```bash
# Request Count
journalctl -u litellm-proxy --since "1 day ago" | grep "POST /chat/completions" | wc -l

# Error Rate
ERROR_COUNT=$(journalctl -u litellm-proxy --since "1 day ago" | grep -i error | wc -l)
TOTAL_COUNT=$(journalctl -u litellm-proxy --since "1 day ago" | wc -l)
echo "Error Rate: $(echo "scale=2; $ERROR_COUNT/$TOTAL_COUNT*100" | bc)%"
```

**System Resources:**
```bash
# CPU Usage
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'

# Memory Usage
free -h | awk 'NR==2{printf "Memory Usage: %s/%s (%.2f%%)\n", $3,$2,$3*100/$2 }'

# Disk Usage
df -h / | awk 'NR==2{printf "Disk Usage: %s/%s (%s)\n", $3,$2,$5}'
```

### Alert Thresholds

**Critical (sofortige Aktion):**
- Gateway down > 5 min
- LiteLLM down > 5 min
- Disk usage > 90%
- Memory usage > 95%

**Warning (zeitnahe Aktion):**
- Error rate > 10%
- Response time > 10s average
- Disk usage > 80%
- Memory usage > 85%

### Monitoring Script

```bash
#!/bin/bash
# monitor-openclaw.sh

echo "=== OpenClaw System Monitor ==="
echo "Time: $(date)"
echo ""

# Gateway Status
if systemctl is-active --quiet openclaw-gateway; then
  echo "✓ Gateway: Running"
else
  echo "✗ Gateway: DOWN"
fi

# LiteLLM Status
if systemctl is-active --quiet litellm-proxy; then
  echo "✓ LiteLLM: Running"
else
  echo "✗ LiteLLM: DOWN"
fi

# Health Check
if openclaw health &>/dev/null; then
  echo "✓ Health: OK"
else
  echo "✗ Health: FAILED"
fi

# Resources
CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
MEM=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
DISK=$(df / | awk 'NR==2{print $5}' | sed 's/%//')

echo ""
echo "CPU: ${CPU}%"
echo "Memory: ${MEM}%"
echo "Disk: ${DISK}%"

# Alerts
if [ $(echo "$CPU > 80" | bc) -eq 1 ]; then
  echo "⚠ WARNING: High CPU usage!"
fi

if [ $MEM -gt 85 ]; then
  echo "⚠ WARNING: High memory usage!"
fi

if [ $DISK -gt 80 ]; then
  echo "⚠ WARNING: Low disk space!"
fi
```

---

## 🔧 Common Maintenance Tasks

### Log Rotation konfigurieren

```bash
# Logrotate Config für OpenClaw
cat > /etc/logrotate.d/openclaw << 'EOF'
/tmp/openclaw/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

### Workspace Cleanup

```bash
# Alte node_modules löschen (dev-agent workspace)
cd /opt/openclaw/workspaces/dev-agent
find . -name "node_modules" -type d -prune -exec rm -rf {} +

# Rebuild falls nötig
npm install
```

### Certificate Renewal (falls HTTPS)

```bash
# Let's Encrypt Renewal (auf Traefik-Server)
ssh root@192.168.1.4 'certbot renew'
ssh root@192.168.1.4 'docker restart traefik'
```

---

## 📝 Maintenance Checklist

### Vor Updates

- [ ] Backup erstellt
- [ ] Aktuellen Status dokumentiert
- [ ] Downtime-Fenster geplant
- [ ] Rollback-Plan bereit

### Nach Updates

- [ ] Health Check erfolgreich
- [ ] Alle Services running
- [ ] Agents antworten
- [ ] Logs auf Errors geprüft
- [ ] Update dokumentiert

### Monatlich

- [ ] System Updates durchgeführt
- [ ] Backups verifiziert
- [ ] Logs reviewed
- [ ] Performance-Metriken geprüft
- [ ] Disk Space geprüft

---

**Version:** 1.0.0  
**Last Update:** 2026-06-03
