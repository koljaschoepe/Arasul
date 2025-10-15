# Arasul Scripts

Dieses Verzeichnis enthält Utility-Skripte für Setup, Testing und Wartung des Arasul-Systems.

## Story E1.2: TLS & Security-Header

### 1. TLS-Verifikation (`verify-tls.sh`)

Testet TLS-Konfiguration und Security-Header.

**Verwendung:**
```bash
# Standard (arasul.local)
./scripts/verify-tls.sh

# Custom Domain
./scripts/verify-tls.sh my-domain.local
```

**Testet:**
- HTTPS-Erreichbarkeit
- HTTP→HTTPS Redirect
- Security-Header (HSTS, CSP, XFO, etc.)
- TLS-Protokoll-Versionen (1.3, 1.2)
- Cipher-Suites & Perfect Forward Secrecy
- Zertifikat-Info

### 2. SSL Labs Test (`ssl-labs-test.sh`)

Führt umfassenden TLS/SSL-Test via `testssl.sh` durch.

**Verwendung:**
```bash
# Standard (arasul.local)
./scripts/ssl-labs-test.sh

# Custom Domain
./scripts/ssl-labs-test.sh my-domain.local
```

**Erwartetes Ergebnis:**
- Rating: A+ (oder A mit self-signed)
- TLS 1.3: Supported
- Perfect Forward Secrecy: Yes
- Schwache Ciphers: Keine

### 3. CA-Zertifikat Export (`export-ca-cert.sh`)

Exportiert Caddy CA-Zertifikat für Client-Trust.

**Verwendung:**
```bash
# Export nach ./certs/
./scripts/export-ca-cert.sh

# Custom Output-Verzeichnis
./scripts/export-ca-cert.sh /tmp/certs
```

**Nach Export:**
1. Zertifikat in System-Trust-Store importieren (siehe Script-Output)
2. Browser neu starten
3. Keine Zertifikatswarnung mehr bei https://arasul.local

### 4. Prometheus Integration Test (`test-prometheus-integration.sh`)

Testet Prometheus-Metriken-Erfassung.

**Verwendung:**
```bash
./scripts/test-prometheus-integration.sh
```

## Story E1.3: VPN-only Erreichbarkeit

### 1. WireGuard-Server Setup (`setup-wireguard.sh`)

Installiert und konfiguriert WireGuard VPN-Server.

**Verwendung:**
```bash
# Als root ausführen
sudo ./scripts/setup-wireguard.sh
```

**Durchgeführte Schritte:**
- WireGuard-Installation
- Server-Keys generieren
- wg0-Interface konfigurieren
- systemd-Service aktivieren
- IP-Forwarding aktivieren

### 2. VPN-Firewall Setup (`setup-vpn-firewall.sh`)

Konfiguriert iptables für VPN-only Zugriff.

**Verwendung:**
```bash
# Als root ausführen
sudo ./scripts/setup-vpn-firewall.sh
```

**Konfiguriert:**
- WireGuard-Port (51820/UDP) öffentlich
- HTTPS/HTTP (443/80) nur über VPN
- SSH, Monitoring nur über VPN
- Public-Interfaces blocken

**⚠️ WICHTIG:** Nach diesem Schritt nur noch VPN-Zugriff möglich!

### 3. VPN-Client hinzufügen (`add-vpn-client.sh`)

Erstellt neue VPN-Client-Konfiguration.

**Verwendung:**
```bash
# Client hinzufügen
sudo ./scripts/add-vpn-client.sh <client-name>

# Beispiele
sudo ./scripts/add-vpn-client.sh admin-laptop
sudo ./scripts/add-vpn-client.sh smartphone
```

**Generiert:**
- Client-Keys (privat/öffentlich)
- Client-Konfigurationsdatei (`.conf`)
- QR-Code für mobile Geräte

**Ausgabe-Verzeichnis:** `/tmp/wireguard-clients/`

### 4. VPN-Client entfernen (`remove-vpn-client.sh`)

Entfernt VPN-Client (Peer-Revocation).

**Verwendung:**
```bash
# Client entfernen
sudo ./scripts/remove-vpn-client.sh <client-name>

# Beispiel
sudo ./scripts/remove-vpn-client.sh old-laptop
```

**Anwendungsfälle:**
- Key-Kompromittierung
- Gerät nicht mehr verwendet
- Zugriff widerrufen

### 5. VPN & Firewall Tests (`test-vpn-firewall.sh`)

Testet VPN-Konfiguration und Firewall-Regeln.

**Verwendung:**
```bash
# Als root ausführen
sudo ./scripts/test-vpn-firewall.sh
```

**Testet:**
- WireGuard-Service-Status
- WireGuard-Interface vorhanden
- VPN-Erreichbarkeit (10.80.1.1)
- Public-IP-Blockade
- Firewall-Regeln aktiv
- IP-Forwarding aktiviert

## Weitere Skripte

*Weitere Skripte werden in zukünftigen Stories hinzugefügt.*

## Berechtigungen

Skripte ausführbar machen:
```bash
chmod +x scripts/*.sh
```

## Referenzen

- **Story E1.2:** `/docs/prd.sharded/epics/E1/E1.2.md`
- **Story E1.3:** `/docs/prd.sharded/epics/E1/E1.3.md`
- **TLS-Setup:** `/docs/deployment/tls-setup.md`
- **VPN-Setup:** `/docs/deployment/vpn-setup.md`
- **Caddy-Konfiguration:** `/caddy/README.md`

