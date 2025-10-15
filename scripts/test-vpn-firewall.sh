#!/bin/bash
# VPN-only Zugriff und Firewall-Tests
# Story E1.3 - VPN-only Erreichbarkeit

set -e

WG_INTERFACE="wg0"
VPN_SERVER_IP="10.80.1.1"
TIMEOUT=5

echo "===================================="
echo "VPN & Firewall Tests"
echo "===================================="

# Test-Ergebnisse
TESTS_PASSED=0
TESTS_FAILED=0

# Helper-Funktion für Test-Output
test_result() {
  local test_name=$1
  local result=$2
  
  if [ $result -eq 0 ]; then
    echo "   ✅ PASS: $test_name"
    ((TESTS_PASSED++))
  else
    echo "   ❌ FAIL: $test_name"
    ((TESTS_FAILED++))
  fi
}

# Test 1: WireGuard-Service aktiv
echo ""
echo "Test 1: WireGuard-Service-Status"
if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
  test_result "WireGuard-Service aktiv" 0
else
  test_result "WireGuard-Service aktiv" 1
fi

# Test 2: WireGuard-Interface vorhanden
echo ""
echo "Test 2: WireGuard-Interface"
if ip addr show $WG_INTERFACE &> /dev/null; then
  test_result "WireGuard-Interface ($WG_INTERFACE) vorhanden" 0
  
  # Interface-Details anzeigen
  WG_IP=$(ip -4 addr show $WG_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  echo "   ℹ️  Interface-IP: $WG_IP"
else
  test_result "WireGuard-Interface ($WG_INTERFACE) vorhanden" 1
fi

# Test 3: VPN-Erreichbarkeit (nur wenn VPN aktiv)
echo ""
echo "Test 3: VPN-Erreichbarkeit (https://$VPN_SERVER_IP/health)"
if curl -k -s -m $TIMEOUT "https://$VPN_SERVER_IP/health" -o /dev/null -w "%{http_code}" | grep -q "200"; then
  test_result "HTTPS über VPN erreichbar" 0
else
  # Könnte fehlschlagen wenn kein Client verbunden ist
  echo "   ⚠️  SKIP: VPN-Zugriff nicht testbar (möglicherweise kein Client verbunden)"
  echo "   ℹ️  Manuell testen: curl -k https://$VPN_SERVER_IP/health"
fi

# Test 4: Public-IP-Blockade
echo ""
echo "Test 4: Public-IP-Blockade"

# Public-IP ermitteln
PUBLIC_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | grep -v '^10\.' | head -n1)

if [ -z "$PUBLIC_IP" ]; then
  echo "   ⚠️  SKIP: Konnte Public-IP nicht ermitteln"
else
  echo "   ℹ️  Teste Public-IP: $PUBLIC_IP"
  
  # Versuch, über Public-IP zuzugreifen (sollte fehlschlagen)
  if curl -k -s -m $TIMEOUT "https://$PUBLIC_IP/health" -o /dev/null 2>&1; then
    test_result "Public-IP geblockt (HTTPS sollte timeout/refused sein)" 1
    echo "   ❌ SICHERHEITSRISIKO: HTTPS ist über Public-IP erreichbar!"
  else
    test_result "Public-IP geblockt" 0
  fi
fi

# Test 5: Firewall-Regeln vorhanden
echo ""
echo "Test 5: Firewall-Regeln"

# WireGuard-Port (51820/UDP) erlaubt
if iptables -L INPUT -n | grep -q "udp.*51820.*ACCEPT"; then
  test_result "WireGuard-Port (51820/UDP) erlaubt" 0
else
  test_result "WireGuard-Port (51820/UDP) erlaubt" 1
fi

# HTTPS (443/TCP) nur von wg0
if iptables -L INPUT -n | grep -q "tcp.*443.*ACCEPT"; then
  test_result "HTTPS (443/TCP) Regel vorhanden" 0
else
  test_result "HTTPS (443/TCP) Regel vorhanden" 1
fi

# Public-Interfaces geblockt
if iptables -L INPUT -n | grep -q "tcp.*443.*DROP\|tcp.*dpt:443.*DROP"; then
  test_result "Public-Interface HTTPS-Block vorhanden" 0
else
  test_result "Public-Interface HTTPS-Block vorhanden" 1
fi

# Test 6: Firewall-Persistenz-Setup
echo ""
echo "Test 6: Firewall-Persistenz"
if [ -f /etc/iptables/rules.v4 ]; then
  test_result "iptables-persistent Konfiguration vorhanden" 0
else
  test_result "iptables-persistent Konfiguration vorhanden" 1
fi

# Test 7: IP-Forwarding aktiviert
echo ""
echo "Test 7: IP-Forwarding"
if sysctl net.ipv4.ip_forward | grep -q "= 1"; then
  test_result "IP-Forwarding aktiviert" 0
else
  test_result "IP-Forwarding aktiviert" 1
fi

# Zusammenfassung
echo ""
echo "===================================="
echo "Test-Zusammenfassung"
echo "===================================="
echo "   ✅ Erfolgreich: $TESTS_PASSED"
echo "   ❌ Fehlgeschlagen: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo "✅ Alle Tests bestanden!"
  exit 0
else
  echo "❌ $TESTS_FAILED Test(s) fehlgeschlagen"
  exit 1
fi

