#!/usr/bin/env bash
# ============================================================================
# Pi-hole API Library
# ============================================================================
# Purpose: Wrapper für Pi-hole API-Calls
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
PIHOLE_API_ENDPOINT=$(get_config_value "api_endpoint")
PIHOLE_API_TOKEN_ENV=$(get_config_value "api_token_env")
TRAEFIK_IP=$(get_config_value "traefik_ip")
API_TIMEOUT=$(get_config_value "api_request")

# Hole API-Token aus Environment oder Config
if [[ -n "${!PIHOLE_API_TOKEN_ENV}" ]]; then
    PIHOLE_API_TOKEN="${!PIHOLE_API_TOKEN_ENV}"
else
    PIHOLE_API_TOKEN=$(get_config_value "api_token")
fi

# Validierung
if [[ -z "$PIHOLE_API_TOKEN" ]]; then
    echo "ERROR: Pi-hole API Token nicht gefunden!" >&2
    echo "       Setze Environment-Variable: export ${PIHOLE_API_TOKEN_ENV}=<token>" >&2
    exit 1
fi

# Füge DNS-Record hinzu
pihole_add_dns_record() {
    local domain="$1"
    local ip="$2"

    echo "   Füge DNS-Record hinzu: ${domain} → ${ip}"

    local url="${PIHOLE_API_ENDPOINT}?customdns&action=add&domain=${domain}&ip=${ip}&token=${PIHOLE_API_TOKEN}"

    local response
    response=$(curl -sSf --max-time "$API_TIMEOUT" "$url" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Prüfe Response
        if echo "$response" | grep -q '"success".*true'; then
            echo "   ✓ DNS-Record erfolgreich hinzugefügt"
            return 0
        elif echo "$response" | grep -q "already exists"; then
            echo "   ⚠ DNS-Record existiert bereits"
            return 0  # Nicht als Fehler werten
        else
            echo "   ERROR: Unerwartete API-Response: $response" >&2
            return 1
        fi
    else
        echo "   ERROR: Pi-hole API nicht erreichbar (Exit: $exit_code)" >&2
        return 1
    fi
}

# Entferne DNS-Record
pihole_remove_dns_record() {
    local domain="$1"

    echo "   Entferne DNS-Record: ${domain}"

    local url="${PIHOLE_API_ENDPOINT}?customdns&action=delete&domain=${domain}&token=${PIHOLE_API_TOKEN}"

    local response
    response=$(curl -sSf --max-time "$API_TIMEOUT" "$url" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        if echo "$response" | grep -q '"success".*true'; then
            echo "   ✓ DNS-Record erfolgreich entfernt"
            return 0
        elif echo "$response" | grep -q "does not exist"; then
            echo "   ⚠ DNS-Record existiert nicht"
            return 0  # Nicht als Fehler werten
        else
            echo "   ERROR: Unerwartete API-Response: $response" >&2
            return 1
        fi
    else
        echo "   ERROR: Pi-hole API nicht erreichbar (Exit: $exit_code)" >&2
        return 1
    fi
}

# Liste alle Custom-DNS-Records auf
pihole_list_dns_records() {
    echo "📋 Pi-hole Custom DNS Records:"

    local url="${PIHOLE_API_ENDPOINT}?customdns&action=get&token=${PIHOLE_API_TOKEN}"

    local response
    response=$(curl -sSf --max-time "$API_TIMEOUT" "$url" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Parse JSON (einfaches grep/sed - für komplexere Parsing jq verwenden)
        echo "$response" | grep -o '"[^"]*"' | sed 's/"//g' | while read -r line; do
            echo "  $line"
        done
        return 0
    else
        echo "ERROR: Pi-hole API nicht erreichbar (Exit: $exit_code)" >&2
        return 1
    fi
}

# Prüfe ob DNS-Record existiert
pihole_check_dns_record() {
    local domain="$1"

    local url="${PIHOLE_API_ENDPOINT}?customdns&action=get&token=${PIHOLE_API_TOKEN}"

    local response
    response=$(curl -sSf --max-time "$API_TIMEOUT" "$url" 2>&1)

    if echo "$response" | grep -q "$domain"; then
        return 0  # Existiert
    else
        return 1  # Existiert nicht
    fi
}

# Teste Pi-hole API-Verbindung
pihole_test_connection() {
    echo "🔗 Teste Pi-hole API-Verbindung..."
    echo "   Host: ${PIHOLE_HOST}"
    echo "   Endpoint: ${PIHOLE_API_ENDPOINT}"

    local url="${PIHOLE_API_ENDPOINT}?status&token=${PIHOLE_API_TOKEN}"

    local response
    response=$(curl -sSf --max-time "$API_TIMEOUT" "$url" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "   ✓ Pi-hole API erreichbar"
        echo "   Response: $response"
        return 0
    else
        echo "   ✗ Pi-hole API nicht erreichbar (Exit: $exit_code)" >&2
        echo "   Error: $response" >&2
        return 1
    fi
}

# Export Funktionen
export -f pihole_add_dns_record
export -f pihole_remove_dns_record
export -f pihole_list_dns_records
export -f pihole_check_dns_record
export -f pihole_test_connection
