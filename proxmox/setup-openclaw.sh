#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw Installation Script für Ubuntu 24.04 LXC
# ============================================================================
# Dieses Script wird INNERHALB des LXC-Containers ausgeführt und installiert
# alle benötigten Abhängigkeiten sowie OpenClaw selbst.
# ============================================================================

export DEBIAN_FRONTEND=noninteractive

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# ============================================================================
# System Update
# ============================================================================

log "Aktualisiere System-Packages..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    vim \
    htop \
    net-tools \
    dnsutils \
    jq \
    unzip \
    software-properties-common

success "System-Packages aktualisiert"

# ============================================================================
# Node.js Installation (v20 LTS)
# ============================================================================

log "Installiere Node.js 20 LTS..."

# NodeSource Repository
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs

# Verifiziere Installation
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

success "Node.js ${NODE_VERSION} und npm ${NPM_VERSION} installiert"

# ============================================================================
# OpenClaw Installation
# ============================================================================

log "Installiere OpenClaw global..."

# Installiere OpenClaw via offiziellen Installer
curl -fsSL https://openclaw.ai/install.sh | bash

# Verifiziere Installation
if command -v openclaw &> /dev/null; then
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "0.x.x")
    success "OpenClaw ${OPENCLAW_VERSION} erfolgreich installiert"
else
    error "OpenClaw Installation fehlgeschlagen"
    exit 1
fi

# ============================================================================
# Docker Installation (für Skills die Container benötigen)
# ============================================================================

log "Installiere Docker..."

# Docker GPG Key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Docker Repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker Service starten
systemctl enable docker
systemctl start docker

success "Docker installiert und gestartet"

# ============================================================================
# Python & Ansible (für Ops-Agent)
# ============================================================================

log "Installiere Python und Ansible..."

apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-venv \
    ansible

success "Python $(python3 --version | cut -d' ' -f2) und Ansible installiert"

# ============================================================================
# GitHub CLI (für Review-Agent)
# ============================================================================

log "Installiere GitHub CLI..."

# GitHub CLI Repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

apt-get update -qq
apt-get install -y -qq gh

success "GitHub CLI $(gh --version | head -n1 | cut -d' ' -f3) installiert"

# ============================================================================
# Security Tools (für Security-Agent)
# ============================================================================

log "Installiere Security-Tools..."

apt-get install -y -qq \
    trivy \
    lynis

# npm security tools
npm install -g \
    npm-audit \
    snyk

success "Security-Tools installiert"

# ============================================================================
# Monitoring Tools (für Ops-Agent)
# ============================================================================

log "Installiere Monitoring-Tools..."

apt-get install -y -qq \
    prometheus-node-exporter

systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

success "Monitoring-Tools installiert"

# ============================================================================
# OpenClaw Verzeichnisse
# ============================================================================

log "Erstelle OpenClaw-Verzeichnisstruktur..."

mkdir -p /opt/openclaw/{agents,skills,config,logs}
mkdir -p /opt/openclaw/agents/{dev,review,security,ops}
mkdir -p /opt/openclaw/skills/{traefik-manager,cert-manager}

# Permissions
chmod 755 /opt/openclaw
chown -R root:root /opt/openclaw

success "Verzeichnisstruktur erstellt"

# ============================================================================
# SSH für Remote Traefik Management
# ============================================================================

log "Konfiguriere SSH Client..."

# SSH Config für Traefik-Server
mkdir -p /root/.ssh
chmod 700 /root/.ssh

cat > /root/.ssh/config <<'EOF'
# OpenClaw Traefik Management
Host traefik-server
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
    ServerAliveCountMax 3
    # Hostname, User und IdentityFile werden von Ops-Agent gesetzt
EOF

chmod 600 /root/.ssh/config

success "SSH konfiguriert"

# ============================================================================
# Systemd Services (optional für Agent-Daemon)
# ============================================================================

log "Erstelle Systemd-Service Templates..."

cat > /etc/systemd/system/openclaw-agent@.service <<'EOF'
[Unit]
Description=OpenClaw %I Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw/agents/%i
ExecStart=/usr/bin/openclaw agent start %i
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

success "Systemd-Services erstellt"

# ============================================================================
# Firewall (optional)
# ============================================================================

