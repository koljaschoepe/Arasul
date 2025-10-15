#!/bin/bash
# VPN-Client hinzufügen und Konfiguration exportieren
# Story E1.3 - VPN-only Erreichbarkeit

set -e

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_CONF="$WG_DIR/$WG_INTERFACE.conf"
OUTPUT_DIR="/tmp/wireguard-clients"

CLIENT_NAME=$1

# Usage-Check
if [ -z "$CLIENT_NAME" ]; then
  echo "Usage: $0 <client-name>"
  echo ""
  echo "Beispiel:"
  echo "  $0 admin-laptop"
  echo "  $0 smartphone"
  exit 1
fi

# Root-Check
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Dieses Skript muss als root ausgeführt werden"
  echo "   Führen Sie aus: sudo $0 $CLIENT_NAME"
  exit 1
fi

# WireGuard-Konfiguration prüfen
if [ ! -f "$WG_CONF" ]; then
  echo "❌ WireGuard nicht konfiguriert!"
  echo "   Führen Sie zuerst aus: sudo ./setup-wireguard.sh"
  exit 1
fi

echo "===================================="
echo "VPN-Client hinzufügen: $CLIENT_NAME"
echo "===================================="

# 1. Client-Keys generieren
echo ""
echo "🔑 Schritt 1: Client-Keys generieren..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
echo "   ✅ Keys generiert"

# 2. Nächste freie IP finden
echo ""
echo "🔍 Schritt 2: Nächste freie IP ermitteln..."

# IPs aus wg0.conf extrahieren
USED_IPS=$(grep -oP '(?<=AllowedIPs = 10\.80\.1\.)\d+' "$WG_CONF" 2>/dev/null | sort -n || echo "")

# Letzte IP finden
if [ -z "$USED_IPS" ]; then
  LAST_IP=1  # Server-IP
else
  LAST_IP=$(echo "$USED_IPS" | tail -1)
fi

NEXT_IP=$((LAST_IP + 1))

if [ $NEXT_IP -gt 254 ]; then
  echo "❌ Fehler: VPN-Subnetz voll (max. 253 Clients)"
  exit 1
fi

CLIENT_IP="10.80.1.$NEXT_IP"
echo "   ✅ Client-IP: $CLIENT_IP"

# 3. Server-Informationen auslesen
echo ""
echo "📋 Schritt 3: Server-Informationen auslesen..."
SERVER_PUBLIC_KEY=$(cat "$WG_DIR/server_publickey")

# Public-IP ermitteln
if [ -n "$SERVER_PUBLIC_IP" ]; then
  SERVER_ENDPOINT="$SERVER_PUBLIC_IP:51820"
else
  # Versuche Public-IP zu ermitteln
  PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")
  
  if [ -z "$PUBLIC_IP" ]; then
    # Fallback: Lokale IP verwenden
    PUBLIC_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    echo "   ⚠️  Public-IP konnte nicht ermittelt werden, verwende lokale IP: $PUBLIC_IP"
    echo "   ⚠️  Für Remote-Zugriff: Setzen Sie SERVER_PUBLIC_IP Umgebungsvariable"
  fi
  
  SERVER_ENDPOINT="$PUBLIC_IP:51820"
fi

echo "   Server-Endpoint: $SERVER_ENDPOINT"

# 4. Peer zu Server-Config hinzufügen
echo ""
echo "📝 Schritt 4: Peer zur Server-Konfiguration hinzufügen..."
cat >> "$WG_CONF" <<EOF

# Peer: $CLIENT_NAME (hinzugefügt: $(date +"%Y-%m-%d %H:%M:%S"))
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOF

echo "   ✅ Peer hinzugefügt"

# 5. WireGuard-Konfiguration neu laden
echo ""
echo "🔄 Schritt 5: WireGuard-Konfiguration neu laden..."
if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
  wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)
  echo "   ✅ Konfiguration neu geladen"
else
  echo "   ⚠️  WireGuard-Service nicht aktiv, starte..."
  systemctl start wg-quick@$WG_INTERFACE
fi

# 6. Client-Konfiguration generieren
echo ""
echo "📄 Schritt 6: Client-Konfiguration generieren..."
mkdir -p "$OUTPUT_DIR"
CLIENT_CONF="$OUTPUT_DIR/$CLIENT_NAME.conf"

cat > "$CLIENT_CONF" <<EOF
# WireGuard Client Configuration
# Client: $CLIENT_NAME
# Generated: $(date)
# Story E1.3 - VPN-only Erreichbarkeit

[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 10.80.1.0/24
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"
echo "   ✅ Client-Konfiguration erstellt: $CLIENT_CONF"

# 7. QR-Code generieren
echo ""
echo "📱 Schritt 7: QR-Code generieren..."
QR_FILE="$OUTPUT_DIR/$CLIENT_NAME-qr.png"

if command -v qrencode &> /dev/null; then
  # QR-Code als PNG
  qrencode -o "$QR_FILE" < "$CLIENT_CONF"
  echo "   ✅ QR-Code gespeichert: $QR_FILE"
  
  # QR-Code in Terminal anzeigen (für Copy/Paste)
  echo ""
  echo "📱 QR-Code (für iOS/Android WireGuard-App):"
  echo ""
  qrencode -t ansiutf8 < "$CLIENT_CONF"
else
  echo "   ⚠️  qrencode nicht installiert, QR-Code übersprungen"
fi

# 8. Zusammenfassung
echo ""
echo "===================================="
echo "✅ Client erfolgreich hinzugefügt!"
echo "===================================="
echo ""
echo "📋 Client-Details:"
echo "   Name: $CLIENT_NAME"
echo "   IP: $CLIENT_IP"
echo "   Konfiguration: $CLIENT_CONF"
if [ -f "$QR_FILE" ]; then
  echo "   QR-Code: $QR_FILE"
fi
echo ""
echo "📱 Client-Setup-Anleitungen:"
echo ""
echo "   iOS/Android:"
echo "   1. WireGuard-App installieren"
echo "   2. QR-Code scannen (siehe oben)"
echo "   3. VPN aktivieren"
echo ""
echo "   macOS/Linux:"
echo "   1. WireGuard installieren (brew install wireguard-tools / apt install wireguard)"
echo "   2. Konfiguration kopieren:"
echo "      sudo cp $CLIENT_CONF /etc/wireguard/$CLIENT_NAME.conf"
echo "   3. VPN aktivieren:"
echo "      sudo wg-quick up $CLIENT_NAME"
echo ""
echo "   Windows:"
echo "   1. WireGuard für Windows installieren"
echo "   2. 'Import tunnel(s) from file' → $CLIENT_CONF"
echo "   3. VPN aktivieren"
echo ""
echo "🔗 Nach Aktivierung erreichbar unter:"
echo "   https://10.80.1.1/"
echo ""
echo "⚠️  Sicherheitshinweise:"
echo "   - Konfigurationsdatei sicher aufbewahren (enthält Private-Key!)"
echo "   - QR-Code nicht in Screenshots/Logs teilen"
echo "   - Bei Key-Verlust: Peer entfernen mit remove-vpn-client.sh"
echo ""

