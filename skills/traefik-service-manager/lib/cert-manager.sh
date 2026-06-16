#!/usr/bin/env bash
# ============================================================================
# Certificate Manager Library für Traefik Service Manager
# ============================================================================
# Purpose: Zertifikatserstellung und -verwaltung via step-ca
# ============================================================================

# Source validator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./validator.sh
source "${SCRIPT_DIR}/validator.sh"

# Erstelle Zertifikat via step-ca
create_step_ca_cert() {
    local hostname="$1"
    local step_ca_host="${2:-192.168.1.3}"
    local cert_script="${3:-/root/create-cert2.sh}"
    local cert_storage="${4:-/srv/pki}"

    echo "🔐 Erstelle Zertifikat für ${hostname}..."

    # Extrahiere Basis-Hostname (ohne .internal)
    local hostname_base="${hostname%.internal}"

    echo "   Host: ${step_ca_host}"
    echo "   Script: ${cert_script}"
    echo "   Hostname (für Script): ${hostname_base}"

    # SSH-Verbindung testen
    if ! validate_ssh_connectivity "$step_ca_host" 10; then
        echo "ERROR: Keine SSH-Verbindung zu step-ca Server ${step_ca_host}" >&2
        return 1
    fi

    # Prüfe ob Script existiert
    if ! ssh root@"$step_ca_host" "test -f ${cert_script}" 2>/dev/null; then
        echo "ERROR: Zertifikats-Script nicht gefunden: ${cert_script} auf ${step_ca_host}" >&2
        return 1
    fi

    # Führe Zertifikats-Script aus
    echo "   Führe aus: ${cert_script} ${hostname_base}"
    if ! ssh root@"$step_ca_host" "${cert_script} ${hostname_base}" 2>&1 | sed 's/^/   /'; then
        echo "ERROR: Zertifikatserstellung fehlgeschlagen" >&2
        return 1
    fi

    echo "✓ Zertifikats-Script ausgeführt"

    # Kurze Pause für Datei-Synchronisation
    sleep 2

    # Verifiziere Zertifikat
    if verify_cert_exists "$hostname_base" "$step_ca_host" "$cert_storage"; then
        echo "✓ Zertifikat erfolgreich erstellt: ${cert_storage}/${hostname_base}/"
        return 0
    else
        echo "ERROR: Zertifikat wurde nicht erstellt" >&2
        return 1
    fi
}

# Verifiziere ob Zertifikat existiert
verify_cert_exists() {
    local hostname_base="$1"
    local step_ca_host="${2:-192.168.1.3}"
    local cert_storage="${3:-/srv/pki}"

    local cert_path="${cert_storage}/${hostname_base}"
    local required_files=("fullchain.crt" "${hostname_base}.crt" "${hostname_base}.key")

    echo "   Verifiziere Zertifikat auf ${step_ca_host}..."

    # Prüfe ob Verzeichnis existiert
    if ! ssh root@"$step_ca_host" "test -d ${cert_path}" 2>/dev/null; then
        echo "ERROR: Zertifikats-Verzeichnis nicht gefunden: ${cert_path}" >&2
        return 1
    fi

    # Prüfe alle erforderlichen Dateien
    for file in "${required_files[@]}"; do
        if ! ssh root@"$step_ca_host" "test -f ${cert_path}/${file}" 2>/dev/null; then
            echo "ERROR: Zertifikats-Datei fehlt: ${cert_path}/${file}" >&2
            return 1
        fi
        echo "   ✓ ${file}"
    done

    return 0
}

