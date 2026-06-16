#!/usr/bin/env bash
# ============================================================================
# Beispiel: Externen Service hinzufügen (Let's Encrypt)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TSM="${SCRIPT_DIR}/../traefik-service-manager.sh"

echo "=== Beispiel: Externen Service hinzufügen ==="
echo

# Externe Domain mit Let's Encrypt
"$TSM" add \
  --hostname api.diefamilielang.de \
  --backend https://192.168.1.50:8080

echo
echo "Service sollte nun erreichbar sein unter:"
echo "https://api.diefamilielang.de"
echo
echo "Let's Encrypt erstellt das Zertifikat automatisch beim ersten HTTPS-Zugriff."
echo
echo "Zum Testen:"
echo "  curl -I https://api.diefamilielang.de"
echo
echo "Zum Entfernen:"
echo "  $TSM remove --hostname api.diefamilielang.de"
echo
