# TLS & Security-Setup (Story E1.2)

## Übersicht

Dieses Dokument beschreibt die TLS-Konfiguration und Security-Header-Implementierung für das Arasul-System gemäß Story E1.2.

## Architektur

### Security-Header-Strategie

**Caddy (Transport-Layer)**
- HSTS (HTTP Strict Transport Security)
- Server-Header-Entfernung
- TLS 1.3 Terminierung

**Helmet (Content-Layer - Express)**
- Content-Security-Policy (CSP)
- X-Frame-Options
- X-Content-Type-Options
- Referrer-Policy
- X-XSS-Protection
- Permissions-Policy

**Begründung:** Caddy handhabt Transport-Security, Helmet Content-Security für feinere Kontrolle.

## Setup-Anleitung

### 1. Voraussetzungen

```bash
# Docker & Docker Compose installiert
docker --version
docker-compose --version

# Projekt klonen (falls nicht vorhanden)
cd /path/to/jetson
```

### 2. Umgebungsvariablen konfigurieren

```bash
# .env-Datei erstellen
cp .env.example .env

# SESSION_SECRET ändern (KRITISCH für Produktion!)
nano .env
```

**Wichtige Variablen:**
```env
SESSION_SECRET=generate-strong-random-string-here
NODE_ENV=production
DATABASE_URL=file:./dev.db
```

### 3. TLS-Zertifikate (Self-Signed)

Caddy generiert automatisch self-signed Zertifikate via `tls internal`:

```bash
# Keine manuelle Aktion erforderlich
# Caddy erstellt Zertifikate beim ersten Start
```

### 4. Services starten

```bash
# Docker Compose Build & Start
docker-compose up -d --build

# Logs prüfen
docker-compose logs -f caddy
docker-compose logs -f api
```

### 5. Health-Checks

```bash
# Backend-API direkt (Container-Netzwerk)
docker exec api wget -O- http://localhost:3000/health

# Via Caddy Reverse-Proxy
curl -k https://arasul.local/health

# HTTP→HTTPS Redirect
curl -I http://arasul.local
# Erwartung: HTTP/1.1 301 Moved Permanently
```

## Verifikation

### 1. TLS-Protokoll-Test

```bash
# TLS 1.3 (sollte funktionieren)
openssl s_client -connect arasul.local:443 -tls1_3

# TLS 1.2 (sollte funktionieren - Fallback)
openssl s_client -connect arasul.local:443 -tls1_2

# TLS 1.1 (sollte fehlschlagen)
openssl s_client -connect arasul.local:443 -tls1_1
```

### 2. Security-Header-Verifikation

```bash
# Alle Security-Header prüfen
curl -I -k https://arasul.local/health
```

**Erwartete Header:**
```http
HTTP/2 200
strict-transport-security: max-age=31536000; includeSubDomains
content-security-policy: default-src 'self'; frame-src 'self'; ...
x-frame-options: SAMEORIGIN
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
permissions-policy: ...
```

### 3. SSL Labs Test (lokal via testssl.sh)

```bash
# testssl.sh via Docker
docker run --rm -ti drwetter/testssl.sh https://arasul.local

# Erwartetes Ergebnis:
# - Rating: A+ (oder A mit self-signed)
# - TLS 1.3: Ja
# - Perfect Forward Secrecy: Ja
# - Schwache Ciphers: Nein
```

### 4. Browser-Test

```bash
# DNS-Eintrag für arasul.local (lokal)
echo "127.0.0.1 arasul.local" | sudo tee -a /etc/hosts

# Browser öffnen
open https://arasul.local
```

**Erwartung:**
- Browser-Warnung: "Unsichere Verbindung" (self-signed Zertifikat)
- Nach Akzeptanz: Dashboard sollte laden
- DevTools → Network → Response Headers prüfen

## Self-Signed Zertifikat vertrauen

### macOS

```bash
# CA-Zertifikat von Caddy extrahieren
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > arasul_ca.crt

# In System-Keychain importieren
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain arasul_ca.crt

# Browser neu starten
```

### Linux (Ubuntu/Debian)

```bash
# CA-Zertifikat extrahieren
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > arasul_ca.crt

# In System-CA-Store kopieren
sudo cp arasul_ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Browser neu starten
```

### Windows

```bash
# CA-Zertifikat extrahieren (WSL/PowerShell)
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > arasul_ca.crt

# Doppelklick auf arasul_ca.crt
# → "Zertifikat installieren"
# → "Lokaler Computer"
# → "Vertrauenswürdige Stammzertifizierungsstellen"
```

## Firewall-Konfiguration (VPN-only)

### iptables-Regeln

```bash
# Port 443 nur über WireGuard (wg0) oder LAN
sudo iptables -A INPUT -i wg0 -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -i lo -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 443 -j DROP
sudo iptables -A INPUT -i wlan0 -p tcp --dport 443 -j DROP

# Port 80 nur über wg0/LAN (für Redirect)
sudo iptables -A INPUT -i wg0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i lo -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -j DROP
sudo iptables -A INPUT -i wlan0 -p tcp --dport 80 -j DROP

# Regeln persistent speichern
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### Verifikation

```bash
# Von VPN-Client (sollte funktionieren)
curl -k https://arasul.local/health

