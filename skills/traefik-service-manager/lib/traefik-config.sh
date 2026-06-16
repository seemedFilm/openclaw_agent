#!/usr/bin/env bash
# ============================================================================
# Traefik Config Generator Library
# ============================================================================
# Purpose: Generierung von Traefik-Konfigurationsdateien
# ============================================================================

# Source validator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./validator.sh
source "${SCRIPT_DIR}/validator.sh"

# Generiere Router-Config für externe Services
generate_external_service_config() {
    local hostname="$1"
    local backend="$2"
    local middlewares="${3:-redirect-https,secure}"
    local cert_resolver="${4:-letsencrypt}"

    # Generiere Router-Namen (Punkte durch Bindestriche ersetzen)
    local router_name="${hostname//./-}"

    # Middlewares als Array
    IFS=',' read -ra middleware_array <<< "$middlewares"

    # YAML generieren
    cat <<EOF
http:
  routers:
    ${router_name}:
      rule: "Host(\`${hostname}\`)"
      entryPoints:
        - websecure
      middlewares:
EOF

    # Middlewares hinzufügen
    for mw in "${middleware_array[@]}"; do
        echo "        - ${mw}"
    done

    cat <<EOF
      tls:
        certResolver: ${cert_resolver}
      service: ${router_name}

    ${router_name}-http:
      rule: "Host(\`${hostname}\`)"
      entryPoints:
        - web
      middlewares:
        - redirect-https
      service: ${router_name}

  services:
    ${router_name}:
      loadBalancer:
        servers:
          - url: "${backend}"
EOF
}

# Generiere Router-Config für interne Services
generate_internal_service_config() {
    local hostname="$1"
    local backend="$2"
    local middlewares="${3:-redirect-https}"

    # Generiere Router-Namen
    local router_name="${hostname//./-}"

    # Middlewares als Array
    IFS=',' read -ra middleware_array <<< "$middlewares"

    # YAML generieren (OHNE certResolver!)
    cat <<EOF
http:
  routers:
    ${router_name}:
      rule: "Host(\`${hostname}\`)"
      entryPoints:
        - websecure
      middlewares:
EOF

    # Middlewares hinzufügen
    for mw in "${middleware_array[@]}"; do
        echo "        - ${mw}"
    done

    cat <<EOF
      service: ${router_name}

  services:
    ${router_name}:
      loadBalancer:
        servers:
          - url: "${backend}"
EOF
}

# Backup Traefik-Konfiguration
backup_config() {
    local traefik_host="${1:-192.168.1.23}"
    local config_path="${2:-/docker/volume/traefik/dynamic}"
    local backup_path="${config_path}/backup"

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    echo "💾 Erstelle Backup der Traefik-Konfiguration..."
    echo "   Host: ${traefik_host}"
    echo "   Pfad: ${config_path}"

    # Erstelle Backup-Verzeichnis falls nicht vorhanden
    ssh root@"$traefik_host" "mkdir -p ${backup_path}" 2>/dev/null || {
        echo "ERROR: Konnte Backup-Verzeichnis nicht erstellen" >&2
        return 1
    }

    # Kopiere alle YAML-Dateien
    ssh root@"$traefik_host" "
        cd ${config_path} || exit 1
        mkdir -p ${backup_path}/${timestamp}
        cp *.yml ${backup_path}/${timestamp}/ 2>/dev/null || true
    " || {
        echo "ERROR: Backup fehlgeschlagen" >&2
        return 1
    }

    echo "   ✓ Backup erstellt: ${backup_path}/${timestamp}/"

    # Speichere Backup-Pfad für möglichen Rollback
    echo "${backup_path}/${timestamp}" > /tmp/traefik-backup-path.txt

    return 0
}

