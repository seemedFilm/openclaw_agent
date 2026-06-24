#!/usr/bin/env bash
# ============================================================================
# Test Pi-hole API Integration
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIHOLE_MANAGER="${SCRIPT_DIR}/../pihole-dns-manager.sh"

echo "=========================================="
echo "Pi-hole API Integration Test"
echo "=========================================="
echo

# Check if API token is set
if [[ -z "${PIHOLE_API_TOKEN:-}" ]]; then
    echo "⚠️  WARNING: PIHOLE_API_TOKEN not set"
    echo "   Set it with: export PIHOLE_API_TOKEN='your-token'"
    echo
fi

# Test 1: API Connection
echo "Test 1: API-Verbindung testen..."
if "$PIHOLE_MANAGER" test; then
    echo "✓ Test 1 passed"
else
    echo "✗ Test 1 failed"
    exit 1
fi
echo

# Test 2: Add DNS Record
echo "Test 2: DNS-Record hinzufügen..."
TEST_HOSTNAME="pihole-test.internal"
if "$PIHOLE_MANAGER" add --hostname "$TEST_HOSTNAME"; then
    echo "✓ Test 2 passed"
else
    echo "✗ Test 2 failed"
    exit 1
fi
echo

# Test 3: Check DNS Record exists
echo "Test 3: DNS-Record prüfen..."
if "$PIHOLE_MANAGER" check --hostname "$TEST_HOSTNAME"; then
    echo "✓ Test 3 passed"
else
    echo "✗ Test 3 failed"
    exit 1
fi
echo

# Test 4: List DNS Records
echo "Test 4: DNS-Records auflisten..."
if "$PIHOLE_MANAGER" list; then
    echo "✓ Test 4 passed"
else
    echo "✗ Test 4 failed"
    exit 1
fi
echo

# Test 5: Remove DNS Record
echo "Test 5: DNS-Record entfernen..."
if "$PIHOLE_MANAGER" remove --hostname "$TEST_HOSTNAME"; then
    echo "✓ Test 5 passed"
else
    echo "✗ Test 5 failed"
    exit 1
fi
echo

# Test 6: Verify DNS Record removed
echo "Test 6: Verifiziere Entfernung..."
if "$PIHOLE_MANAGER" check --hostname "$TEST_HOSTNAME"; then
    echo "✗ Test 6 failed - Record still exists"
    exit 1
else
    echo "✓ Test 6 passed"
fi
echo

echo "=========================================="
echo "✓ Alle Tests erfolgreich!"
echo "=========================================="
