#!/usr/bin/env bash
# ============================================================================
# Traefik Service Manager
# ============================================================================
# Purpose: Automatisches Traefik Service Management mit Zertifikatserstellung
# Version: 1.0.0
# ============================================================================

set -euo pipefail

# Konfiguration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

# Default-Werte (werden von config.yaml überschrieben)
STEP_CA_HOST="192.168.1.3"
STEP_CA_USER="root"
STEP_CA_CERT_SCRIPT="/root/create-cert2.sh"
STEP_CA_CERT_STORAGE="/srv/pki"

TRAEFIK_HOST="192.168.1.23"
TRAEFIK_USER="root"
TRAEFIK_CONFIG_PATH="/docker/volume/traefik/dynamic"
TRAEFIK_CONTAINER="traefik"

INTERNAL_DOMAIN_SUFFIX=".internal"
DEFAULT_MIDDLEWARES="redirect-https,secure"
CERT_RESOLVER="letsencrypt"

BACKUP_BEFORE_CHANGE="true"
VERIFY_CERT_CREATION="true"
RESTART_TRAEFIK="true"
ROLLBACK_ON_ERROR="true"

# Source Libraries
# shellcheck source=lib/validator.sh
source "${SCRIPT_DIR}/lib/validator.sh"
# shellcheck source=lib/cert-manager.sh
source "${SCRIPT_DIR}/lib/cert-manager.sh"
# shellcheck source=lib/traefik-config.sh
source "${SCRIPT_DIR}/lib/traefik-config.sh"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktionen
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Prüfe ob Service intern ist
is_internal_service() {
    local hostname="$1"
    [[ "$hostname" == *"$INTERNAL_DOMAIN_SUFFIX" ]]
}

# Load Config (einfaches YAML-Parsing für bash)
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Lade Konfiguration von ${CONFIG_FILE}..."
        # Einfaches Parsing - für Production evtl. yq verwenden
        # Hier verwenden wir die Defaults
    fi
}

# Erstelle Restore Point für Rollback
create_restore_point() {
    RESTORE_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    RESTORE_PATH="/tmp/traefik-restore-${RESTORE_TIMESTAMP}"

    log_info "Erstelle Restore Point: ${RESTORE_TIMESTAMP}"

    ssh "${TRAEFIK_USER}@${TRAEFIK_HOST}" "
        mkdir -p ${RESTORE_PATH}
        cd ${TRAEFIK_CONFIG_PATH} && cp *.yml ${RESTORE_PATH}/ 2>/dev/null || true
    " || {
        log_warning "Konnte Restore Point nicht vollständig erstellen"
        return 1
    }

    echo "${RESTORE_PATH}" > /tmp/traefik-restore-path.txt
    log_success "Restore Point erstellt"
    return 0
}

