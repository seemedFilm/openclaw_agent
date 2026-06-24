#!/usr/bin/env bash
# ============================================================================
# Pi-hole DNS Manager Library
# ============================================================================
# Purpose: DNS-Management via SSH (Pi-hole v5/v6 kompatibel)
# ============================================================================

# Lade Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.yaml"

# Parse Config-Werte
get_config_value() {
    local key="$1"
    grep "^[[:space:]]*${key}:" "$CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?.*/\1/' | head -1
}

PIHOLE_HOST=$(get_config_value "host")
PIHOLE_SSH_USER=$(get_config_value "ssh_user")
PIHOLE_CUSTOM_LIST=$(get_config_value "custom_list")
TRAEFIK_IP=$(get_config_value "traefik_ip")
ACCESS_METHOD=$(get_config_value "access_method")

# Default values
PIHOLE_SSH_USER="${PIHOLE_SSH_USER:-root}"
PIHOLE_CUSTOM_LIST="${PIHOLE_CUSTOM_LIST:-/etc/pihole/custom.list}"
ACCESS_METHOD="${ACCESS_METHOD:-ssh}"

# Füge DNS-Record hinzu (via SSH)
pihole_add_dns_record() {
    local domain="$1"
    local ip="$2"

    echo "   Füge DNS-Record hinzu: ${domain} → ${ip}"

    # Prüfe ob Record bereits existiert
    if ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "grep -q '^${ip} ${domain}$' ${PIHOLE_CUSTOM_LIST} 2>/dev/null"; then
        echo "   ⚠ DNS-Record existiert bereits"
        return 0  # Nicht als Fehler werten
    fi

    # Füge Record hinzu
    if ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "echo '${ip} ${domain}' >> ${PIHOLE_CUSTOM_LIST}" 2>/dev/null; then
        # Reload DNS
        if ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "pihole restartdns reload" >/dev/null 2>&1; then
            echo "   ✓ DNS-Record erfolgreich hinzugefügt"
            return 0
        else
            echo "   ERROR: DNS-Reload fehlgeschlagen" >&2
            return 1
        fi
    else
        echo "   ERROR: Konnte DNS-Record nicht schreiben" >&2
        return 1
    fi
}

# Entferne DNS-Record (via SSH)
pihole_remove_dns_record() {
    local domain="$1"

    echo "   Entferne DNS-Record: ${domain}"

    # Prüfe ob Record existiert
    if ! ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "grep -q ' ${domain}$' ${PIHOLE_CUSTOM_LIST} 2>/dev/null"; then
        echo "   ⚠ DNS-Record existiert nicht"
        return 0  # Nicht als Fehler werten
    fi

    # Entferne Record (alle Zeilen mit diesem Domain)
    if ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "sed -i '/ ${domain}$/d' ${PIHOLE_CUSTOM_LIST}" 2>/dev/null; then
        # Reload DNS
        if ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "pihole restartdns reload" >/dev/null 2>&1; then
            echo "   ✓ DNS-Record erfolgreich entfernt"
            return 0
        else
            echo "   ERROR: DNS-Reload fehlgeschlagen" >&2
            return 1
        fi
    else
        echo "   ERROR: Konnte DNS-Record nicht entfernen" >&2
        return 1
    fi
}

# Liste alle Custom-DNS-Records auf
pihole_list_dns_records() {
    echo "📋 Pi-hole Custom DNS Records:"

    local records
    records=$(ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "cat ${PIHOLE_CUSTOM_LIST} 2>/dev/null" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        if [[ -z "$records" ]]; then
            echo "  (keine Custom-DNS-Records vorhanden)"
        else
            echo "$records" | while read -r ip domain; do
                [[ -n "$ip" && -n "$domain" ]] && echo "  ${domain} → ${ip}"
            done
        fi
        return 0
    else
        echo "ERROR: Konnte DNS-Records nicht lesen (Exit: $exit_code)" >&2
        return 1
    fi
}

# Prüfe ob DNS-Record existiert
pihole_check_dns_record() {
    local domain="$1"

    if ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "grep -q ' ${domain}$' ${PIHOLE_CUSTOM_LIST} 2>/dev/null"; then
        return 0  # Existiert
    else
        return 1  # Existiert nicht
    fi
}

# Teste Pi-hole SSH-Verbindung
pihole_test_connection() {
    echo "🔗 Teste Pi-hole SSH-Verbindung..."
    echo "   Host: ${PIHOLE_HOST}"
    echo "   User: ${PIHOLE_SSH_USER}"
    echo "   Custom-List: ${PIHOLE_CUSTOM_LIST}"
    echo "   Methode: ${ACCESS_METHOD}"

    # Test SSH-Verbindung
    if ! ssh -T -o ConnectTimeout=5 "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "true" 2>/dev/null; then
        echo "   ✗ SSH-Verbindung fehlgeschlagen" >&2
        echo "   Tipp: ssh-copy-id ${PIHOLE_SSH_USER}@${PIHOLE_HOST}" >&2
        return 1
    fi
    echo "   ✓ SSH-Verbindung OK"

    # Test custom.list Zugriff
    if ! ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "test -f ${PIHOLE_CUSTOM_LIST}" 2>/dev/null; then
        echo "   ✗ ${PIHOLE_CUSTOM_LIST} nicht gefunden" >&2
        return 1
    fi
    echo "   ✓ custom.list zugreifbar"

    # Test pihole Command
    if ! ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "which pihole" >/dev/null 2>&1; then
        echo "   ✗ pihole Command nicht gefunden" >&2
        return 1
    fi
    echo "   ✓ pihole Command verfügbar"

    # Zeige Pi-hole Version
    local version
    version=$(ssh -T "${PIHOLE_SSH_USER}@${PIHOLE_HOST}" "pihole -v 2>/dev/null | head -1" 2>&1)
    echo "   Version: ${version}"

    return 0
}

# Export Funktionen
export -f pihole_add_dns_record
export -f pihole_remove_dns_record
export -f pihole_list_dns_records
export -f pihole_check_dns_record
export -f pihole_test_connection
