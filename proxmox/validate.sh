#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw Deployment Validierungs-Script
# ============================================================================
# Prüft alle Voraussetzungen bevor das Deployment gestartet wird
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

error() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

header() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo
}

# ============================================================================
# Lokale Voraussetzungen
# ============================================================================

check_local_requirements() {
    header "1. Lokale Voraussetzungen"

    # Bash Version
    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        success "Bash Version ${BASH_VERSION}"
    else
        error "Bash Version 4+ erforderlich (aktuell: ${BASH_VERSION})"
    fi

    # SSH Client
    if command -v ssh &> /dev/null; then
        success "SSH Client verfügbar ($(ssh -V 2>&1 | head -n1))"
    else
        error "SSH Client nicht gefunden"
    fi

    # SCP für Dateitransfer
    if command -v scp &> /dev/null; then
        success "SCP verfügbar"
    else
        error "SCP nicht gefunden"
    fi

    # Git (optional aber empfohlen)
    if command -v git &> /dev/null; then
        success "Git verfügbar ($(git --version))"
    else
        warn "Git nicht gefunden (optional für Updates)"
    fi
}

# ============================================================================
# SSH Helper Functions
# ============================================================================

ssh_exec() {
    # Führt SSH-Command aus mit gewählter Authentifizierungsmethode
    local auth_method="${PROXMOX_AUTH_METHOD:-auto}"
    local proxmox_user="${PROXMOX_USER:-root}"
    local proxmox_port="${PROXMOX_PORT:-22}"

    # Auto-Modus: Versuche erst Key, dann Passwort
    if [[ "$auth_method" == "auto" ]]; then
        # Versuche SSH-Key
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "${proxmox_port}" "${proxmox_user}@${PROXMOX_HOST}" "$@" 2>/dev/null; then
            return 0
        fi

        # Key fehlgeschlagen, versuche Passwort als Fallback
        if [[ -n "${PROXMOX_PASSWORD:-}" ]] && command -v sshpass &> /dev/null; then
            sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -p "${proxmox_port}" "${proxmox_user}@${PROXMOX_HOST}" "$@"
            return $?
        fi

        return 1
    fi

    # Nur Passwort
    if [[ "$auth_method" == "password" ]]; then
        if [[ -z "${PROXMOX_PASSWORD:-}" ]]; then
            return 1
        fi
        if ! command -v sshpass &> /dev/null; then
            return 1
        fi
        sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -p "${proxmox_port}" "${proxmox_user}@${PROXMOX_HOST}" "$@"
        return $?
    fi

    # Nur Key (Standard)
    ssh -p "${proxmox_port}" "${proxmox_user}@${PROXMOX_HOST}" "$@"
}

# ============================================================================
# Umgebungsvariablen
# ============================================================================

