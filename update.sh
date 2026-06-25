#!/usr/bin/env bash
# ============================================================================
# OpenClaw Update Script
# ============================================================================
# Zentrale Update-Verwaltung für alle Skills auf dem OpenClaw Container
# ============================================================================

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguration
OPENCLAW_HOST="${1:-192.168.1.11}"
OPENCLAW_USER="root"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Banner
echo "===================================================================="
echo "  OpenClaw Update System"
echo "  Target: ${OPENCLAW_HOST}"
echo "===================================================================="
echo

# Prüfe SSH-Verbindung
log "Prüfe SSH-Verbindung zu ${OPENCLAW_HOST}..."
if ! ssh -o ConnectTimeout=5 "${OPENCLAW_USER}@${OPENCLAW_HOST}" "true" 2>/dev/null; then
    error "Keine SSH-Verbindung zu ${OPENCLAW_HOST}"
    exit 1
fi
success "SSH-Verbindung OK"
echo

# ============================================================================
# Funktionen für einzelne Skills
# ============================================================================

update_cert_manager() {
    log "Update cert-manager..."

    # Backup erstellen
    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
        mkdir -p /opt/openclaw/backups
        backup_dir=\"/opt/openclaw/backups/cert-manager-\$(date +%Y%m%d-%H%M%S)\"
        cp -r /opt/openclaw/skills/cert-manager \"\$backup_dir\"
        echo \"Backup: \$backup_dir\"
    "

    # Dateien deployen
    rsync -az --info=progress2 \
        --exclude '.git' \
        --exclude '__pycache__' \
        --exclude '*.pyc' \
        --exclude 'data/' \
        --exclude 'logs/' \
        "${SCRIPT_DIR}/skills/cert-manager/" \
        "${OPENCLAW_USER}@${OPENCLAW_HOST}:/opt/openclaw/skills/cert-manager/"

    # Services neustarten
    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
        systemctl restart cert-manager-api cert-manager-web
        sleep 2
        systemctl is-active cert-manager-api cert-manager-web
    "

    success "cert-manager aktualisiert"
}

update_traefik_service_manager() {
    log "Update traefik-service-manager..."

    # Backup
    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
        backup_dir=\"/opt/openclaw/backups/traefik-service-manager-\$(date +%Y%m%d-%H%M%S)\"
        cp -r /opt/openclaw/skills/traefik-service-manager \"\$backup_dir\" 2>/dev/null || true
    "

    # Deploy
    cd "${SCRIPT_DIR}/skills/traefik-service-manager"
    bash deploy-skill.sh "${OPENCLAW_HOST}" >/dev/null 2>&1

    success "traefik-service-manager aktualisiert"
}

update_pihole_dns_manager() {
    log "Update pihole-dns-manager..."

    # Backup
    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
        backup_dir=\"/opt/openclaw/backups/pihole-dns-manager-\$(date +%Y%m%d-%H%M%S)\"
        cp -r /opt/openclaw/skills/pihole-dns-manager \"\$backup_dir\" 2>/dev/null || true
    "

    # Deploy
    cd "${SCRIPT_DIR}/skills/pihole-dns-manager"
    bash deploy-skill.sh "${OPENCLAW_HOST}" >/dev/null 2>&1

    success "pihole-dns-manager aktualisiert"
}

# ============================================================================
# Update-Strategien
# ============================================================================

update_all() {
    log "Starte vollständiges Update aller Skills..."
    echo

    update_cert_manager
    echo

    update_traefik_service_manager
    echo

    update_pihole_dns_manager
    echo

    success "Alle Skills aktualisiert!"
}

update_specific() {
    local skill="$1"

    case "$skill" in
        cert-manager)
            update_cert_manager
            ;;
        traefik-service-manager|traefik)
            update_traefik_service_manager
            ;;
        pihole-dns-manager|pihole)
            update_pihole_dns_manager
            ;;
        *)
            error "Unbekanntes Skill: $skill"
            echo
            echo "Verfügbare Skills:"
            echo "  - cert-manager"
            echo "  - traefik-service-manager"
            echo "  - pihole-dns-manager"
            exit 1
            ;;
    esac
}

