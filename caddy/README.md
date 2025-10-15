# Caddy TLS & Reverse-Proxy Konfiguration

## Übersicht

Caddy fungiert als TLS-Terminierungsproxy und Reverse-Proxy für alle Arasul-Services. Diese Konfiguration implementiert Story E1.2 (TLS & Security-Header A+).

## Architektur

```
Client (über WireGuard VPN)
    |
    v
Caddy (TLS-Terminierung, Port 443)
    |
    +-- / → Express Backend (Port 3000) [MVP: Admin-UI]
    +-- /api → Express Backend (Port 3000)
    +-- /health → Express Backend (Port 3000)
    +-- /n8n → n8n (Port 5678) [TODO: E2.x]
    +-- /minio → MinIO (Port 9001) [TODO: E3.x]
    +-- /guacamole → Guacamole (Port 8080) [TODO: E4.x]
    +-- /monitor → Monitoring UI (Port 3000) [TODO: E7.x]
```

## Security-Header-Strategie

### Caddy (Transport-Layer)
- **HSTS** (HTTP Strict Transport Security): `max-age=31536000; includeSubDomains`
- **Server-Header entfernt**: Verhindert Fingerprinting
- **TLS 1.3 bevorzugt**: Fallback auf TLS 1.2 mit sicheren Ciphers

### Helmet (Content-Layer - Express Backend)
- **CSP** (Content-Security-Policy): Mit `frame-src 'self'` für Guacamole-Iframe
- **X-Frame-Options**: `SAMEORIGIN`
- **X-Content-Type-Options**: `nosniff`
- **X-XSS-Protection**: `1; mode=block`
- **Referrer-Policy**: `strict-origin-when-cross-origin`

**Grund:** Helmet hat feinere Kontrolle über Content-Security und ist bereits konfiguriert. Caddy übernimmt nur Transport-Security.

## TLS-Zertifikate

### MVP (Aktuell)
- **Self-Signed Zertifikat**: Automatisch von Caddy via `tls internal` generiert
- **Domain**: `arasul.local`
- **Speicherort**: Docker Volume `caddy_data:/data`

### Phase 1.5 (Geplant)
- **step-ca**: Lokale Certificate Authority (CA)
- **Automatische Rotation**: Via step-ca Renewal
- **CA-Zertifikat**: Muss auf Clients importiert werden

## Verwendung

### 1. Caddy-Konfiguration validieren
```bash
docker run --rm -v $(pwd)/Caddyfile:/etc/caddy/Caddyfile caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
```

### 2. Caddy starten (via Docker Compose)
```bash
cd /path/to/jetson
docker-compose up -d caddy
```

### 3. Logs prüfen
```bash
docker logs -f caddy
```

### 4. TLS-Verbindung testen
```bash
# HTTPS-Erreichbarkeit
curl -k https://arasul.local/health

# HTTP→HTTPS Redirect
curl -I http://arasul.local
```

## Verifikation

### 1. Security-Header prüfen
```bash
curl -I -k https://arasul.local/api/health
```

**Erwartete Header:**
```
HTTP/2 200
strict-transport-security: max-age=31536000; includeSubDomains
content-security-policy: default-src 'self'; frame-src 'self'; ...
x-frame-options: SAMEORIGIN
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
```

### 2. SSL Labs Test (lokal)
```bash
# Via testssl.sh (Docker)
docker run --rm -ti drwetter/testssl.sh https://arasul.local

# Erwartetes Ergebnis:
# - Rating: A+
# - TLS 1.3 unterstützt
# - Perfect Forward Secrecy aktiv
# - Keine Warnungen
```

### 3. TLS-Protokoll-Test
```bash
# TLS 1.3
openssl s_client -connect arasul.local:443 -tls1_3

# TLS 1.2 (Fallback)
openssl s_client -connect arasul.local:443 -tls1_2

# TLS 1.1 (sollte fehlschlagen)
openssl s_client -connect arasul.local:443 -tls1_1
```

## Troubleshooting

### Problem: Browser zeigt "Unsichere Verbindung"
**Ursache:** Self-Signed Zertifikat wird nicht vertraut  
**Lösung:**
1. Zertifikat manuell akzeptieren (Browser-Warnung)
2. ODER: CA-Zertifikat importieren (empfohlen)