check_environment() {
    header "2. Umgebungsvariablen"

    # .env Datei laden falls vorhanden
    if [[ -f "$(dirname "$0")/config/.env" ]]; then
        success ".env Datei gefunden"
        # shellcheck disable=SC1091
        source "$(dirname "$0")/config/.env"
    else
        warn ".env Datei nicht gefunden (nutze Defaults)"
    fi

    # PROXMOX_HOST
    if [[ -n "${PROXMOX_HOST:-}" ]]; then
        success "PROXMOX_HOST gesetzt: ${PROXMOX_HOST}"
    else
        error "PROXMOX_HOST nicht gesetzt"
        info "Setze mit: export PROXMOX_HOST='192.168.1.10'"
    fi

    # Optional Vars
    PROXMOX_USER="${PROXMOX_USER:-root}"
    PROXMOX_PORT="${PROXMOX_PORT:-22}"
    PROXMOX_AUTH_METHOD="${PROXMOX_AUTH_METHOD:-auto}"
    PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-}"

    info "PROXMOX_USER: ${PROXMOX_USER}"
    info "PROXMOX_PORT: ${PROXMOX_PORT}"

    # Authentifizierungsmethode
    if [[ "$PROXMOX_AUTH_METHOD" == "password" ]]; then
        info "PROXMOX_AUTH_METHOD: password (Nur Passwort)"
        if [[ -n "$PROXMOX_PASSWORD" ]]; then
            success "PROXMOX_PASSWORD gesetzt"
        else
            error "PROXMOX_PASSWORD nicht gesetzt (erforderlich bei AUTH_METHOD=password)"
        fi

        if command -v sshpass &> /dev/null; then
            success "sshpass verfügbar"
        else
            error "sshpass nicht installiert (erforderlich für Passwort-Auth)"
            info "Installation: sudo apt install sshpass"
        fi
    elif [[ "$PROXMOX_AUTH_METHOD" == "auto" ]]; then
        info "PROXMOX_AUTH_METHOD: auto (SSH-Key mit Passwort-Fallback)"

        # Prüfe SSH-Key
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "${PROXMOX_USER}@${PROXMOX_HOST}" -p "${PROXMOX_PORT}" "exit" 2>/dev/null; then
            success "SSH-Key verfügbar (Primär)"
        else
            warn "SSH-Key nicht verfügbar"
        fi

        # Prüfe Passwort-Fallback
        if [[ -n "$PROXMOX_PASSWORD" ]]; then
            success "PROXMOX_PASSWORD gesetzt (Fallback)"
            if command -v sshpass &> /dev/null; then
                success "sshpass verfügbar (Fallback)"
            else
                warn "sshpass nicht installiert (Fallback deaktiviert)"
                info "Installation: sudo apt install sshpass"
            fi
        else
            warn "PROXMOX_PASSWORD nicht gesetzt (kein Fallback)"
        fi
    else
        info "PROXMOX_AUTH_METHOD: key (Nur SSH-Key)"
    fi
}

# ============================================================================
# Proxmox Verbindung
# ============================================================================

