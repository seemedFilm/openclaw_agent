#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw LXC Deployment Script für Proxmox
# ============================================================================
# Dieses Script erstellt einen LXC-Container auf Proxmox und installiert
# OpenClaw mit allen Abhängigkeiten.
# ============================================================================

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# ============================================================================
# Konfiguration
# ============================================================================

# Lade .env falls vorhanden
if [[ -f "$(dirname "$0")/config/.env" ]]; then
    set -a  # Automatisch exportieren
    source "$(dirname "$0")/config/.env"
    set +a
fi

# Proxmox Verbindung
PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.4}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_PORT="${PROXMOX_PORT:-22}"
PROXMOX_AUTH_METHOD="${PROXMOX_AUTH_METHOD:-auto}"
PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-}"

# LXC Container Einstellungen
LXC_ID="${LXC_ID:-200}"  # Container ID (automatisch erhöhen falls belegt)
LXC_HOSTNAME="${LXC_HOSTNAME:-openclaw-agents}"
LXC_CORES="${LXC_CORES:-4}"
LXC_MEMORY="${LXC_MEMORY:-8192}"  # MB
LXC_SWAP="${LXC_SWAP:-2048}"      # MB
LXC_ROOTFS="${LXC_ROOTFS:-40}"    # GB
LXC_STORAGE="${LXC_STORAGE:-local-lvm}"
LXC_NETWORK_BRIDGE="${LXC_NETWORK_BRIDGE:-vmbr0}"
LXC_NETWORK_IP="${LXC_NETWORK_IP:-dhcp}"  # oder z.B. 192.168.1.100/24
LXC_GATEWAY="${LXC_GATEWAY:-}"

# OS Template
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
TEMPLATE_NAME="ubuntu-24.04-standard"
TEMPLATE_FILE="${TEMPLATE_NAME}_24.04-2_amd64.tar.zst"

# SSH Key für OpenClaw Container
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"

# ============================================================================
# SSH Wrapper-Funktionen
# ============================================================================

# SSH-Verbindung mit gewählter Authentifizierungsmethode
ssh_exec() {
    local auth_method="$PROXMOX_AUTH_METHOD"

    # Auto-Modus: Versuche erst Key, dann Passwort
    if [[ "$auth_method" == "auto" ]]; then
        # Versuche SSH-Key
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "${PROXMOX_PORT}" "${PROXMOX_USER}@${PROXMOX_HOST}" "$@" 2>/dev/null; then
            return 0
        fi

        # Key fehlgeschlagen, versuche Passwort als Fallback
        if [[ -n "$PROXMOX_PASSWORD" ]] && command -v sshpass &> /dev/null; then
            sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -p "${PROXMOX_PORT}" "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
            return $?
        fi

        # Beide Methoden fehlgeschlagen
        return 1
    fi

    # Nur Passwort
    if [[ "$auth_method" == "password" ]]; then
        if [[ -z "$PROXMOX_PASSWORD" ]]; then
            error "PROXMOX_PASSWORD nicht gesetzt (erforderlich bei AUTH_METHOD=password)"
            exit 1
        fi
        if ! command -v sshpass &> /dev/null; then
            error "sshpass nicht installiert (erforderlich für Passwort-Authentifizierung)"
            echo "Installation:"
            echo "  Ubuntu/Debian: sudo apt install sshpass"
            echo "  macOS: brew install hudochenkov/sshpass/sshpass"
            echo "  Windows (WSL): sudo apt install sshpass"
            exit 1
        fi
        sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -p "${PROXMOX_PORT}" "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
        return $?
    fi

    # Nur Key (Standard)
    ssh -p "${PROXMOX_PORT}" "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
}

# SCP mit gewählter Authentifizierungsmethode
scp_exec() {
    local auth_method="$PROXMOX_AUTH_METHOD"

    # Auto-Modus: Versuche erst Key, dann Passwort
    if [[ "$auth_method" == "auto" ]]; then
        # Versuche SSH-Key
        if scp -o BatchMode=yes -o ConnectTimeout=5 -P "${PROXMOX_PORT}" "$@" 2>/dev/null; then
            return 0
        fi

        # Key fehlgeschlagen, versuche Passwort als Fallback
        if [[ -n "$PROXMOX_PASSWORD" ]] && command -v sshpass &> /dev/null; then
            sshpass -p "$PROXMOX_PASSWORD" scp -o StrictHostKeyChecking=no -P "${PROXMOX_PORT}" "$@"
            return $?
        fi

        # Beide Methoden fehlgeschlagen
        return 1
    fi

    # Nur Passwort
    if [[ "$auth_method" == "password" ]]; then
        if [[ -z "$PROXMOX_PASSWORD" ]]; then
            error "PROXMOX_PASSWORD nicht gesetzt (erforderlich bei AUTH_METHOD=password)"
            exit 1
        fi
        if ! command -v sshpass &> /dev/null; then
            error "sshpass nicht installiert"
            exit 1
        fi
        sshpass -p "$PROXMOX_PASSWORD" scp -o StrictHostKeyChecking=no -P "${PROXMOX_PORT}" "$@"
        return $?
    fi

    # Nur Key (Standard)
    scp -P "${PROXMOX_PORT}" "$@"
}

