#!/usr/bin/env bash
# ============================================================================
# Pi-hole DNS Manager - OpenClaw Skill
# ============================================================================
# Purpose: Verwaltet DNS-Einträge in Pi-hole für Traefik-Services
# Usage: pihole-dns-manager.sh <command> [options]
# ============================================================================

set -euo pipefail

# Source library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/pihole-api.sh
source "${SCRIPT_DIR}/lib/pihole-api.sh"

# Zeige Hilfe
show_help() {
    cat << EOF
Pi-hole DNS Manager - OpenClaw Skill

USAGE:
    pihole-dns-manager.sh <command> [options]

COMMANDS:
    add         Füge DNS-Record hinzu
    remove      Entferne DNS-Record
    list        Liste alle Custom-DNS-Records
    check       Prüfe ob DNS-Record existiert
    test        Teste Pi-hole API-Verbindung

OPTIONS:
    --hostname <name>   Hostname (z.B. myapp.internal)
    --ip <ip>           IP-Adresse (optional, default: Traefik IP aus config.yaml)
    --help              Zeige diese Hilfe

EXAMPLES:
    # DNS-Record hinzufügen (IP = Traefik)
    pihole-dns-manager.sh add --hostname myapp.internal

    # DNS-Record mit custom IP
    pihole-dns-manager.sh add --hostname myapp.internal --ip 192.168.1.100

    # DNS-Record entfernen
    pihole-dns-manager.sh remove --hostname myapp.internal

    # Alle Records auflisten
    pihole-dns-manager.sh list

    # Prüfen ob Record existiert
    pihole-dns-manager.sh check --hostname myapp.internal

    # API-Verbindung testen
    pihole-dns-manager.sh test

ENVIRONMENT:
    PIHOLE_API_TOKEN    Pi-hole API-Token (empfohlen)

CONFIGURATION:
    ${SCRIPT_DIR}/config.yaml

EOF
}

# Parse Arguments
COMMAND=""
HOSTNAME=""
IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        add|remove|list|check|test)
            COMMAND="$1"
            shift
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --ip)
            IP="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "ERROR: Unbekanntes Argument: $1" >&2
            echo "Verwende --help für Hilfe" >&2
            exit 1
            ;;
    esac
done

# Validiere Command
if [[ -z "$COMMAND" ]]; then
    echo "ERROR: Kein Command angegeben" >&2
    echo "Verwende --help für Hilfe" >&2
    exit 1
fi

# Execute Command
case "$COMMAND" in
    add)
        if [[ -z "$HOSTNAME" ]]; then
            echo "ERROR: --hostname erforderlich für 'add'" >&2
            exit 1
        fi

        # Default IP = Traefik
        if [[ -z "$IP" ]]; then
            IP="$TRAEFIK_IP"
        fi

        echo "🔧 Füge Pi-hole DNS-Record hinzu..."
        echo "   Hostname: ${HOSTNAME}"
        echo "   IP: ${IP}"

        if pihole_add_dns_record "$HOSTNAME" "$IP"; then
            echo "✓ DNS-Record erfolgreich hinzugefügt"
            exit 0
        else
            echo "✗ Fehler beim Hinzufügen des DNS-Records" >&2
            exit 1
        fi
        ;;

    remove)
        if [[ -z "$HOSTNAME" ]]; then
            echo "ERROR: --hostname erforderlich für 'remove'" >&2
            exit 1
        fi

        echo "🗑️  Entferne Pi-hole DNS-Record..."
        echo "   Hostname: ${HOSTNAME}"

        if pihole_remove_dns_record "$HOSTNAME"; then
            echo "✓ DNS-Record erfolgreich entfernt"
            exit 0
        else
            echo "✗ Fehler beim Entfernen des DNS-Records" >&2
            exit 1
        fi
        ;;

    list)
        pihole_list_dns_records
        exit $?
        ;;

    check)
        if [[ -z "$HOSTNAME" ]]; then
            echo "ERROR: --hostname erforderlich für 'check'" >&2
            exit 1
        fi

        echo "🔍 Prüfe DNS-Record: ${HOSTNAME}"

        if pihole_check_dns_record "$HOSTNAME"; then
            echo "✓ DNS-Record existiert"
            exit 0
        else
            echo "✗ DNS-Record existiert nicht"
            exit 1
        fi
        ;;

    test)
        pihole_test_connection
        exit $?
        ;;

    *)
        echo "ERROR: Unbekannter Command: $COMMAND" >&2
        exit 1
        ;;
esac
