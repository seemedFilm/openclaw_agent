# Amazon Bedrock Integration mit OpenClaw

Da OpenClaw und Claude Code standardmäßig die Anthropic API erwarten, du aber Amazon Bedrock nutzt, gibt es mehrere Lösungsansätze.

## 🎯 Optionen

### Option 1: LiteLLM Proxy (Empfohlen)

LiteLLM ist ein Proxy, der Bedrock API-Calls in Anthropic-Format übersetzt.

**Vorteile:**
- ✅ Transparent für OpenClaw
- ✅ Unterstützt alle Bedrock-Modelle
- ✅ Einfacher Wechsel zu nativer API später

**Setup:**

```bash
# Im OpenClaw Container
pip3 install litellm[proxy]

# AWS Credentials konfigurieren
export AWS_ACCESS_KEY_ID="dein-access-key"
export AWS_SECRET_ACCESS_KEY="dein-secret-key"
export AWS_REGION_NAME="us-east-1"  # oder deine Region

# LiteLLM Proxy starten (läuft lokal auf Port 4000)
litellm --model bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
```

**OpenClaw Config:**

```bash
# Setze API-Endpoint auf LiteLLM Proxy
export ANTHROPIC_API_KEY="dummy-key"  # Dummy, da Bedrock AWS-Auth nutzt
export ANTHROPIC_BASE_URL="http://localhost:4000"
```

**Als Systemd Service:**

```bash
# Erstelle Service-Datei
cat > /etc/systemd/system/litellm-proxy.service <<'EOF'
[Unit]
Description=LiteLLM Proxy for Amazon Bedrock
After=network.target

[Service]
Type=simple
User=root
Environment="AWS_ACCESS_KEY_ID=dein-access-key"
Environment="AWS_SECRET_ACCESS_KEY=dein-secret-key"
Environment="AWS_REGION_NAME=us-east-1"
ExecStart=/usr/local/bin/litellm --model bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0 --port 4000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren
systemctl daemon-reload
systemctl enable litellm-proxy
systemctl start litellm-proxy
systemctl status litellm-proxy
```

---

### Option 2: AWS Bedrock SDK direkt (Komplex)

OpenClaw müsste modifiziert werden, um Bedrock SDK zu nutzen.

**Nachteil:**
- ❌ Erfordert Code-Anpassungen in OpenClaw
- ❌ Nicht empfohlen, da wartungsintensiv

---

### Option 3: Native Claude API Key beschaffen (Später)

Wenn du später einen nativen Claude API-Key hast:

```bash
# Einfach .env anpassen:
CLAUDE_API_KEY="sk-ant-..."

# Im Container:
export ANTHROPIC_API_KEY="sk-ant-..."
unset ANTHROPIC_BASE_URL  # Falls LiteLLM-Proxy vorher genutzt
```

---

## 🚀 Empfohlener Ablauf für dich

### Jetzt (mit Bedrock):

**1. LiteLLM im Container installieren:**

```bash
# Nach dem LXC-Setup, im Container:
ssh root@192.168.1.11

# LiteLLM installieren
pip3 install 'litellm[proxy]'

# AWS Credentials persistent setzen
cat >> ~/.bashrc <<'EOF'

# AWS Bedrock Credentials
export AWS_ACCESS_KEY_ID="dein-access-key"
export AWS_SECRET_ACCESS_KEY="dein-secret-key"
export AWS_REGION_NAME="us-east-1"
EOF

source ~/.bashrc
```

**2. LiteLLM testen:**

```bash
# Starte Proxy im Vordergrund (Test)
litellm --model bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0 --port 4000

# In einem zweiten Terminal:
curl http://localhost:4000/v1/models
```

**3. OpenClaw konfigurieren:**

```bash
# Im Container
cat >> ~/.bashrc <<'EOF'

# OpenClaw mit LiteLLM Proxy
export ANTHROPIC_API_KEY="bedrock-via-litellm"
export ANTHROPIC_BASE_URL="http://localhost:4000"
EOF

source ~/.bashrc
```

**4. OpenClaw testen:**

```bash
openclaw chat "Hallo, teste die Bedrock-Verbindung"
```

**5. LiteLLM als Service einrichten:**

```bash
# Erstelle Service (siehe oben)
# Dann OpenClaw nutzen wie gewohnt
```

---

### Später (mit nativer API):

```bash
# Im Container ~/.bashrc ändern:
# Altes entfernen:
# export ANTHROPIC_BASE_URL="http://localhost:4000"

# Neues eintragen:
export ANTHROPIC_API_KEY="sk-ant-..."

# LiteLLM Service stoppen (nicht mehr benötigt)
systemctl stop litellm-proxy
systemctl disable litellm-proxy
```

---

## 🔧 .env Anpassungen

Aktualisiere deine `.env.example`:

```bash
# ----------------------------------------------------------------------------
# OpenClaw Konfiguration
# ----------------------------------------------------------------------------

# Option A: Native Claude API (später)
CLAUDE_API_KEY=sk-ant-...

# Option B: Amazon Bedrock (jetzt)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION_NAME=us-east-1
AWS_BEDROCK_MODEL=anthropic.claude-3-5-sonnet-20241022-v2:0

# LiteLLM Proxy für Bedrock (wenn Option B)
LITELLM_ENABLED=true
LITELLM_PORT=4000
```

---

## 📊 Kosten-Vergleich

| API | Sonnet 4 (Input) | Sonnet 4 (Output) |
|-----|------------------|-------------------|
| **Bedrock** | $3.00 / 1M tokens | $15.00 / 1M tokens |
| **Native Claude** | $3.00 / 1M tokens | $15.00 / 1M tokens |

Preislich identisch, aber Bedrock hat AWS-Overhead (IAM, Regions, etc.).

---

## 🆘 Troubleshooting

### LiteLLM startet nicht

```bash
# Logs prüfen
journalctl -u litellm-proxy -f

# Manuell testen
litellm --model bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0 --debug
```

### OpenClaw findet LiteLLM nicht

```bash
# Prüfe ob Proxy läuft
curl http://localhost:4000/health

# Prüfe Environment
echo $ANTHROPIC_BASE_URL
```

### AWS Credentials ungültig

```bash
# Teste AWS-Zugriff direkt
aws bedrock list-foundation-models --region us-east-1

# Falls aws-cli fehlt:
pip3 install awscli
aws configure
```

---

## 🎯 Nächste Schritte

1. **Jetzt:** LXC Container deployen (ohne API)
2. **Nach LXC-Setup:** LiteLLM Proxy einrichten
3. **Dann:** OpenClaw Onboarding mit Proxy
4. **Später:** Auf native API wechseln (einfacher Env-Var-Wechsel)

Möchtest du, dass ich das `setup-openclaw.sh` Script erweitere, um LiteLLM automatisch zu installieren?