# ============================================================================
# Validierung
# ============================================================================

validate_requirements() {
    log "Validiere Anforderungen..."

    if [[ -z "$PROXMOX_HOST" ]]; then
        error "PROXMOX_HOST nicht gesetzt. Bitte setze die Umgebungsvariable."
        echo "Beispiel: export PROXMOX_HOST='192.168.1.10'"
        exit 1
    fi

    # Prüfe Authentifizierungsmethode
    if [[ "$PROXMOX_AUTH_METHOD" == "password" ]]; then
        log "Verwende Passwort-Authentifizierung"
        if [[ -z "$PROXMOX_PASSWORD" ]]; then
            error "PROXMOX_PASSWORD nicht gesetzt"
            exit 1
        fi
        if ! command -v sshpass &> /dev/null; then
            error "sshpass nicht installiert"
            echo "Installation: sudo apt install sshpass"
            exit 1
        fi
    elif [[ "$PROXMOX_AUTH_METHOD" == "auto" ]]; then
        log "Verwende Auto-Authentifizierung (SSH-Key mit Passwort-Fallback)"
        if [[ -n "$PROXMOX_PASSWORD" ]] && command -v sshpass &> /dev/null; then
            log "Fallback verfügbar: Passwort-Authentifizierung"
        else
            log "Kein Fallback: Nur SSH-Key verfügbar"
        fi
    else
        log "Verwende SSH-Key-Authentifizierung"
    fi

    # Prüfe SSH-Zugriff
    if ! ssh_exec "exit" 2>/dev/null; then
        error "Keine SSH-Verbindung zu ${PROXMOX_USER}@${PROXMOX_HOST}:${PROXMOX_PORT} möglich"
        echo "Bitte stelle sicher, dass:"
        echo "  1. Der Proxmox Host erreichbar ist"
        if [[ "$PROXMOX_AUTH_METHOD" == "key" ]]; then
            echo "  2. SSH-Key-Authentifizierung konfiguriert ist (ssh-copy-id)"
        else
            echo "  2. Das Passwort korrekt ist"
        fi
        echo "  3. Der Benutzer Root-Rechte hat"
        exit 1
    fi

    success "SSH-Verbindung zu Proxmox erfolgreich"
}

# ============================================================================
# Proxmox Template Check
# ============================================================================

ensure_template() {
    log "Prüfe Ubuntu 24.04 Template..."

    local template_check
    template_check=$(ssh_exec "pveam list ${TEMPLATE_STORAGE} | grep -c '${TEMPLATE_FILE}' || true")

    if [[ "$template_check" -eq 0 ]]; then
        warn "Template ${TEMPLATE_FILE} nicht gefunden. Lade herunter..."
        ssh_exec "pveam download ${TEMPLATE_STORAGE} ${TEMPLATE_FILE}"
        success "Template heruntergeladen"
    else
        success "Template bereits vorhanden"
    fi
}

# ============================================================================
# LXC Container Erstellung
# ============================================================================

find_free_ctid() {
    # Log zu stderr damit es nicht in Command-Substitution landet
    log "Suche freie Container-ID ab ${LXC_ID}..." >&2

    local id=$LXC_ID
    while ssh_exec "pct status $id &>/dev/null"; do
        id=$((id + 1))
    done

    echo "$id"
}