check_proxmox_connection() {
    header "3. Proxmox Verbindung"

    if [[ -z "${PROXMOX_HOST:-}" ]]; then
        error "PROXMOX_HOST nicht gesetzt - überspringe Verbindungstests"
        return
    fi

    local proxmox_user="${PROXMOX_USER:-root}"
    local proxmox_port="${PROXMOX_PORT:-22}"

    # Netzwerk-Erreichbarkeit (optional, da ICMP oft blockiert ist)
    info "Teste Netzwerk-Erreichbarkeit..."
    if ping -c 1 -W 2 "${PROXMOX_HOST}" &> /dev/null; then
        success "Proxmox Host ${PROXMOX_HOST} erreichbar (ICMP)"
    else
        warn "Proxmox Host ${PROXMOX_HOST} antwortet nicht auf Ping (ICMP evtl. blockiert)"
        info "Versuche SSH-Verbindung..."
    fi

    # SSH-Port offen (optional, da oft blockiert)
    info "Teste SSH-Port..."
    if timeout 5 bash -c "echo > /dev/tcp/${PROXMOX_HOST}/${proxmox_port}" 2>/dev/null; then
        success "SSH-Port ${proxmox_port} offen"
    else
        warn "SSH-Port ${proxmox_port} TCP-Check fehlgeschlagen (Firewall?)"
        info "Versuche direkte SSH-Verbindung..."
    fi

    # SSH-Authentifizierung
    info "Teste SSH-Authentifizierung..."

    local auth_method="${PROXMOX_AUTH_METHOD:-auto}"

    if [[ "$auth_method" == "auto" ]]; then
        # Teste SSH-Key
        local key_works=false
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "${proxmox_user}@${PROXMOX_HOST}" -p "${proxmox_port}" "exit" 2>/dev/null; then
            success "SSH-Key-Authentifizierung erfolgreich (Primär)"
            key_works=true
        else
            warn "SSH-Key-Authentifizierung fehlgeschlagen"
        fi

        # Teste Passwort-Fallback
        local password_works=false
        if [[ -n "${PROXMOX_PASSWORD:-}" ]] && command -v sshpass &> /dev/null; then
            if sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${proxmox_user}@${PROXMOX_HOST}" -p "${proxmox_port}" "exit" 2>/dev/null; then
                success "Passwort-Authentifizierung erfolgreich (Fallback)"
                password_works=true
            else
                warn "Passwort-Authentifizierung fehlgeschlagen"
            fi
        fi

        # Mindestens eine Methode muss funktionieren
        if [[ "$key_works" == false ]] && [[ "$password_works" == false ]]; then
            error "Keine Authentifizierungsmethode erfolgreich"
            info "Richte SSH-Key-Auth ein mit: ssh-copy-id ${proxmox_user}@${PROXMOX_HOST}"
            info "Oder setze PROXMOX_PASSWORD in .env"
            return
        fi
    elif [[ "$auth_method" == "password" ]]; then
        if ssh_exec "exit" 2>/dev/null; then
            success "SSH-Authentifizierung erfolgreich (Passwort)"
        else
            error "SSH-Authentifizierung fehlgeschlagen (Passwort)"
            info "Prüfe PROXMOX_PASSWORD in .env"
            return
        fi
    else
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "${proxmox_user}@${PROXMOX_HOST}" -p "${proxmox_port}" "exit" 2>/dev/null; then
            success "SSH-Authentifizierung erfolgreich (SSH-Key)"
        else
            error "SSH-Authentifizierung fehlgeschlagen (SSH-Key)"
            info "Richte SSH-Key-Auth ein mit: ssh-copy-id ${proxmox_user}@${PROXMOX_HOST}"
            info "Oder nutze PROXMOX_AUTH_METHOD=auto/password mit PROXMOX_PASSWORD"
            return
        fi
    fi

    # Proxmox Version
    info "Prüfe Proxmox Version..."
    local pve_version
    pve_version=$(ssh_exec "pveversion" 2>/dev/null | head -n1 || echo "unknown")

    if [[ "$pve_version" != "unknown" ]]; then
        success "Proxmox Version: ${pve_version}"
    else
        warn "Proxmox Version konnte nicht ermittelt werden"
    fi

    # Root-Rechte
    info "Prüfe Berechtigungen..."
    if ssh_exec "test -w /etc && echo 'ok'" 2>/dev/null | grep -q "ok"; then
        success "Root-Rechte verfügbar"
    else
        error "Keine ausreichenden Rechte (Root erforderlich)"
    fi
}

# ============================================================================
# Proxmox Ressourcen
# ============================================================================