log "Konfiguriere Firewall..."

apt-get install -y -qq ufw

# Erlaube SSH
ufw allow 22/tcp comment 'SSH'

# Erlaube Node Exporter (Prometheus)
ufw allow 9100/tcp comment 'Prometheus Node Exporter'

# Enable UFW (non-interactive)
echo "y" | ufw enable

success "Firewall konfiguriert"

# ============================================================================
# LiteLLM Proxy (für Amazon Bedrock Support)
# ============================================================================

log "Installiere LiteLLM Proxy (für Bedrock-Support)..."

pip3 install -q 'litellm[proxy]' 'boto3'

# Installiere AWS CLI
pip3 install -q awscli

success "LiteLLM und AWS CLI installiert"

# Erstelle LiteLLM Systemd Service Template
cat > /etc/systemd/system/litellm-proxy.service <<'EOF'
[Unit]
Description=LiteLLM Proxy for Amazon Bedrock
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=-/opt/openclaw/config/litellm.env
ExecStart=/usr/local/bin/litellm --model ${BEDROCK_MODEL:-bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0} --port ${LITELLM_PORT:-8000}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Erstelle Config-Verzeichnis
mkdir -p /opt/openclaw/config

# Template für LiteLLM Env
cat > /opt/openclaw/config/litellm.env.example <<'EOF'
# AWS Bedrock Credentials
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_REGION_NAME=us-east-1

# Bedrock Model
BEDROCK_MODEL=bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0

# LiteLLM Port
LITELLM_PORT=8000
EOF

systemctl daemon-reload

log "LiteLLM Service vorbereitet (nicht aktiviert)"
log "Aktivierung später mit: systemctl enable --now litellm-proxy"

# ============================================================================
# Cleanup
# ============================================================================

log "Räume auf..."

apt-get autoremove -y -qq
apt-get clean
rm -rf /var/lib/apt/lists/*
npm cache clean --force

success "Cleanup abgeschlossen"

# ============================================================================
# Zusammenfassung
# ============================================================================

cat <<EOF

================================================================================
OpenClaw Setup abgeschlossen!
================================================================================

Installierte Komponenten:
  ✓ Node.js $(node --version)
  ✓ npm $(npm --version)
  ✓ OpenClaw $(openclaw --version)
  ✓ Docker $(docker --version | cut -d' ' -f3 | tr -d ',')
  ✓ Ansible $(ansible --version | head -n1 | cut -d' ' -f2)
  ✓ GitHub CLI $(gh --version | head -n1 | cut -d' ' -f3)
  ✓ Python $(python3 --version | cut -d' ' -f2)
  ✓ Security Tools (trivy, lynis, snyk)
  ✓ Monitoring (prometheus-node-exporter)
  ✓ LiteLLM Proxy (für Amazon Bedrock)
  ✓ AWS CLI $(aws --version | cut -d' ' -f1)

Verzeichnisstruktur:
  /opt/openclaw/
    ├── agents/       # Agent Konfigurationen
    ├── skills/       # Custom Skills
    ├── config/       # Globale Config
    └── logs/         # Log-Dateien

Nächste Schritte:
  1. API-Keys konfigurieren:

     a) Für Amazon Bedrock:
        - cp /opt/openclaw/config/litellm.env.example /opt/openclaw/config/litellm.env
        - nano /opt/openclaw/config/litellm.env  # AWS Credentials eintragen
        - systemctl enable --now litellm-proxy
        - export ANTHROPIC_BASE_URL="http://localhost:4000"
        - export ANTHROPIC_API_KEY="bedrock"  # Dummy für Bedrock

     b) Für native Claude API (später):
        - export ANTHROPIC_API_KEY="sk-ant-..."
        - systemctl stop litellm-proxy  # Proxy nicht mehr nötig

  2. OpenClaw Onboarding: openclaw onboard
  3. Agents einrichten (siehe /opt/openclaw/agents/)

  Siehe auch: /opt/openclaw/docs/BEDROCK-SETUP.md

Systemd Services:
  - systemctl start openclaw-agent@dev
  - systemctl start openclaw-agent@review
  - systemctl start openclaw-agent@security
  - systemctl start openclaw-agent@ops

================================================================================
EOF
