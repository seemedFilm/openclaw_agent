#!/usr/bin/env bash
# ============================================================================
# Beispiel: Internen Service hinzufügen (step-ca Zertifikat)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TSM="${SCRIPT_DIR}/../traefik-service-manager.sh"

echo "=== Beispiel: Internen Service hinzufügen ==="
echo

# Interne Domain mit step-ca Zertifikat
"$TSM" add \
  --hostname myapp.internal \
  --backend https://192.168.1.51:3000

echo
echo "Service sollte nun erreichbar sein unter:"
echo "https://myapp.internal"
echo
echo "Das Zertifikat wurde von step-ca (192.168.1.3) erstellt."
echo
echo "Zum Testen:"
echo "  curl -I https://myapp.internal"
echo
echo "Zertifikat-Details:"
echo "  ssh root@192.168.1.3 'ls -la /srv/pki/myapp/'"
echo "  ssh root@192.168.1.3 'openssl x509 -in /srv/pki/myapp/fullchain.crt -noout -text'"
echo
echo "Zum Entfernen:"
echo "  $TSM remove --hostname myapp.internal"
echo