check_proxmox_resources() {
    header "4. Proxmox Ressourcen"

    if [[ -z "${PROXMOX_HOST:-}" ]]; then
        warn "PROXMOX_HOST nicht gesetzt - überspringe Ressourcen-Check"
        return
    fi

    local proxmox_user="${PROXMOX_USER:-root}"
    local proxmox_port="${PROXMOX_PORT:-22}"

    # Storage prüfen
    info "Prüfe Storage..."
    local storage="${LXC_STORAGE:-local-lvm}"
    local required_space="${LXC_ROOTFS:-40}"

    local storage_info
    storage_info=$(ssh_exec "pvesm status -storage ${storage} 2>/dev/null | grep -v '^Name' | tail -n1" || echo "")

    if [[ -n "$storage_info" ]]; then
        success "Storage '${storage}' verfügbar"
        # pvesm status gibt Werte in KB aus
        # Format: Name Type Status Total(KB) Used(KB) Available(KB) %
        local avail_kb total_gb avail_gb used_percent
        avail_kb=$(echo "$storage_info" | awk '{print $6}')
        total_gb=$(echo "$storage_info" | awk '{printf "%.0f", $4/1024/1024}')
        avail_gb=$(echo "$storage_info" | awk '{printf "%.0f", $6/1024/1024}')
        used_percent=$(echo "$storage_info" | awk '{print $7}')

        if [[ "$avail_gb" -ge "$required_space" ]]; then
            success "Genügend Speicher verfügbar: ${avail_gb} GB von ${total_gb} GB frei (${used_percent} belegt, benötigt: ${required_space} GB)"
        else
            error "Zu wenig Speicher: ${avail_gb} GB verfügbar, ${required_space} GB benötigt"
        fi
    else
        warn "Storage '${storage}' konnte nicht geprüft werden"
    fi

    # Template prüfen
    info "Prüfe Ubuntu 24.04 Template..."
    local template_storage="${TEMPLATE_STORAGE:-local}"
    local template_check
    template_check=$(ssh_exec "pveam list ${template_storage} 2>/dev/null | grep -c 'ubuntu-24.04' || echo '0'")

    if [[ "$template_check" -gt 0 ]]; then
        success "Ubuntu 24.04 Template vorhanden"
    else
        warn "Ubuntu 24.04 Template nicht gefunden (wird automatisch heruntergeladen)"
    fi

    # Freie Container-IDs
    info "Prüfe verfügbare Container-IDs..."
    local requested_id="${LXC_ID:-200}"
    if ssh_exec "pct status ${requested_id} &>/dev/null"; then
        warn "Container-ID ${requested_id} bereits belegt (automatische Erhöhung erfolgt)"
    else
        success "Container-ID ${requested_id} verfügbar"
    fi
}

# ============================================================================
# Deployment Scripts
# ============================================================================

check_deployment_scripts() {
    header "5. Deployment Scripts"

    local script_dir
    script_dir="$(dirname "$0")"

    # deploy.sh
    if [[ -f "${script_dir}/deploy.sh" ]]; then
        if [[ -x "${script_dir}/deploy.sh" ]]; then
            success "deploy.sh vorhanden und ausführbar"
        else
            warn "deploy.sh nicht ausführbar (wird automatisch ausführbar gemacht)"
        fi
    else
        error "deploy.sh nicht gefunden"
    fi

    # setup-openclaw.sh
    if [[ -f "${script_dir}/setup-openclaw.sh" ]]; then
        if [[ -x "${script_dir}/setup-openclaw.sh" ]]; then
            success "setup-openclaw.sh vorhanden und ausführbar"
        else
            warn "setup-openclaw.sh nicht ausführbar (wird automatisch ausführbar gemacht)"
        fi
    else
        error "setup-openclaw.sh nicht gefunden"
    fi

    # Config Verzeichnis
    if [[ -d "${script_dir}/config" ]]; then
        success "Config-Verzeichnis vorhanden"
    else
        warn "Config-Verzeichnis nicht gefunden"
    fi
}

# ============================================================================
# Zusammenfassung
# ============================================================================

print_summary() {
    header "Zusammenfassung"

    if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✓ Alle Checks erfolgreich! Bereit für Deployment.${NC}"
        echo
        echo "Starte Deployment mit:"
        echo -e "  ${BLUE}bash $(dirname "$0")/deploy.sh${NC}"
        return 0
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "${YELLOW}⚠ ${WARNINGS} Warnung(en), aber Deployment sollte funktionieren.${NC}"
        echo
        echo "Starte Deployment mit:"
        echo -e "  ${BLUE}bash $(dirname "$0")/deploy.sh${NC}"
        return 0
    else
        echo -e "${RED}✗ ${ERRORS} Fehler gefunden! Bitte beheben vor Deployment.${NC}"
        [[ $WARNINGS -gt 0 ]] && echo -e "${YELLOW}⚠ ${WARNINGS} Warnung(en)${NC}"
        echo
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  OpenClaw Deployment - Validierung                         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

    check_local_requirements
    check_environment
    check_proxmox_connection
    check_proxmox_resources
    check_deployment_scripts

    echo
    print_summary
}

main "$@"
