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

## Weitere Skripte

*Weitere Skripte werden in zukünftigen Stories hinzugefügt.*

## Berechtigungen

Skripte ausführbar machen:
```bash
chmod +x scripts/*.sh
```

## Referenzen

- **Story E1.2:** `/docs/prd.sharded/epics/E1/E1.2.md`
- **TLS-Setup:** `/docs/deployment/tls-setup.md`
- **Caddy-Konfiguration:** `/caddy/README.md`