status_check() {
    log "Prüfe Status aller Services..."
    echo

    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" << 'EOF'
echo "=== cert-manager ==="
systemctl status cert-manager-api cert-manager-web --no-pager -l | grep -E "Active:|Main PID:|Memory:" || true
echo

echo "=== Skill Versionen ==="
echo -n "cert-manager: "
grep "v[0-9]" /opt/openclaw/skills/cert-manager/web/templates/base.html 2>/dev/null | grep -o "v[0-9]\.[0-9]\.[0-9]" || echo "unknown"

echo -n "traefik-service-manager: "
head -5 /opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh 2>/dev/null | grep -o "v[0-9]\.[0-9]\.[0-9]" || echo "no version tag"

echo -n "pihole-dns-manager: "
head -5 /opt/openclaw/skills/pihole-dns-manager/pihole-dns-manager.sh 2>/dev/null | grep -o "v[0-9]\.[0-9]\.[0-9]" || echo "no version tag"

echo
echo "=== Letzte Backups ==="
ls -1t /opt/openclaw/backups/ 2>/dev/null | head -5 || echo "(keine Backups)"
EOF
}

rollback() {
    local skill="$1"

    log "Verfügbare Backups für ${skill}:"
    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "ls -1t /opt/openclaw/backups/ | grep '^${skill}-'"

    echo
    read -p "Backup-Verzeichnis (oder Enter für neuestes): " backup_dir

    if [[ -z "$backup_dir" ]]; then
        backup_dir=$(ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "ls -1t /opt/openclaw/backups/ | grep '^${skill}-' | head -1")
    fi

    if [[ -z "$backup_dir" ]]; then
        error "Kein Backup gefunden"
        exit 1
    fi

    log "Stelle ${skill} wieder her von: ${backup_dir}"

    ssh "${OPENCLAW_USER}@${OPENCLAW_HOST}" "
        set -e
        rm -rf /opt/openclaw/skills/${skill}
        cp -r /opt/openclaw/backups/${backup_dir} /opt/openclaw/skills/${skill}

        # Services neustarten falls cert-manager
        if [[ '${skill}' == 'cert-manager' ]]; then
            systemctl restart cert-manager-api cert-manager-web
        fi
    "

    success "Rollback abgeschlossen"
}

show_help() {
    cat << EOF
OpenClaw Update Script

USAGE:
    ./update.sh [OPENCLAW_HOST] [COMMAND] [OPTIONS]

COMMANDS:
    all                    Aktualisiere alle Skills
    <skill-name>          Aktualisiere spezifisches Skill
    status                Zeige Status und Versionen
    rollback <skill>      Stelle Skill von Backup wieder her
    help                  Zeige diese Hilfe

SKILLS:
    cert-manager
    traefik-service-manager
    pihole-dns-manager

EXAMPLES:
    # Alle Skills aktualisieren
    ./update.sh all

    # Nur cert-manager aktualisieren
    ./update.sh cert-manager

    # Auf anderem Host aktualisieren
    ./update.sh 192.168.1.99 all

    # Status prüfen
    ./update.sh status

    # Rollback
    ./update.sh rollback cert-manager

WORKFLOW:
    1. Lokale Änderungen machen (git pull oder direkt editieren)
    2. ./update.sh all
    3. Testen: http://192.168.1.11:5000
    4. Bei Problemen: ./update.sh rollback <skill>

NOTES:
    - Automatisches Backup vor jedem Update
    - Backups in /opt/openclaw/backups/
    - SSH-Key-Authentifizierung erforderlich
    - cert-manager Services werden automatisch neugestartet

EOF
}

# ============================================================================
# Main
# ============================================================================

# Parse Command
COMMAND="${2:-all}"

case "$COMMAND" in
    all)
        update_all
        ;;
    status)
        status_check
        ;;
    rollback)
        if [[ -z "${3:-}" ]]; then
            error "Skill-Name erforderlich: ./update.sh rollback <skill-name>"
            exit 1
        fi
        rollback "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    cert-manager|traefik-service-manager|traefik|pihole-dns-manager|pihole)
        update_specific "$COMMAND"
        ;;
    *)
        error "Unbekannter Command: $COMMAND"
        echo
        show_help
        exit 1
        ;;
esac

echo
echo "===================================================================="
echo "  Update abgeschlossen"
echo "===================================================================="
echo
echo "Nächste Schritte:"
echo "  - Status prüfen: ./update.sh status"
echo "  - Web-UI testen: http://192.168.1.11:5000"
echo "  - Logs ansehen: ssh root@${OPENCLAW_HOST} 'journalctl -u cert-manager-api -f'"
echo