# Rollback zum letzten Restore Point
rollback() {
    if [[ ! -f /tmp/traefik-restore-path.txt ]]; then
        log_error "Kein Restore Point gefunden"
        return 1
    fi

    local restore_path
    restore_path=$(cat /tmp/traefik-restore-path.txt)

    log_warning "Führe Rollback durch zu ${restore_path}..."

    ssh "${TRAEFIK_USER}@${TRAEFIK_HOST}" "
        cp ${restore_path}/*.yml ${TRAEFIK_CONFIG_PATH}/
        docker restart ${TRAEFIK_CONTAINER}
    " || {
        log_error "Rollback fehlgeschlagen!"
        return 1
    }

    log_success "Rollback erfolgreich"
    rm /tmp/traefik-restore-path.txt
    return 0
}

# Dienst hinzufügen
add_service() {
    local hostname="$1"
    local backend="$2"

    echo
    log_info "=== Füge Traefik-Service hinzu ==="
    echo "Hostname: ${hostname}"
    echo "Backend:  ${backend}"
    echo

    # Validierung
    log_info "Validiere Input..."
    validate_hostname "$hostname" || return 1
    validate_backend "$backend" || return 1

    # SSH-Konnektivität prüfen
    log_info "Prüfe SSH-Verbindungen..."
    validate_ssh_connectivity "$TRAEFIK_HOST" || return 1

    # Prüfe ob Traefik läuft
    log_info "Prüfe Traefik-Status..."
    validate_traefik_running "$TRAEFIK_HOST" "$TRAEFIK_CONTAINER" || return 1

    # Prüfe ob Service bereits existiert
    if validate_hostname_not_exists "$hostname" "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH"; then
        log_success "Hostname verfügbar"
    else
        log_error "Service für ${hostname} existiert bereits!"
        return 1
    fi

    # Erstelle Restore Point
    if [[ "$BACKUP_BEFORE_CHANGE" == "true" ]]; then
        create_restore_point || {
            log_warning "Fahre ohne Restore Point fort..."
        }
    fi

    # Interne oder externe Service?
    if is_internal_service "$hostname"; then
        log_info "Erkannt: Interner Service (${INTERNAL_DOMAIN_SUFFIX})"
        add_internal_service "$hostname" "$backend" || {
            if [[ "$ROLLBACK_ON_ERROR" == "true" ]]; then
                rollback
            fi
            return 1
        }
    else
        log_info "Erkannt: Externer Service (Let's Encrypt)"
        add_external_service "$hostname" "$backend" || {
            if [[ "$ROLLBACK_ON_ERROR" == "true" ]]; then
                rollback
            fi
            return 1
        }
    fi

    echo
    log_success "=== Service erfolgreich hinzugefügt ==="
    echo
    echo "🌐 Service sollte nun erreichbar sein unter:"
    echo "   https://${hostname}"
    echo

    return 0
}

# Externe Service hinzufügen
add_external_service() {
    local hostname="$1"
    local backend="$2"

    # Generiere Config
    log_info "Generiere Traefik-Config für externen Service..."
    local config_content
    config_content=$(generate_external_service_config "$hostname" "$backend" "$DEFAULT_MIDDLEWARES" "$CERT_RESOLVER")

    # Deploy Config
    deploy_config "$hostname" "$config_content" "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH" || return 1

    # Restart Traefik
    if [[ "$RESTART_TRAEFIK" == "true" ]]; then
        restart_traefik "$TRAEFIK_HOST" "$TRAEFIK_CONTAINER" || return 1
    fi

    log_success "Externer Service konfiguriert"
    log_info "Let's Encrypt wird Zertifikat beim ersten HTTPS-Zugriff erstellen"

    return 0
}

# Interne Service hinzufügen
add_internal_service() {
    local hostname="$1"
    local backend="$2"
    local hostname_base="${hostname%$INTERNAL_DOMAIN_SUFFIX}"

    # SSH-Verbindung zu step-ca prüfen
    log_info "Prüfe Verbindung zu step-ca Server..."
    validate_ssh_connectivity "$STEP_CA_HOST" || return 1

    # Erstelle Zertifikat
    log_info "Erstelle internes Zertifikat..."
    create_step_ca_cert "$hostname" "$STEP_CA_HOST" "$STEP_CA_CERT_SCRIPT" "$STEP_CA_CERT_STORAGE" || {
        log_error "Zertifikatserstellung fehlgeschlagen"
        return 1
    }

    # Verifiziere Zertifikat-Zugriff auf Traefik
    if [[ "$VERIFY_CERT_CREATION" == "true" ]]; then
        log_info "Verifiziere Zertifikat-Zugriff auf Traefik-Server..."
        verify_cert_accessible_on_traefik "$hostname_base" "$TRAEFIK_HOST" "$STEP_CA_CERT_STORAGE" || {
            log_error "Zertifikat nicht auf Traefik-Server zugänglich"
            return 1
        }
    fi

    # Update tls.yml
    log_info "Aktualisiere tls.yml..."
    update_tls_yaml "$hostname_base" "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH" "$STEP_CA_CERT_STORAGE" || {
        log_error "Konnte tls.yml nicht aktualisieren"
        return 1
    }

    # Generiere Config (ohne certResolver)
    log_info "Generiere Traefik-Config für internen Service..."
    local middlewares="${DEFAULT_MIDDLEWARES%%,secure}"  # Entferne 'secure' für intern
    local config_content
    config_content=$(generate_internal_service_config "$hostname" "$backend" "$middlewares")

    # Deploy Config
    deploy_config "$hostname" "$config_content" "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH" || return 1

    # Restart Traefik
    if [[ "$RESTART_TRAEFIK" == "true" ]]; then
        restart_traefik "$TRAEFIK_HOST" "$TRAEFIK_CONTAINER" || return 1
    fi

    log_success "Interner Service konfiguriert"

    return 0
}

# Dienst entfernen
remove_service() {
    local hostname="$1"

    echo
    log_info "=== Entferne Traefik-Service ==="
    echo "Hostname: ${hostname}"
    echo

    # Validierung
    validate_hostname "$hostname" || return 1

    # Erstelle Restore Point
    if [[ "$BACKUP_BEFORE_CHANGE" == "true" ]]; then
        create_restore_point || {
            log_warning "Fahre ohne Restore Point fort..."
        }
    fi

    # Entferne Config
    remove_service_config "$hostname" "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH" || {
        log_error "Konnte Service-Config nicht entfernen"
        return 1
    }

    # Wenn interner Service: Entferne aus tls.yml
    if is_internal_service "$hostname"; then
        local hostname_base="${hostname%$INTERNAL_DOMAIN_SUFFIX}"
        log_info "Interner Service erkannt, entferne aus tls.yml..."
        remove_from_tls_yaml "$hostname_base" "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH" "$STEP_CA_CERT_STORAGE" || {
            log_warning "Konnte Eintrag nicht aus tls.yml entfernen"
        }
    fi

    # Restart Traefik
    if [[ "$RESTART_TRAEFIK" == "true" ]]; then
        restart_traefik "$TRAEFIK_HOST" "$TRAEFIK_CONTAINER" || return 1
    fi

    echo
    log_success "=== Service erfolgreich entfernt ==="
    echo

    return 0
}

# Liste Services auf
list_services_cmd() {
    echo
    log_info "=== Traefik Services ==="
    echo

    list_services "$TRAEFIK_HOST" "$TRAEFIK_CONFIG_PATH"

    return 0
}

# Liste Zertifikate auf
list_certificates_cmd() {
    echo
    log_info "=== Zertifikate ==="
    echo

    list_certificates "$STEP_CA_HOST" "$STEP_CA_CERT_STORAGE"

    return 0
}

# Usage
usage() {
    cat <<EOF
Traefik Service Manager v1.0.0

Usage: $0 <command> [options]

Commands:
    add        Füge einen neuen Service hinzu
    remove     Entferne einen Service
    list       Liste alle Services auf
    certs      Liste alle Zertifikate auf

Options für 'add':
    --hostname <FQDN>     Service-Hostname (z.B. api.example.com oder myapp.internal)
    --backend <URL>       Backend-URL (z.B. https://192.168.1.50:8080)

Options für 'remove':
    --hostname <FQDN>     Service-Hostname

Beispiele:
    # Externer Service (Let's Encrypt)
    $0 add --hostname api.diefamilielang.de --backend https://192.168.1.50:8080

    # Interner Service (step-ca Zertifikat)
    $0 add --hostname myapp.internal --backend https://192.168.1.51:3000

    # Service entfernen
    $0 remove --hostname api.diefamilielang.de

    # Services auflisten
    $0 list

    # Zertifikate auflisten
    $0 certs

EOF
}

# Main
main() {
    # Load Config
    load_config

    # Parse Command
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        add)
            local hostname=""
            local backend=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --hostname)
                        hostname="$2"
                        shift 2
                        ;;
                    --backend)
                        backend="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unbekannte Option: $1"
                        usage
                        exit 1
                        ;;
                esac
            done

            if [[ -z "$hostname" ]] || [[ -z "$backend" ]]; then
                log_error "Hostname und Backend sind erforderlich"
                usage
                exit 1
            fi

            add_service "$hostname" "$backend"
            ;;

        remove)
            local hostname=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --hostname)
                        hostname="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unbekannte Option: $1"
                        usage
                        exit 1
                        ;;
                esac
            done

            if [[ -z "$hostname" ]]; then
                log_error "Hostname ist erforderlich"
                usage
                exit 1
            fi

            remove_service "$hostname"
            ;;

        list)
            list_services_cmd
            ;;

        certs)
            list_certificates_cmd
            ;;

        -h|--help|help)
            usage
            exit 0
            ;;

        *)
            log_error "Unbekannter Befehl: $command"
            usage
            exit 1
            ;;
    esac
}

# Run Main
main "$@"