create_lxc_container() {
    local ctid
    ctid=$(find_free_ctid)

    log "Erstelle LXC Container mit ID ${ctid}..." >&2

    # Netzwerk-Konfiguration
    local network_config="name=eth0,bridge=${LXC_NETWORK_BRIDGE}"
    if [[ "$LXC_NETWORK_IP" != "dhcp" ]]; then
        network_config="${network_config},ip=${LXC_NETWORK_IP}"
        [[ -n "$LXC_GATEWAY" ]] && network_config="${network_config},gw=${LXC_GATEWAY}"
    else
        network_config="${network_config},ip=dhcp"
    fi

    # Container erstellen
    ssh_exec <<EOF
pct create ${ctid} ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_FILE} \\
    --hostname ${LXC_HOSTNAME} \\
    --cores ${LXC_CORES} \\
    --memory ${LXC_MEMORY} \\
    --swap ${LXC_SWAP} \\
    --rootfs ${LXC_STORAGE}:${LXC_ROOTFS} \\
    --net0 ${network_config} \\
    --nameserver 8.8.8.8 \\
    --nameserver 8.8.4.4 \\
    --features nesting=1,keyctl=1 \\
    --unprivileged 1 \\
    --onboot 1 \\
    --start 1
EOF

    success "Container ${ctid} erstellt und gestartet"
    echo "$ctid"
}

# ============================================================================
# Container Setup
# ============================================================================

wait_for_container() {
    local ctid=$1
    log "Warte auf Container-Initialisierung..."

    for i in {1..30}; do
        if ssh_exec "pct exec ${ctid} -- test -f /var/lib/dpkg/lock-frontend" 2>/dev/null; then
            sleep 2
        else
            success "Container bereit"
            return 0
        fi
        sleep 2
    done

    error "Container-Initialisierung Timeout"
    return 1
}

setup_container() {
    local ctid=$1
    log "Konfiguriere Container..."

    # Setup-Script mit korrekten Unix Line-Endings kopieren
    local setup_script="$(dirname "$0")/setup-openclaw.sh"
    local temp_script="/tmp/setup-openclaw-${ctid}.sh"

    # Konvertiere zu Unix-Format falls nötig und kopiere
    if command -v dos2unix &> /dev/null; then
        log "Konvertiere Script zu Unix Line-Endings..."
        dos2unix -k "${setup_script}" 2>/dev/null || true
    fi

    scp_exec "${setup_script}" "${PROXMOX_USER}@${PROXMOX_HOST}:${temp_script}" 2>&1 | grep -v "Pseudo-terminal" || true

    # Setup ausführen
    ssh_exec 2>&1 <<EOF | grep -v "Pseudo-terminal" | grep -v "The programs included" | grep -v "individual files" | grep -v "Debian GNU/Linux comes" | grep -v "permitted by law" || true
# Sicherheitshalber nochmal konvertieren auf Proxmox
sed -i 's/\r\$//' ${temp_script}
pct push ${ctid} ${temp_script} /root/setup-openclaw.sh
pct exec ${ctid} -- chmod +x /root/setup-openclaw.sh
pct exec ${ctid} -- /root/setup-openclaw.sh
rm ${temp_script}
EOF

    success "Container-Setup abgeschlossen"
}

get_container_ip() {
    local ctid=$1
    log "Ermittle Container-IP..." >&2

    local ip
    ip=$(ssh_exec "pct exec ${ctid} -- hostname -I | awk '{print \$1}'")

    echo "$ip"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log "Starte OpenClaw LXC Deployment..."
    echo

    validate_requirements
    ensure_template

    local ctid
    ctid=$(create_lxc_container)

    wait_for_container "$ctid"
    setup_container "$ctid"

    local container_ip
    container_ip=$(get_container_ip "$ctid")

    echo
    success "=================================================================================="
    success "OpenClaw LXC Container erfolgreich erstellt!"
    success "=================================================================================="
    echo
    echo "Container Details:"
    echo "  ID:       ${ctid}"
    echo "  Hostname: ${LXC_HOSTNAME}"
    echo "  IP:       ${container_ip}"
    echo "  CPU:      ${LXC_CORES} Cores"
    echo "  RAM:      ${LXC_MEMORY} MB"
    echo "  Disk:     ${LXC_ROOTFS} GB"
    echo
    echo "SSH Zugriff:"
    echo "  ssh root@${container_ip}"
    echo
    echo "Nächste Schritte:"
    echo "  1. SSH in Container: ssh root@${container_ip}"
    echo "  2. OpenClaw testen: openclaw --version"
    echo "  3. OpenClaw onboarding: openclaw onboard"
    echo "  4. Agents konfigurieren (siehe ../agents/)"
    echo

    # Speichere Container-Info
    cat > "$(dirname "$0")/container-info.txt" <<EOF
CONTAINER_ID=${ctid}
CONTAINER_HOSTNAME=${LXC_HOSTNAME}
CONTAINER_IP=${container_ip}
CREATED=$(date -Iseconds)
EOF

    success "Container-Info gespeichert in: $(dirname "$0")/container-info.txt"
}

# Führe Main aus
main "$@"
