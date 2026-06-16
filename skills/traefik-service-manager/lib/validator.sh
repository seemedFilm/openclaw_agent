#!/usr/bin/env bash
# ============================================================================
# Validator Library für Traefik Service Manager
# ============================================================================
# Purpose: Input-Validierung und Sanitization
# ============================================================================

# Hostname-Validierung (FQDN Format)
validate_hostname() {
    local hostname="$1"

    # Regex für FQDN: mindestens ein Punkt, alphanumerisch mit Bindestrichen
    local hostname_regex='^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    if [[ -z "$hostname" ]]; then
        echo "ERROR: Hostname darf nicht leer sein" >&2
        return 1
    fi

    if [[ ! "$hostname" =~ $hostname_regex ]]; then
        echo "ERROR: Ungültiges Hostname-Format: $hostname" >&2
        echo "      Erwartet: FQDN (z.B. api.example.com oder myapp.internal)" >&2
        return 1
    fi

    # Längen-Check
    if [[ ${#hostname} -gt 253 ]]; then
        echo "ERROR: Hostname zu lang (max 253 Zeichen): $hostname" >&2
        return 1
    fi

    return 0
}

# Backend-URL-Validierung
validate_backend() {
    local backend="$1"

    # Regex für Backend: http(s)://IP:Port oder http(s)://hostname:Port
    local backend_regex='^https?://([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-zA-Z0-9\.\-]+)(:[0-9]{1,5})?(/.*)?$'

    if [[ -z "$backend" ]]; then
        echo "ERROR: Backend-URL darf nicht leer sein" >&2
        return 1
    fi

    if [[ ! "$backend" =~ $backend_regex ]]; then
        echo "ERROR: Ungültiges Backend-Format: $backend" >&2
        echo "      Erwartet: http(s)://IP:Port oder http(s)://hostname:Port" >&2
        echo "      Beispiel: https://192.168.1.50:8080" >&2
        return 1
    fi

    # IP-Validierung (wenn IP verwendet wird)
    if [[ "$backend" =~ ^https?://([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3}) ]]; then
        local ip1="${BASH_REMATCH[1]}"
        local ip2="${BASH_REMATCH[2]}"
        local ip3="${BASH_REMATCH[3]}"
        local ip4="${BASH_REMATCH[4]}"

        if (( ip1 > 255 || ip2 > 255 || ip3 > 255 || ip4 > 255 )); then
            echo "ERROR: Ungültige IP-Adresse in Backend: $backend" >&2
            return 1
        fi
    fi

    # Port-Validierung (wenn vorhanden)
    if [[ "$backend" =~ :([0-9]+) ]]; then
        local port="${BASH_REMATCH[1]}"
        if (( port < 1 || port > 65535 )); then
            echo "ERROR: Ungültiger Port in Backend: $port (erlaubt: 1-65535)" >&2
            return 1
        fi
    fi

    return 0
}

# Sanitize Input (Command-Injection-Schutz)
sanitize_input() {
    local input="$1"

    # Entferne gefährliche Zeichen
    # Erlaubt: alphanumerisch, Punkte, Bindestriche, Doppelpunkte, Slashes
    local sanitized="${input//[^a-zA-Z0-9.\-:\/]/_}"

    echo "$sanitized"
}

# Prüfe ob String Shell-Meta-Zeichen enthält
contains_shell_metacharacters() {
    local input="$1"

    # Shell-Meta-Zeichen: ; | & $ ` ( ) < > [ ] { } * ? ~ ! # \
    if [[ "$input" =~ [\;\|\&\$\`\(\)\<\>\[\]\{\}\*\?\~\!\#\\] ]]; then
        return 0  # enthält Meta-Zeichen
    fi

    return 1  # sicher
}

# Validiere ob Hostname bereits existiert
validate_hostname_not_exists() {
    local hostname="$1"
    local traefik_host="${2:-192.168.1.23}"
    local config_path="${3:-/docker/volume/traefik/dynamic}"

    # Generiere Config-Dateinamen
    local config_filename="${hostname//./-}.yml"

    # Prüfe ob Config bereits existiert
    if ssh -o ConnectTimeout=5 root@"$traefik_host" "test -f ${config_path}/${config_filename}" 2>/dev/null; then
        echo "WARNING: Konfiguration für $hostname existiert bereits" >&2
        echo "         Datei: ${config_path}/${config_filename}" >&2
        return 1
    fi

    return 0
}

# Validiere SSH-Konnektivität zu Host
validate_ssh_connectivity() {
    local target_host="$1"
    local timeout="${2:-5}"

    if ! ssh -o ConnectTimeout="$timeout" -o BatchMode=yes root@"$target_host" "true" 2>/dev/null; then
        echo "ERROR: SSH-Verbindung zu $target_host fehlgeschlagen" >&2
        echo "       Prüfe SSH-Keys und Netzwerk-Konnektivität" >&2
        return 1
    fi

    return 0
}

# Validiere ob Traefik Container läuft
validate_traefik_running() {
    local traefik_host="${1:-192.168.1.23}"
    local container_name="${2:-traefik}"

    if ! ssh root@"$traefik_host" "docker ps --filter name=${container_name} --format '{{.Names}}'" 2>/dev/null | grep -q "^${container_name}$"; then
        echo "ERROR: Traefik Container '${container_name}' läuft nicht auf ${traefik_host}" >&2
        return 1
    fi

    return 0
}

# Export Funktionen
export -f validate_hostname
export -f validate_backend
export -f sanitize_input
export -f contains_shell_metacharacters
export -f validate_hostname_not_exists
export -f validate_ssh_connectivity
export -f validate_traefik_running
