# WireGuard VPN Setup

**Story E1.3 – VPN-only Erreichbarkeit**

Dieses Dokument beschreibt die Einrichtung und Verwaltung des WireGuard VPN-Zugangs zum Jetson-System.

## Inhaltsverzeichnis

- [Übersicht](#übersicht)
- [Server-Setup](#server-setup)
- [Client-Setup](#client-setup)
- [Verwaltung](#verwaltung)
- [Troubleshooting](#troubleshooting)
- [Sicherheit](#sicherheit)

---

## Übersicht

### Ziel

Alle HTTPS-Dienste (Dashboard, API, n8n, MinIO, Guacamole, Monitoring) sind ausschließlich über WireGuard VPN erreichbar. Der direkte Zugriff über Public-IPs wird durch Firewall-Regeln blockiert.

### Architektur

```
Client (z.B. 192.168.1.100)
  ↓ [WireGuard Tunnel - Port 51820/UDP]
WireGuard-Server (Jetson, 10.80.1.1)
  ↓ [wg0 Interface]
iptables (Firewall: nur wg0 → 443/TCP erlaubt)
  ↓
Caddy (TLS-Terminierung, 443/TCP)
  ↓ [Reverse-Proxy]
Services (Dashboard, API, n8n, MinIO, Guacamole)
```

### Netzwerk-Details

- **VPN-Subnetz:** 10.80.1.0/24
- **Server-IP:** 10.80.1.1
- **Client-IPs:** 10.80.1.2 - 10.80.1.254
- **WireGuard-Port:** 51820/UDP (öffentlich erreichbar)
- **Dienste-Ports:** 80/443 TCP (nur über VPN)

---

## Server-Setup

### Voraussetzungen

- **OS:** Linux (Debian/Ubuntu) mit Kernel ≥5.6
- **JetPack:** ≥5.x (WireGuard-Unterstützung)
- **Root-Zugriff** auf dem Jetson-Gerät

### Installation

**Schritt 1: WireGuard installieren und konfigurieren**

```bash
cd /path/to/jetson/scripts
sudo ./setup-wireguard.sh
```

Das Skript führt automatisch folgende Schritte aus:
- WireGuard-Paket installieren
- Server-Keys generieren
- WireGuard-Interface `wg0` konfigurieren
- systemd-Service aktivieren und starten
- IP-Forwarding aktivieren

**Erwartete Ausgabe:**
```
===================================="
WireGuard VPN Server Setup
====================================

✅ WireGuard bereits installiert
✅ WireGuard-Kernel-Modul aktiv
✅ Server-Keys generiert
✅ Default-Interface: eth0
✅ Konfiguration erstellt
✅ IP-Forwarding permanent aktiviert
✅ WireGuard-Service aktiv
```

**Schritt 2: Firewall-Regeln einrichten**

```bash
sudo ./setup-vpn-firewall.sh
```

Das Skript konfiguriert iptables für VPN-only Zugriff:
- WireGuard-Port (51820/UDP) öffentlich erreichbar
- HTTPS/HTTP (443/80 TCP) nur über VPN
- SSH, Prometheus, Grafana nur über VPN
- Public-Interfaces blocken Ports 80/443

**⚠️ WICHTIG:** Nach diesem Schritt sind Dienste nur noch über VPN erreichbar!

### Verifizierung

```bash
# WireGuard-Service-Status
sudo systemctl status wg-quick@wg0

# Interface-Status
sudo wg show wg0

# Firewall-Regeln
sudo iptables -L INPUT -n -v
```

---

## Client-Setup

### Client hinzufügen

**Neuen VPN-Client erstellen:**

```bash
sudo ./scripts/add-vpn-client.sh <client-name>
```

Beispiele:
```bash
sudo ./scripts/add-vpn-client.sh admin-laptop
sudo ./scripts/add-vpn-client.sh smartphone
sudo ./scripts/add-vpn-client.sh tablet
```

Das Skript generiert:
- Client-Keys (privat/öffentlich)
- Client-Konfigurationsdatei (`.conf`)
- QR-Code für mobile Geräte

**Ausgabe:**
```
✅ Client erfolgreich hinzugefügt!

📋 Client-Details:
   Name: admin-laptop
   IP: 10.80.1.2
   Konfiguration: /tmp/wireguard-clients/admin-laptop.conf
   QR-Code: /tmp/wireguard-clients/admin-laptop-qr.png

📱 QR-Code (für iOS/Android WireGuard-App):
[QR-Code wird im Terminal angezeigt]
```

### Plattform-spezifische Installation

#### iOS / Android

1. **WireGuard-App installieren:**
   - iOS: [App Store](https://apps.apple.com/app/wireguard/id1441195209)
   - Android: [Google Play](https://play.google.com/store/apps/details?id=com.wireguard.android)

2. **QR-Code scannen:**
   - App öffnen → "+" → "Create from QR code"
   - QR-Code scannen (wird vom Skript im Terminal angezeigt)

3. **VPN aktivieren:**
   - Toggle-Schalter in der App aktivieren

#### macOS / Linux

1. **WireGuard installieren:**
   ```bash
   # macOS (Homebrew)
   brew install wireguard-tools
   
   # Linux (Debian/Ubuntu)
   sudo apt install wireguard
   ```

2. **Konfiguration importieren:**
   ```bash
   sudo cp /tmp/wireguard-clients/admin-laptop.conf /etc/wireguard/admin-laptop.conf
   sudo chmod 600 /etc/wireguard/admin-laptop.conf
   ```

3. **VPN aktivieren:**
   ```bash
   sudo wg-quick up admin-laptop
   ```

4. **VPN deaktivieren:**
   ```bash
   sudo wg-quick down admin-laptop
   ```

5. **Auto-Start (optional):**
   ```bash
   sudo systemctl enable wg-quick@admin-laptop
   ```

#### Windows

1. **WireGuard für Windows installieren:**
   - Download: [WireGuard Website](https://www.wireguard.com/install/)

2. **Konfiguration importieren:**
   - WireGuard-App öffnen
   - "Import tunnel(s) from file" → `.conf`-Datei auswählen

3. **VPN aktivieren:**
   - "Activate" Button klicken

### Verbindung testen

Nach Aktivierung des VPN:

```bash
# Ping VPN-Server
ping 10.80.1.1

# HTTPS-Zugriff testen
curl -k https://10.80.1.1/health

# Dashboard öffnen
open https://10.80.1.1/  # macOS
xdg-open https://10.80.1.1/  # Linux
```

**Erwartete Ausgabe:**
```json
{"status":"ok"}
```

---

## Verwaltung

### Client auflisten

```bash
# Aktive VPN-Verbindungen anzeigen
sudo wg show wg0

# Detaillierte Peer-Informationen
sudo wg show wg0 dump
```

### Client entfernen (Peer-Revocation)

**Wichtig bei:**
- Key-Verlust oder -Kompromittierung
- Gerät wird nicht mehr verwendet
- Mitarbeiter verlässt Organisation

```bash
sudo ./scripts/remove-vpn-client.sh <client-name>
```

Beispiel:
```bash
sudo ./scripts/remove-vpn-client.sh old-laptop
```

Das Skript:
- Entfernt Peer aus Server-Konfiguration
- Lädt WireGuard-Config neu
- Erstellt Backup der alten Konfiguration

### VPN-Status über API abrufen

**Nur für Admins zugänglich:**

```bash
# Mit aktiver VPN-Verbindung und Login-Session
curl -k https://10.80.1.1/api/vpn/status \
  -H "Cookie: connect.sid=<session-cookie>"
```

**Antwort:**
```json
{
  "interface": "wg0",
  "publicKey": "ABC...DEF...",
  "listenPort": 51820,
  "peersCount": 3,
  "peersActive": 2,
  "peers": [
    {
      "publicKey": "XYZ...123...",
      "endpoint": "192.168.1.100:54321",
      "allowedIps": "10.80.1.2/32",
      "latestHandshake": "2025-10-15T10:30:00.000Z",
      "rxBytes": 1234567,
      "txBytes": 7654321,
      "active": true
    }
  ]
}
```

---

## Troubleshooting

### VPN-Verbindung schlägt fehl

**Problem:** Client kann sich nicht mit VPN verbinden

**Lösungen:**

1. **WireGuard-Port prüfen:**
   ```bash
   # Auf Server
   sudo ss -ulnp | grep 51820
   ```
   Erwartete Ausgabe: `udp UNCONN 0 0 *:51820 *:*`

2. **Firewall-Regeln prüfen:**
   ```bash
   sudo iptables -L INPUT -n | grep 51820
   ```

3. **NAT/Router-Konfiguration:**
   - Port 51820/UDP muss zum Jetson weitergeleitet werden
   - Bei Carrier-Grade NAT: Kontaktieren Sie Ihren ISP

4. **Server-Endpoint prüfen:**
   - Überprüfen Sie die `Endpoint`-Zeile in der Client-Config
   - Muss öffentliche IP oder DynDNS-Hostname enthalten

### Dienste nicht erreichbar über VPN

**Problem:** VPN verbunden, aber `https://10.80.1.1/` nicht erreichbar

**Lösungen:**

1. **VPN-IP prüfen:**
   ```bash
   # Auf Client
   ip addr show wg0  # Linux
   ifconfig utun3  # macOS
   ```
   Client sollte IP im 10.80.1.0/24-Range haben

2. **Routing prüfen:**
   ```bash
   ip route | grep 10.80.1.0
   ```

3. **DNS-Auflösung:**
   - Verwenden Sie direkt `https://10.80.1.1/`
   - Nicht `https://arasul.local/` (DNS-Auflösung über VPN nicht konfiguriert)

4. **TLS-Zertifikat:**
   - Bei Self-Signed: CA-Zertifikat importieren (siehe E1.2-Dokumentation)
   - Oder `-k` Flag bei curl verwenden

### Firewall-Tests fehlschlagen

**Problem:** Test-Skript meldet Fehler

```bash
sudo ./scripts/test-vpn-firewall.sh
```

**Häufige Fehler:**

1. **"WireGuard-Service nicht aktiv"**
   ```bash
   sudo systemctl start wg-quick@wg0
   sudo systemctl enable wg-quick@wg0
   ```

2. **"Public-IP nicht geblockt"** (SICHERHEITSRISIKO!)
   ```bash
   # Firewall-Regeln neu anwenden
   sudo ./scripts/setup-vpn-firewall.sh
   ```

3. **"iptables-persistent fehlt"**
   ```bash
   sudo apt install iptables-persistent
   sudo iptables-save > /etc/iptables/rules.v4
   ```

### DNS-Probleme

**Problem:** Keine Namensauflösung über VPN

**Lösung:** DNS-Server in Client-Config ändern

```ini
[Interface]
DNS = 1.1.1.1, 8.8.8.8
```

Oder öffentliche DNS verwenden:
- Cloudflare: 1.1.1.1
- Google: 8.8.8.8
- Quad9: 9.9.9.9

### Performance-Probleme

**Problem:** Langsame Verbindung über VPN

**Diagnose:**

```bash
# Auf Server: Aktive Peers anzeigen
sudo wg show wg0 transfer

# Auf Client: Ping-Latenz
ping 10.80.1.1
```

**Lösungen:**

1. **MTU optimieren** (Client-Config):
   ```ini
   [Interface]
   MTU = 1420  # Für PPPoE/DSL
   ```

2. **Keepalive reduzieren:**
   ```ini
   [Peer]
   PersistentKeepalive = 60  # Statt 25
   ```

3. **WireGuard-Kernel-Modul verwenden** (statt Userspace):
   ```bash
   lsmod | grep wireguard
   ```

---

## Sicherheit

### Best Practices

1. **Private-Keys schützen:**
   - **NIEMALS** in Git committen
   - Permissions: `chmod 600 /etc/wireguard/*.conf`
   - Backup verschlüsseln (z.B. mit GPG)

2. **QR-Codes nicht teilen:**
   - Enthalten Private-Key
   - Nicht in Screenshots/Logs
   - Nach Import löschen: `rm /tmp/wireguard-clients/*.png`

3. **Key-Rotation:**
   - Bei Verdacht auf Kompromittierung: sofort Peer entfernen
   - Reguläre Rotation alle 6-12 Monate (Phase 2)

4. **Client-Zugriff überwachen:**
   ```bash
   # Letzte Verbindung jedes Peers
   sudo wg show wg0 latest-handshakes
   ```

5. **Firewall-Regeln regelmäßig testen:**
   ```bash
   sudo ./scripts/test-vpn-firewall.sh
   ```

### Threat Model

**Bedrohungen:**

1. **VPN-Key-Diebstahl:**
   - Angreifer kann VPN nutzen
   - **Mitigation:** Peer sofort entfernen, neue Keys generieren

2. **Schwache Firewall-Regeln:**
   - Public-Exposure trotz VPN
   - **Mitigation:** Automatisierte Tests in CI/CD

3. **WireGuard-Downtime:**
   - Kein Zugriff auf System
   - **Mitigation:** Fallback-Zugriff via Local-LAN, systemd Auto-Restart

### Incident Response

**Bei Key-Kompromittierung:**

1. **Sofort Peer entfernen:**
   ```bash
   sudo ./scripts/remove-vpn-client.sh <kompromittierter-client>
   ```

2. **Audit-Logs prüfen:**
   ```bash
   # API-Zugriffe von kompromittiertem Client
   sudo journalctl -u wg-quick@wg0 | grep <client-ip>
   ```

3. **Neue Keys generieren:**
   ```bash
   sudo ./scripts/add-vpn-client.sh <client-name>-new
   ```

4. **Incident dokumentieren:**
   - Zeitpunkt der Kompromittierung
   - Betroffene Systeme
   - Durchgeführte Maßnahmen

---

## Referenzen

- [WireGuard Dokumentation](https://www.wireguard.com/)
- [Architektur-Shard 03: Security-Architektur](../architect.sharded/architect.03-security-architecture.md)
- [Architektur-Shard 10: Netzwerk & Ports](../architect.sharded/architect.10-network-ports.md)
- [Story E1.3: VPN-only Erreichbarkeit](../prd.sharded/epics/E1/E1.3.md)

---

**Version:** 1.0  
**Datum:** 15. Oktober 2025  
**Story:** E1.3 – VPN-only Erreichbarkeit

