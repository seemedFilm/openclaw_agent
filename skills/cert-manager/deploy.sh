#!/bin/bash
# ============================================================================
# Cert-Manager Deployment Script
# Deployed cert-manager auf OpenClaw Container (192.168.1.11)
# ============================================================================

set -e

OPENCLAW_HOST="192.168.1.11"
OPENCLAW_USER="root"
REMOTE_PATH="/opt/openclaw/skills/cert-manager"

echo "==================================================================="
echo "  Cert-Manager Deployment"
echo "==================================================================="

# 0. Verzeichnis erstellen
echo "➜ Erstelle Verzeichnisse auf $OPENCLAW_HOST..."
ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} "mkdir -p ${REMOTE_PATH}/{api,web/templates,web/static/css,lib,config,logs,data}"

# 1. Dateien kopieren
echo "➜ Kopiere Dateien auf $OPENCLAW_HOST..."
rsync -az --info=progress2 --exclude '.git' --exclude '__pycache__' \
    . ${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_PATH}/
echo "   ✓ Dateien synchronisiert"

# 2. SSH-Keys einrichten
echo "➜ SSH-Keys einrichten..."
ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} << 'EOF'
set -e

if [ ! -f /root/.ssh/cert_manager ]; then
    echo "Erstelle SSH-Key für cert-manager..."
    ssh-keygen -t ed25519 -C "cert-manager" -f /root/.ssh/cert_manager -N ""

    echo ""
    echo "✋ WICHTIG: Kopiere folgenden Public Key auf step-ca Server (192.168.1.3):"
    echo ""
    cat /root/.ssh/cert_manager.pub
    echo ""
    echo "Befehl auf 192.168.1.3 ausführen:"
    echo "  echo '$(cat /root/.ssh/cert_manager.pub)' >> /root/.ssh/authorized_keys"
    echo ""
    read -p "Drücke Enter wenn fertig..."
fi

# SSH Config
if ! grep -q "Host step-ca" /root/.ssh/config 2>/dev/null; then
    echo "Füge step-ca zu SSH config hinzu..."
    cat >> /root/.ssh/config <<'SSHCONF'

Host step-ca
    HostName 192.168.1.3
    User root
    IdentityFile /root/.ssh/cert_manager
    StrictHostKeyChecking no
SSHCONF
    chmod 600 /root/.ssh/config
fi

EOF

# 3. Python Dependencies (in venv)
echo "➜ Installiere Python-Dependencies in venv..."
ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} << 'EOF'
set -e

# Verwende existierendes venv
/opt/openclaw/venv/bin/pip install -q fastapi uvicorn pydantic sqlalchemy python-jose cryptography paramiko flask pyyaml

EOF

# 4. Datenbank initialisieren
echo "➜ Initialisiere Datenbank..."
ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} << 'EOF'
set -e

cd /opt/openclaw/skills/cert-manager
/opt/openclaw/venv/bin/python3 api/init_db.py

EOF

# 5. Systemd Services
echo "➜ Erstelle Systemd-Services..."
ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} << 'EOF'
set -e

# API Service
cat > /etc/systemd/system/cert-manager-api.service <<'SERVICE'
[Unit]
Description=Cert-Manager REST API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/skills/cert-manager
ExecStart=/opt/openclaw/venv/bin/python3 -m uvicorn api.main:app --host 0.0.0.0 --port 5001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Web-UI Service
cat > /etc/systemd/system/cert-manager-web.service <<'SERVICE'
[Unit]
Description=Cert-Manager Web UI
After=network.target cert-manager-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/skills/cert-manager
ExecStart=/opt/openclaw/venv/bin/python3 web/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Renewal Scheduler Service
cat > /etc/systemd/system/cert-manager-renewal.service <<'SERVICE'
[Unit]
Description=Cert-Manager Renewal Scheduler
After=network.target cert-manager-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/skills/cert-manager
ExecStart=/opt/openclaw/venv/bin/python3 lib/renewal_scheduler.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Services aktivieren und starten
systemctl daemon-reload
systemctl enable cert-manager-api cert-manager-web cert-manager-renewal
systemctl restart cert-manager-api cert-manager-web cert-manager-renewal

EOF

# 6. Status prüfen
echo ""
echo "➜ Service-Status:"
ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} << 'EOF'
systemctl status cert-manager-api --no-pager | head -10
systemctl status cert-manager-web --no-pager | head -10
systemctl status cert-manager-renewal --no-pager | head -10
EOF

echo ""
echo "==================================================================="
echo "✅ Deployment erfolgreich!"
echo "==================================================================="
echo ""
echo "Nächste Schritte:"
echo ""
echo "1. Traefik-Route einrichten:"
echo "   ssh root@192.168.1.11"
echo "   /opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add \\"
echo "     --hostname certs.internal \\"
echo "     --backend http://192.168.1.11:5000"
echo ""
echo "2. Traefik BasicAuth konfigurieren (siehe README.md)"
echo ""
echo "3. Web-UI öffnen: https://certs.internal"
echo ""
echo "4. API-Test:"
echo "   curl http://localhost:5001/api/certs"
echo ""
