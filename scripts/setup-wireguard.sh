#!/bin/bash
# WireGuard VPN Server Setup für Jetson
# Story E1.3 - VPN-only Erreichbarkeit

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
VPN_SUBNET="10.80.1.0/24"
SERVER_IP="10.80.1.1"
LISTEN_PORT="51820"

echo "===================================="
echo "WireGuard VPN Server Setup"
echo "===================================="

# Root-Check
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Dieses Skript muss als root ausgeführt werden"
  echo "   Führen Sie aus: sudo $0"
  exit 1
fi

# 1. WireGuard installieren
echo ""
echo "📦 Schritt 1: WireGuard-Installation prüfen..."
if ! command -v wg &> /dev/null; then
  echo "   WireGuard nicht gefunden, installiere..."
  apt update
  apt install -y wireguard wireguard-tools
else
  echo "   ✅ WireGuard bereits installiert"
fi

# qrencode für QR-Code-Generierung
if ! command -v qrencode &> /dev/null; then
  echo "   qrencode nicht gefunden, installiere..."
  apt install -y qrencode
else
  echo "   ✅ qrencode bereits installiert"
fi

# 2. WireGuard-Kernel-Modul prüfen
echo ""
echo "🔍 Schritt 2: WireGuard-Kernel-Modul prüfen..."
if ! lsmod | grep -q wireguard; then
  echo "   Versuche Kernel-Modul zu laden..."
  modprobe wireguard || {
    echo "❌ WireGuard-Kernel-Modul konnte nicht geladen werden"
    echo "   JetPack ≥5.x erforderlich oder wireguard-dkms installieren"
    exit 1
  }
fi
echo "   ✅ WireGuard-Kernel-Modul aktiv"

# 3. Server-Keys generieren
echo ""
echo "🔑 Schritt 3: Server-Keys generieren..."
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

if [ ! -f "$WG_DIR/server_privatekey" ]; then
  wg genkey | tee "$WG_DIR/server_privatekey" | wg pubkey > "$WG_DIR/server_publickey"
  chmod 600 "$WG_DIR/server_privatekey"
  chmod 644 "$WG_DIR/server_publickey"
  echo "   ✅ Server-Keys generiert"
else
  echo "   ⚠️  Server-Keys existieren bereits, überspringe..."
fi

SERVER_PRIVATE_KEY=$(cat "$WG_DIR/server_privatekey")
SERVER_PUBLIC_KEY=$(cat "$WG_DIR/server_publickey")

echo "   Server Public Key: $SERVER_PUBLIC_KEY"

# 4. Network-Interface ermitteln
echo ""
echo "🌐 Schritt 4: Netzwerk-Interface ermitteln..."
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$DEFAULT_INTERFACE" ]; then
  DEFAULT_INTERFACE="eth0"
  echo "   ⚠️  Konnte Default-Interface nicht ermitteln, verwende: $DEFAULT_INTERFACE"
else
  echo "   ✅ Default-Interface: $DEFAULT_INTERFACE"
fi

# 5. WireGuard-Konfiguration erstellen
echo ""
echo "📝 Schritt 5: WireGuard-Konfiguration erstellen..."
cat > "$WG_DIR/$WG_INTERFACE.conf" <<EOF
# WireGuard Server Configuration
# Generated: $(date)
# Story E1.3 - VPN-only Erreichbarkeit

[Interface]
Address = $SERVER_IP/24
ListenPort = $LISTEN_PORT
PrivateKey = $SERVER_PRIVATE_KEY

# IP-Forwarding aktivieren
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE

PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE

# Clients werden dynamisch über add-vpn-client.sh hinzugefügt
# Format:
# [Peer]
# PublicKey = <CLIENT_PUBLIC_KEY>
# AllowedIPs = 10.80.1.x/32
EOF

chmod 600 "$WG_DIR/$WG_INTERFACE.conf"
echo "   ✅ Konfiguration erstellt: $WG_DIR/$WG_INTERFACE.conf"

# 6. IP-Forwarding permanent aktivieren
echo ""
echo "🔧 Schritt 6: IP-Forwarding aktivieren..."
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  sysctl -p
  echo "   ✅ IP-Forwarding permanent aktiviert"
else
  echo "   ⚠️  IP-Forwarding bereits konfiguriert"
fi

# 7. WireGuard-Service aktivieren
echo ""
echo "🚀 Schritt 7: WireGuard-Service aktivieren..."
systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

sleep 2

# Health-Check
if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
  echo "   ✅ WireGuard-Service aktiv"
else
  echo "   ❌ WireGuard-Service konnte nicht gestartet werden"
  systemctl status wg-quick@$WG_INTERFACE
  exit 1
fi

# 8. Interface-Status prüfen
echo ""
echo "📊 WireGuard-Status:"
wg show $WG_INTERFACE

echo ""
echo "===================================="
echo "✅ WireGuard-Server erfolgreich eingerichtet!"
echo "===================================="
echo ""
echo "📋 Nächste Schritte:"
echo "   1. Firewall-Regeln einrichten: sudo $SCRIPT_DIR/setup-vpn-firewall.sh"
echo "   2. VPN-Client hinzufügen: sudo $SCRIPT_DIR/add-vpn-client.sh <client-name>"
echo ""
echo "🔑 Server Public Key (für Clients):"
echo "   $SERVER_PUBLIC_KEY"
echo ""