# Update tls.yml für internes Zertifikat
update_tls_yaml() {
    local hostname_base="$1"
    local traefik_host="${2:-192.168.1.23}"
    local config_path="${3:-/docker/volume/traefik/dynamic}"
    local cert_storage="${4:-/srv/pki}"

    local tls_file="${config_path}/tls.yml"

    echo "📝 Aktualisiere tls.yml für ${hostname_base}..."

    # Backup von tls.yml
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    ssh root@"$traefik_host" "cp ${tls_file} ${tls_file}.backup-${timestamp}" 2>/dev/null || {
        echo "WARNING: Konnte tls.yml nicht sichern (evtl. existiert sie nicht)" >&2
    }

    # Prüfe ob tls.yml existiert
    if ! ssh root@"$traefik_host" "test -f ${tls_file}" 2>/dev/null; then
        echo "   tls.yml existiert nicht, erstelle neue Datei..."
        ssh root@"$traefik_host" "cat > ${tls_file}" <<'EOF'
tls:
  certificates:
EOF
    fi

    # Prüfe ob Eintrag bereits existiert
    if ssh root@"$traefik_host" "grep -q '${cert_storage}/${hostname_base}/fullchain.crt' ${tls_file}" 2>/dev/null; then
        echo "   ⚠ Zertifikat bereits in tls.yml vorhanden, überspringe..."
        return 0
    fi

    # Füge neuen Zertifikats-Eintrag hinzu
    ssh root@"$traefik_host" "cat >> ${tls_file}" <<EOF
    - certFile: ${cert_storage}/${hostname_base}/fullchain.crt
      keyFile: ${cert_storage}/${hostname_base}/${hostname_base}.key
EOF

    if [[ $? -eq 0 ]]; then
        echo "   ✓ tls.yml aktualisiert"
        return 0
    else
        echo "ERROR: Konnte tls.yml nicht aktualisieren" >&2
        return 1
    fi
}

# Deploy Config zu Traefik-Server
deploy_config() {
    local hostname="$1"
    local config_content="$2"
    local traefik_host="${3:-192.168.1.23}"
    local config_path="${4:-/docker/volume/traefik/dynamic}"

    # Generiere Dateinamen
    local config_filename="${hostname//./-}.yml"
    local target_file="${config_path}/${config_filename}"

    echo "📤 Deploy Config für ${hostname}..."
    echo "   Ziel: ${traefik_host}:${target_file}"

    # Prüfe ob Config bereits existiert
    if ssh root@"$traefik_host" "test -f ${target_file}" 2>/dev/null; then
        echo "   ⚠ Config existiert bereits, wird überschrieben..."
    fi

    # Deploy Config via SSH
    echo "$config_content" | ssh root@"$traefik_host" "cat > ${target_file}" || {
        echo "ERROR: Konnte Config nicht deployen" >&2
        return 1
    }

    echo "   ✓ Config deployed: ${config_filename}"

    # Verifiziere Syntax (optional, wenn traefik CLI verfügbar)
    # ssh root@"$traefik_host" "docker exec traefik traefik validate ${target_file}" 2>/dev/null && \
    #     echo "   ✓ Config-Syntax validiert"

    return 0
}

# Restart Traefik Container
restart_traefik() {
    local traefik_host="${1:-192.168.1.23}"
    local container_name="${2:-traefik}"
    local timeout="${3:-30}"

    echo "🔄 Starte Traefik-Container neu..."
    echo "   Host: ${traefik_host}"
    echo "   Container: ${container_name}"

    # Prüfe ob Container existiert
    if ! ssh root@"$traefik_host" "docker ps -a --filter name=${container_name} --format '{{.Names}}'" 2>/dev/null | grep -q "^${container_name}$"; then
        echo "ERROR: Traefik-Container '${container_name}' nicht gefunden" >&2
        return 1
    fi

    # Restart Container
    if ssh root@"$traefik_host" "docker restart ${container_name}" >/dev/null 2>&1; then
        echo "   ✓ Container neugestartet"

        # Warte auf Container-Start
        echo "   Warte auf Container-Start..."
        local elapsed=0
        while (( elapsed < timeout )); do
            if ssh root@"$traefik_host" "docker ps --filter name=${container_name} --filter status=running --format '{{.Names}}'" 2>/dev/null | grep -q "^${container_name}$"; then
                echo "   ✓ Container läuft"
                return 0
            fi
            sleep 2
            elapsed=$((elapsed + 2))
        done

        echo "ERROR: Container-Start timeout nach ${timeout}s" >&2
        return 1
    else
        echo "ERROR: Konnte Container nicht neustarten" >&2
        return 1
    fi
}

