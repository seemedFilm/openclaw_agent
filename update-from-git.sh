#!/usr/bin/env bash
# ============================================================================
# OpenClaw Git-based Update Script
# ============================================================================
# Holt neueste Änderungen von Git und deployed sie automatisch
# ============================================================================

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_HOST="${1:-192.168.1.11}"

echo "===================================================================="
echo "  OpenClaw Git-based Update"
echo "===================================================================="
echo

# ============================================================================
# 1. Git Status prüfen
# ============================================================================

log "Prüfe Git-Repository..."
cd "$SCRIPT_DIR"

# Uncommitted Changes?
if [[ -n $(git status --porcelain) ]]; then
    warn "Lokale Änderungen vorhanden!"
    git status --short
    echo
    read -p "Trotzdem fortfahren? Lokale Änderungen gehen verloren! (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        error "Abgebrochen"
        exit 1
    fi
fi

# Aktueller Branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log "Branch: ${CURRENT_BRANCH}"

# Aktueller Commit
BEFORE_COMMIT=$(git rev-parse HEAD)
BEFORE_SHORT=$(git rev-parse --short HEAD)
log "Aktueller Commit: ${BEFORE_SHORT}"

echo

# ============================================================================
# 2. Git Pull
# ============================================================================

log "Hole neueste Änderungen von origin/${CURRENT_BRANCH}..."

if ! git pull origin "${CURRENT_BRANCH}"; then
    error "Git pull fehlgeschlagen"
    exit 1
fi

AFTER_COMMIT=$(git rev-parse HEAD)
AFTER_SHORT=$(git rev-parse --short HEAD)

if [[ "$BEFORE_COMMIT" == "$AFTER_COMMIT" ]]; then
    success "Bereits auf dem neuesten Stand"
    exit 0
fi

success "Update erfolgreich: ${BEFORE_SHORT} → ${AFTER_SHORT}"
echo

# ============================================================================
# 3. Zeige Änderungen
# ============================================================================

log "Geänderte Dateien:"
git diff --name-status "${BEFORE_COMMIT}" "${AFTER_COMMIT}" | while read -r status file; do
    case "$status" in
        M) echo "  📝 Modified:  $file" ;;
        A) echo "  ➕ Added:     $file" ;;
        D) echo "  ❌ Deleted:   $file" ;;
        *) echo "  $status $file" ;;
    esac
done

echo

# Commit-Messages
log "Neue Commits:"
git log --oneline "${BEFORE_COMMIT}..${AFTER_COMMIT}" | sed 's/^/  /'
echo

# ============================================================================
# 4. Erkenne betroffene Skills
# ============================================================================

log "Erkenne betroffene Skills..."

CHANGED_FILES=$(git diff --name-only "${BEFORE_COMMIT}" "${AFTER_COMMIT}")
SKILLS_TO_UPDATE=()

if echo "$CHANGED_FILES" | grep -q "^skills/cert-manager/"; then
    SKILLS_TO_UPDATE+=("cert-manager")
fi

if echo "$CHANGED_FILES" | grep -q "^skills/traefik-service-manager/"; then
    SKILLS_TO_UPDATE+=("traefik-service-manager")
fi

if echo "$CHANGED_FILES" | grep -q "^skills/pihole-dns-manager/"; then
    SKILLS_TO_UPDATE+=("pihole-dns-manager")
fi

if [[ ${#SKILLS_TO_UPDATE[@]} -eq 0 ]]; then
    warn "Keine Skill-Änderungen erkannt"
    echo "Geänderte Dateien:"
    echo "$CHANGED_FILES" | sed 's/^/  /'
    echo
    read -p "Trotzdem alle Skills aktualisieren? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        SKILLS_TO_UPDATE=("cert-manager" "traefik-service-manager" "pihole-dns-manager")
    else
        success "Keine Updates notwendig"
        exit 0
    fi
fi

log "Zu aktualisierende Skills:"
for skill in "${SKILLS_TO_UPDATE[@]}"; do
    echo "  - $skill"
done

echo
read -p "Fortfahren mit Update? (Y/n): " confirm
if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
    error "Abgebrochen"
    exit 1
fi

echo

# ============================================================================
# 5. Führe Update aus
# ============================================================================

for skill in "${SKILLS_TO_UPDATE[@]}"; do
    log "Update $skill..."
    if bash update.sh "${OPENCLAW_HOST}" "$skill"; then
        success "$skill aktualisiert"
    else
        error "$skill Update fehlgeschlagen"
        exit 1
    fi
    echo
done

# ============================================================================
# 6. Verifikation
# ============================================================================

log "Verifikation..."
bash update.sh "${OPENCLAW_HOST}" status

echo
success "Git-based Update abgeschlossen!"
echo
echo "===================================================================="
echo "  Changelog: ${BEFORE_SHORT} → ${AFTER_SHORT}"
echo "===================================================================="
git log --pretty=format:"%h - %s" "${BEFORE_COMMIT}..${AFTER_COMMIT}" | sed 's/^/  /'
echo
echo