# Verifiziere Zertifikat-Zugriff auf Traefik-Server
verify_cert_accessible_on_traefik() {
    local hostname_base="$1"
    local traefik_host="${2:-192.168.1.23}"
    local cert_storage="${3:-/srv/pki}"

    local cert_path="${cert_storage}/${hostname_base}"

    echo "   Verifiziere Zertifikat-Zugriff auf Traefik-Server ${traefik_host}..."

    # Prüfe SSH-Verbindung
    if ! validate_ssh_connectivity "$traefik_host" 10; then
        echo "ERROR: Keine SSH-Verbindung zu Traefik-Server ${traefik_host}" >&2
        return 1
    fi

    # Prüfe Mount-Zugriff
    if ! ssh root@"$traefik_host" "test -d ${cert_path}" 2>/dev/null; then
        echo "ERROR: Zertifikats-Verzeichnis nicht auf Traefik-Server zugänglich: ${cert_path}" >&2
        echo "       Prüfe Proxmox Bind Mount von /srv/pki" >&2
        return 1
    fi

    # Prüfe Dateien
    local required_files=("fullchain.crt" "${hostname_base}.key")
    for file in "${required_files[@]}"; do
        if ! ssh root@"$traefik_host" "test -f ${cert_path}/${file}" 2>/dev/null; then
            echo "ERROR: Zertifikats-Datei nicht auf Traefik-Server: ${cert_path}/${file}" >&2
            return 1
        fi
    done

    echo "   ✓ Zertifikat auf Traefik-Server zugänglich"
    return 0
}

# Liste alle Zertifikate auf
list_certificates() {
    local step_ca_host="${1:-192.168.1.3}"
    local cert_storage="${2:-/srv/pki}"

    echo "📋 Zertifikate auf ${step_ca_host}:"
    echo

    # Liste Verzeichnisse in /srv/pki
    ssh root@"$step_ca_host" "
        cd ${cert_storage} 2>/dev/null || exit 1
        for dir in */; do
            if [[ -d \"\$dir\" ]]; then
                hostname=\${dir%/}
                echo \"  \$hostname\"

                # Prüfe Dateien
                if [[ -f \"\${dir}fullchain.crt\" ]]; then
                    # Zeige Ablaufdatum
                    expiry=\$(openssl x509 -in \"\${dir}fullchain.crt\" -noout -enddate 2>/dev/null | cut -d= -f2)
                    echo \"    Ablauf: \$expiry\"
                else
                    echo \"    ⚠ fullchain.crt fehlt\"
                fi
                echo
            fi
        done
    " 2>/dev/null || {
        echo "ERROR: Konnte Zertifikate nicht auflisten" >&2
        return 1
    }

    return 0
}

# Prüfe Zertifikats-Ablauf
check_cert_expiry() {
    local hostname_base="$1"
    local step_ca_host="${2:-192.168.1.3}"
    local cert_storage="${3:-/srv/pki}"
    local warn_days="${4:-30}"

    local cert_file="${cert_storage}/${hostname_base}/fullchain.crt"

    # Hole Ablaufdatum
    local expiry_date
    expiry_date=$(ssh root@"$step_ca_host" "openssl x509 -in ${cert_file} -noout -enddate 2>/dev/null" | cut -d= -f2)

    if [[ -z "$expiry_date" ]]; then
        echo "ERROR: Konnte Ablaufdatum nicht ermitteln" >&2
        return 1
    fi

    # Konvertiere zu Unix-Timestamp
    local expiry_ts
    expiry_ts=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)

    local now_ts
    now_ts=$(date +%s)

    local days_until_expiry=$(( (expiry_ts - now_ts) / 86400 ))

    echo "Zertifikat: ${hostname_base}"
    echo "Ablauf: ${expiry_date}"
    echo "Verbleibende Tage: ${days_until_expiry}"

    if (( days_until_expiry < 0 )); then
        echo "⚠ STATUS: ABGELAUFEN"
        return 2
    elif (( days_until_expiry < warn_days )); then
        echo "⚠ STATUS: Läuft bald ab (< ${warn_days} Tage)"
        return 1
    else
        echo "✓ STATUS: Gültig"
        return 0
    fi
}

# Export Funktionen
export -f create_step_ca_cert
export -f verify_cert_exists
export -f verify_cert_accessible_on_traefik
export -f list_certificates
export -f check_cert_expiry