#### CA-Zertifikat exportieren
```bash
# Caddy CA-Zertifikat extrahieren
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > arasul_ca.crt
```

#### CA-Zertifikat importieren (macOS)
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain arasul_ca.crt
```

#### CA-Zertifikat importieren (Linux)
```bash
sudo cp arasul_ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Problem: HTTP→HTTPS Redirect funktioniert nicht
**Prüfung:**
```bash
curl -I http://arasul.local
# Erwarteter Output: HTTP/1.1 301 Moved Permanently
```

**Lösung:** Caddyfile prüfen - `redir` muss im HTTP-Block stehen

### Problem: Backend nicht erreichbar via Reverse-Proxy
**Prüfung:**
```bash
# Backend direkt testen (im Container-Netzwerk)
docker exec caddy wget -O- http://api:3000/health

# Caddy-Logs prüfen
docker logs caddy
```

**Lösung:** Docker-Netzwerk (`arasul-net`) und Service-Namen prüfen

### Problem: CSRF-Token funktioniert nicht über Reverse-Proxy
**Ursache:** CSRF-Cookies werden von Caddy cached/modifiziert  
**Lösung:** Caddy cached POST-Requests nicht (default), keine Aktion erforderlich

## Firewall-Konfiguration (VPN-only Zugriff)

### iptables-Regeln
```bash
# Port 443 nur über WireGuard (wg0) oder LAN
sudo iptables -A INPUT -i wg0 -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 443 -j DROP
sudo iptables -A INPUT -i wlan0 -p tcp --dport 443 -j DROP

# Port 80 nur über wg0/LAN (für Redirect)
sudo iptables -A INPUT -i wg0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -j DROP
sudo iptables -A INPUT -i wlan0 -p tcp --dport 80 -j DROP

# Regeln persistent speichern (Debian/Ubuntu)
sudo iptables-save > /etc/iptables/rules.v4
```

### Verifikation
```bash
# Von VPN-Client (sollte funktionieren)
curl -k https://arasul.local/health

# Von Public-IP (sollte timeout/blocked)
curl https://<public-ip>:443/health
```

## Netzwerk-Ports

| Port | Protokoll | Zugriff | Zweck |
|------|-----------|---------|-------|
| 443  | TCP       | VPN/LAN | HTTPS (TLS-Terminierung) |
| 80   | TCP       | VPN/LAN | HTTP→HTTPS Redirect |
| 51820 | UDP      | Public  | WireGuard VPN (E1.3) |

## Dateistruktur

```
jetson/
├── caddy/
│   ├── Caddyfile          # Haupt-Konfiguration
│   └── README.md          # Diese Datei
├── docker-compose.yml     # Caddy + Services
└── docs/
    └── deployment/
        └── tls-setup.md   # Detaillierte TLS-Dokumentation
```

## Migration zu step-ca (Phase 1.5)

**Aktuell:** `tls internal` (self-signed)  
**Zukünftig:** step-ca Integration

### Änderungen für step-ca
1. **Caddyfile anpassen:**
   ```caddyfile
   tls /certs/arasul.crt /certs/arasul.key {
       ca /certs/root_ca.crt
       protocols tls1.2 tls1.3
   }
   ```

2. **Docker Volume für Zertifikate:**
   ```yaml
   volumes:
     - ./step-ca/certs:/certs:ro
   ```

3. **step-ca Auto-Renewal:**
   - Cron-Job für `step ca renew`
   - Zertifikats-Rotation alle 90 Tage

## Referenzen

- **Story:** `docs/prd.sharded/epics/E1/E1.2.md`
- **Architektur:** `docs/architect.sharded/architect.03-security-architecture.md`
- **Ports:** `docs/architect.sharded/architect.10-network-ports.md`
- **Caddy Docs:** https://caddyserver.com/docs/
- **testssl.sh:** https://github.com/drwetter/testssl.sh

## Change Log

| Datum | Version | Beschreibung | Autor |
|-------|---------|--------------|-------|
| 2025-10-14 | 1.0 | Initiale Caddy-Konfiguration für E1.2 | Dev Agent |