# Von Public-IP (sollte timeout/blocked)
curl --max-time 5 https://<public-ip>:443/health
# Erwartung: Timeout/Connection refused
```

## Automatisierte Tests

```bash
# Unit-Tests (E1.2 Security-Header)
cd /path/to/jetson/app
npm test -- e12_tls_security_headers.test.ts

# Erwartung: Alle Tests grün
```

## Migration zu step-ca (Phase 1.5)

**Aktuell:** Self-signed Zertifikat via Caddy `tls internal`  
**Zukünftig:** step-ca (lokale Certificate Authority)

### Schritte für Migration

1. **step-ca installieren & konfigurieren**
   ```bash
   wget https://dl.step.sm/gh-release/cli/docs-ca-install/v0.25.0/step-ca_linux_0.25.0_amd64.tar.gz
   tar xzf step-ca_linux_0.25.0_amd64.tar.gz
   sudo mv step-ca /usr/local/bin/
   ```

2. **CA initialisieren**
   ```bash
   step ca init --deployment-type standalone --name "Arasul CA" --dns arasul.local
   ```

3. **Zertifikat für arasul.local erstellen**
   ```bash
   step ca certificate arasul.local arasul.crt arasul.key
   ```

4. **Caddyfile anpassen**
   ```caddyfile
   tls /certs/arasul.crt /certs/arasul.key {
       ca /certs/root_ca.crt
       protocols tls1.2 tls1.3
   }
   ```

5. **Docker Volume für Zertifikate**
   ```yaml
   volumes:
     - ./step-ca/certs:/certs:ro
   ```

6. **Cron-Job für Auto-Renewal**
   ```bash
   0 2 * * * step ca renew /certs/arasul.crt /certs/arasul.key --force
   ```

## Troubleshooting

### Problem: Browser zeigt "ERR_SSL_PROTOCOL_ERROR"

**Mögliche Ursachen:**
1. Caddy läuft nicht: `docker-compose ps`
2. Port 443 nicht erreichbar: `netstat -tuln | grep 443`
3. Firewall blockiert: `sudo iptables -L -n`

**Lösung:**
```bash
# Caddy-Logs prüfen
docker logs caddy

# Firewall-Regeln temporär deaktivieren (Test)
sudo iptables -P INPUT ACCEPT
```

### Problem: HSTS-Header fehlt

**Prüfung:**
```bash
curl -I -k https://arasul.local/health | grep -i strict-transport
```

**Ursache:** Caddy setzt Header nicht  
**Lösung:** Caddyfile prüfen - `header { Strict-Transport-Security "..." }` vorhanden?

### Problem: CSP blockiert Ressourcen

**Symptom:** Browser-Console zeigt CSP-Violations  
**Prüfung:** DevTools → Console → CSP-Fehler lesen

**Lösung:** Helmet-Konfiguration in `server.ts` anpassen:
```typescript
contentSecurityPolicy: {
  directives: {
    scriptSrc: ["'self'", "'unsafe-inline'", "cdn.example.com"],  // CDN hinzufügen
  }
}
```

### Problem: Session-Cookies funktionieren nicht über HTTPS

**Symptom:** Login funktioniert nicht, Session wird nicht gespeichert  
**Ursache:** `secure: true` in Cookie-Optionen, aber kein HTTPS in Tests

**Lösung:** In `server.ts`:
```typescript
cookie: {
  secure: process.env.NODE_ENV === 'production',  // False in Development/Tests
  httpOnly: true,
  sameSite: 'strict',
}
```

### Problem: Caddy Reverse-Proxy leitet nicht weiter

**Symptom:** 502 Bad Gateway  
**Prüfung:**
```bash
# Backend direkt testen
docker exec api wget -O- http://localhost:3000/health

# Caddy-Container → API-Container
docker exec caddy wget -O- http://api:3000/health
```

**Lösung:** Docker-Netzwerk prüfen - beide Container müssen im selben Netzwerk sein (`arasul-net`)

## Monitoring & Alerts

### Zertifikatsablauf überwachen

```bash
# Skript für Zertifikatsablauf-Check
#!/bin/bash
CERT_FILE="/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/arasul.local/arasul.local.crt"
EXPIRY=$(docker exec caddy openssl x509 -enddate -noout -in $CERT_FILE)
echo "Zertifikatsablauf: $EXPIRY"
```

### TLS-Protokoll-Logs

```bash
# Caddy-Access-Logs aktivieren (optional)
# In Caddyfile:
log {
  output file /var/log/caddy/access.log
  format json
}
```

## Referenzen

- **Story:** `/docs/prd.sharded/epics/E1/E1.2.md`
- **Architektur:** `/docs/architect.sharded/architect.03-security-architecture.md`
- **Caddy Docs:** https://caddyserver.com/docs/
- **Helmet Docs:** https://helmetjs.github.io/
- **testssl.sh:** https://github.com/drwetter/testssl.sh
- **SSL Labs:** https://www.ssllabs.com/ssltest/

## Change Log

| Datum | Version | Beschreibung | Autor |
|-------|---------|--------------|-------|
| 2025-10-14 | 1.0 | TLS-Setup-Dokumentation für E1.2 | Dev Agent |

