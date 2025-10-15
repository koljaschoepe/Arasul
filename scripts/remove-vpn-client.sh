#!/bin/bash
# VPN-Client entfernen (Peer-Revocation)
# Story E1.3 - VPN-only Erreichbarkeit

set -e

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_CONF="$WG_DIR/$WG_INTERFACE.conf"

CLIENT_NAME=$1

# Usage-Check
if [ -z "$CLIENT_NAME" ]; then
  echo "Usage: $0 <client-name>"
  echo ""
  echo "Beispiel:"
  echo "  $0 admin-laptop"
  exit 1
fi

# Root-Check
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Dieses Skript muss als root ausgeführt werden"
  echo "   Führen Sie aus: sudo $0 $CLIENT_NAME"
  exit 1
fi

echo "===================================="
echo "VPN-Client entfernen: $CLIENT_NAME"
echo "===================================="

# 1. Client in Konfiguration finden
echo ""
echo "🔍 Schritt 1: Client in Konfiguration suchen..."

if ! grep -q "# Peer: $CLIENT_NAME" "$WG_CONF"; then
  echo "❌ Client '$CLIENT_NAME' nicht in Konfiguration gefunden"
  echo ""
  echo "Verfügbare Clients:"
  grep "# Peer:" "$WG_CONF" | sed 's/# Peer: /  - /'
  exit 1
fi

echo "   ✅ Client gefunden"

# 2. Peer-Konfiguration entfernen
echo ""
echo "🗑️  Schritt 2: Peer aus Konfiguration entfernen..."

# Backup erstellen
cp "$WG_CONF" "$WG_CONF.backup.$(date +%s)"

# Peer-Block entfernen (von "# Peer: $CLIENT_NAME" bis zum nächsten "[Peer]" oder EOF)
sed -i "/# Peer: $CLIENT_NAME/,/^\[Peer\]/{/^\[Peer\]/!d;}" "$WG_CONF"
sed -i "/# Peer: $CLIENT_NAME/d" "$WG_CONF"

echo "   ✅ Peer entfernt"

# 3. WireGuard-Konfiguration neu laden
echo ""
echo "🔄 Schritt 3: WireGuard-Konfiguration neu laden..."
if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
  wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)
  echo "   ✅ Konfiguration neu geladen"
else
  echo "   ⚠️  WireGuard-Service nicht aktiv"
fi

echo ""
echo "===================================="
echo "✅ Client erfolgreich entfernt!"
echo "===================================="
echo ""
echo "⚠️  Hinweis:"
echo "   - Der Client kann sich nicht mehr verbinden"
echo "   - Backup der alten Konfiguration: $WG_CONF.backup.*"
echo ""

