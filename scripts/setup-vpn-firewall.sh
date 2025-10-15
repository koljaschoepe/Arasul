#!/bin/bash
# Firewall-Regeln für VPN-only Zugriff
# Story E1.3 - VPN-only Erreichbarkeit

set -e

WG_INTERFACE="wg0"
WIREGUARD_PORT="51820"
HTTPS_PORT="443"
HTTP_PORT="80"
SSH_PORT="22"
PROMETHEUS_PORT="9090"
GRAFANA_PORT="3001"

echo "===================================="
echo "VPN-only Firewall Setup"
echo "===================================="

# Root-Check
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Dieses Skript muss als root ausgeführt werden"
  echo "   Führen Sie aus: sudo $0"
  exit 1
fi

# 1. iptables-persistent installieren
echo ""
echo "📦 Schritt 1: iptables-persistent prüfen..."
if ! dpkg -l | grep -q iptables-persistent; then
  echo "   Installiere iptables-persistent..."
  # Non-interactive Installation
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
  apt install -y iptables-persistent
else
  echo "   ✅ iptables-persistent bereits installiert"
fi

# 2. Netzwerk-Interfaces ermitteln
echo ""
echo "🌐 Schritt 2: Netzwerk-Interfaces ermitteln..."
PUBLIC_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|wlan|enp)' || echo "")
if [ -z "$PUBLIC_INTERFACES" ]; then
  echo "   ⚠️  Keine Public-Interfaces gefunden, verwende eth0 als Fallback"
  PUBLIC_INTERFACES="eth0"
fi
echo "   Public-Interfaces: $PUBLIC_INTERFACES"

# 3. Firewall-Regeln erstellen
echo ""
echo "🔒 Schritt 3: Firewall-Regeln konfigurieren..."

# Alte Regeln löschen
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default-Policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback erlauben (wichtig für lokale Prozesse)
iptables -A INPUT -i lo -j ACCEPT

# Established/Related Verbindungen erlauben
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# ICMP (Ping) erlauben für Diagnostik
iptables -A INPUT -p icmp -j ACCEPT

# WireGuard-Port (51820/UDP) öffentlich erreichbar
iptables -A INPUT -p udp --dport $WIREGUARD_PORT -j ACCEPT

# HTTPS (443/TCP) nur von VPN (wg0)
iptables -A INPUT -i $WG_INTERFACE -p tcp --dport $HTTPS_PORT -j ACCEPT

# HTTP (80/TCP) nur von VPN (wg0) für HTTPS-Redirect
iptables -A INPUT -i $WG_INTERFACE -p tcp --dport $HTTP_PORT -j ACCEPT

# SSH (22/TCP) nur von VPN (wg0) - Remote-Management
iptables -A INPUT -i $WG_INTERFACE -p tcp --dport $SSH_PORT -j ACCEPT

# Prometheus (9090/TCP) nur von VPN
iptables -A INPUT -i $WG_INTERFACE -p tcp --dport $PROMETHEUS_PORT -j ACCEPT

# Grafana (3001/TCP) nur von VPN
iptables -A INPUT -i $WG_INTERFACE -p tcp --dport $GRAFANA_PORT -j ACCEPT

# HTTPS/HTTP von Public-Interfaces EXPLIZIT BLOCKEN
for iface in $PUBLIC_INTERFACES; do
  iptables -A INPUT -i $iface -p tcp --dport $HTTPS_PORT -j DROP
  iptables -A INPUT -i $iface -p tcp --dport $HTTP_PORT -j DROP
  echo "   ✅ Ports 80/443 auf $iface geblockt"
done

# Logging für geblockte Verbindungen (optional, für Debugging)
# iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPT-DROP: " --log-level 7

echo "   ✅ Firewall-Regeln konfiguriert"

# 4. Regeln persistent speichern
echo ""
echo "💾 Schritt 4: Firewall-Regeln persistent speichern..."
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4
echo "   ✅ Regeln gespeichert: /etc/iptables/rules.v4"

# 5. Firewall-Status anzeigen
echo ""
echo "📋 Firewall-Status:"
echo ""
echo "INPUT-Chain:"
iptables -L INPUT -n -v --line-numbers | head -n 20
echo ""

echo "===================================="
echo "✅ Firewall erfolgreich konfiguriert!"
echo "===================================="
echo ""
echo "🔒 Sicherheits-Zusammenfassung:"
echo "   ✅ WireGuard-Port ($WIREGUARD_PORT/UDP): öffentlich erreichbar"
echo "   ✅ HTTPS ($HTTPS_PORT/TCP): nur über VPN ($WG_INTERFACE)"
echo "   ✅ HTTP ($HTTP_PORT/TCP): nur über VPN ($WG_INTERFACE)"
echo "   ✅ SSH ($SSH_PORT/TCP): nur über VPN ($WG_INTERFACE)"
echo "   ❌ Public-Interfaces: Ports 80/443 geblockt"
echo ""
echo "⚠️  Wichtig:"
echo "   - Firewall-Regeln überleben Reboots (iptables-persistent)"
echo "   - Testen Sie VPN-Zugriff BEVOR Sie sich ausloggen!"
echo "   - Bei Problemen: sudo iptables -F (alle Regeln löschen)"
echo ""

