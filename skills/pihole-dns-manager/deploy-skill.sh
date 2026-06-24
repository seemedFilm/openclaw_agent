#!/usr/bin/env bash
# ============================================================================
# Deploy Pi-hole DNS Manager Skill zum OpenClaw Container
# ============================================================================

set -euo pipefail

# Konfiguration
OPENCLAW_HOST="${1:-192.168.1.11}"
OPENCLAW_USER="root"
SKILL_NAME="pihole-dns-manager"
LOCAL_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SKILL_DIR="/opt/openclaw/skills/${SKILL_NAME}"

echo "=== Deploy Pi-hole DNS Manager Skill ==="
echo
echo "Ziel: ${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_SKILL_DIR}"
echo

# Prüfe SSH-Verbindung
echo "Prüfe SSH-Verbindung..."
if ! ssh -o ConnectTimeout=5 "${OPENCLAW_USER}@${OPENCLAW_HOST}" "true" 2>/dev/null; then
    echo "ERROR: Keine SSH-Verbindung zu ${OPENCLAW_HOST}" >&2
    echo "       Prüfe SSH-Keys und Netzwerk" >&2
    exit 1
fi
echo "✓ SSH-Verbindung OK"

# Erstelle Remote-Verzeichnis
echo "Erstelle Skill-Verzeichnis..."
ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "mkdir -p ${REMOTE_SKILL_DIR}/{lib,examples}" || {
    echo "ERROR: Konnte Verzeichnis nicht erstellen" >&2
    exit 1
}
echo "✓ Verzeichnis erstellt"

# Kopiere Dateien
echo "Kopiere Skill-Dateien..."

# Hauptscript
scp "${LOCAL_SKILL_DIR}/pihole-dns-manager.sh" \
    "${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_SKILL_DIR}/" || exit 1

# Libraries
scp "${LOCAL_SKILL_DIR}/lib/"*.sh \
    "${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_SKILL_DIR}/lib/" || exit 1

# Konfiguration
scp "${LOCAL_SKILL_DIR}/config.yaml" \
    "${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_SKILL_DIR}/" || exit 1

# README
scp "${LOCAL_SKILL_DIR}/README.md" \
    "${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_SKILL_DIR}/" || exit 1

# Beispiele
scp "${LOCAL_SKILL_DIR}/examples/"*.sh \
    "${OPENCLAW_USER}@${OPENCLAW_HOST}:${REMOTE_SKILL_DIR}/examples/" || exit 1

echo "✓ Dateien kopiert"

# Setze Executable-Rechte
echo "Setze Executable-Rechte..."
ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
    chmod +x ${REMOTE_SKILL_DIR}/pihole-dns-manager.sh
    chmod +x ${REMOTE_SKILL_DIR}/lib/*.sh
    chmod +x ${REMOTE_SKILL_DIR}/examples/*.sh
" || {
    echo "WARNING: Konnte Permissions nicht setzen" >&2
}
echo "✓ Permissions gesetzt"

# Prüfe Deployment
echo
echo "Verifiziere Deployment..."
ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
    echo '=== Installierte Dateien ==='
    ls -lh ${REMOTE_SKILL_DIR}/
    echo
    echo '=== Libraries ==='
    ls -lh ${REMOTE_SKILL_DIR}/lib/
    echo
    echo '=== Beispiele ==='
    ls -lh ${REMOTE_SKILL_DIR}/examples/
" || {
    echo "WARNING: Konnte Dateien nicht auflisten" >&2
}

echo
echo "✓ Deployment erfolgreich!"
echo
echo "Nächste Schritte:"
echo "1. Pi-hole API-Token setzen:"
echo "   ssh ${OPENCLAW_USER}@${OPENCLAW_HOST}"
echo "   echo 'export PIHOLE_API_TOKEN=\"your-token-here\"' >> /root/.bashrc"
echo "   source /root/.bashrc"
echo
echo "2. Skill testen:"
echo "   ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} '${REMOTE_SKILL_DIR}/pihole-dns-manager.sh test'"
echo
echo "3. DNS-Record hinzufügen:"
echo "   ssh ${OPENCLAW_USER}@${OPENCLAW_HOST} '${REMOTE_SKILL_DIR}/pihole-dns-manager.sh add --hostname test.internal'"
echo