# Entferne Service-Config
remove_service_config() {
    local hostname="$1"
    local traefik_host="${2:-192.168.1.23}"
    local config_path="${3:-/docker/volume/traefik/dynamic}"

    local config_filename="${hostname//./-}.yml"
    local target_file="${config_path}/${config_filename}"

    echo "🗑️  Entferne Config für ${hostname}..."

    # Prüfe ob Config existiert
    if ! ssh root@"$traefik_host" "test -f ${target_file}" 2>/dev/null; then
        echo "   ⚠ Config nicht gefunden: ${config_filename}"
        return 0
    fi

    # Backup vor Löschung
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${config_path}/backup"

    ssh root@"$traefik_host" "mkdir -p ${backup_path} && cp ${target_file} ${backup_path}/${config_filename}.${timestamp}" || {
        echo "WARNING: Konnte Config nicht sichern" >&2
    }

    # Lösche Config
    if ssh root@"$traefik_host" "rm ${target_file}" 2>/dev/null; then
        echo "   ✓ Config entfernt: ${config_filename}"
        echo "   Backup: ${backup_path}/${config_filename}.${timestamp}"
        return 0
    else
        echo "ERROR: Konnte Config nicht entfernen" >&2
        return 1
    fi
}

# Entferne Zertifikats-Eintrag aus tls.yml
remove_from_tls_yaml() {
    local hostname_base="$1"
    local traefik_host="${2:-192.168.1.23}"
    local config_path="${3:-/docker/volume/traefik/dynamic}"
    local cert_storage="${4:-/srv/pki}"

    local tls_file="${config_path}/tls.yml"

    echo "📝 Entferne Zertifikats-Eintrag aus tls.yml..."

    # Backup
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    ssh root@"$traefik_host" "cp ${tls_file} ${tls_file}.backup-${timestamp}" 2>/dev/null || {
        echo "WARNING: Konnte tls.yml nicht sichern" >&2
    }

    # Entferne Zeilen mit diesem Zertifikat
    ssh root@"$traefik_host" "
        sed -i.tmp '/${cert_storage//\//\\/}\/${hostname_base}\/fullchain.crt/,+1d' ${tls_file}
        rm ${tls_file}.tmp 2>/dev/null || true
    " || {
        echo "ERROR: Konnte Eintrag nicht entfernen" >&2
        return 1
    }

    echo "   ✓ Eintrag entfernt"
    return 0
}

# Liste alle Service-Configs auf
list_services() {
    local traefik_host="${1:-192.168.1.23}"
    local config_path="${2:-/docker/volume/traefik/dynamic}"

    echo "📋 Traefik-Services auf ${traefik_host}:"
    echo

    ssh root@"$traefik_host" "
        cd ${config_path} 2>/dev/null || exit 1
        for file in *.yml; do
            if [[ -f \"\$file\" ]] && [[ \"\$file\" != \"middlewares.yml\" ]] && [[ \"\$file\" != \"tls.yml\" ]] && [[ \"\$file\" != \"transport.yml\" ]]; then
                echo \"  \$file\"
                # Extrahiere Host-Rule
                host=\$(grep -oP 'Host\\(\`\\K[^\`]+' \"\$file\" 2>/dev/null | head -1)
                if [[ -n \"\$host\" ]]; then
                    echo \"    Host: \$host\"
                fi
                # Extrahiere Backend
                backend=\$(grep -oP 'url: \"\\K[^\"]+' \"\$file\" 2>/dev/null | head -1)
                if [[ -n \"\$backend\" ]]; then
                    echo \"    Backend: \$backend\"
                fi
                echo
            fi
        done
    " 2>/dev/null || {
        echo "ERROR: Konnte Services nicht auflisten" >&2
        return 1
    }

    return 0
}

# Export Funktionen
export -f generate_external_service_config
export -f generate_internal_service_config
export -f backup_config
export -f update_tls_yaml
export -f deploy_config
export -f restart_traefik
export -f remove_service_config
export -f remove_from_tls_yaml
export -f list_services
