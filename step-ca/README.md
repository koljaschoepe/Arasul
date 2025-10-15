# step-ca Certificate Authority

## Übersicht

Diese Konfiguration implementiert eine lokale Certificate Authority (CA) mit [smallstep/step-ca](https://smallstep.com/docs/step-ca) für das Arasul-Projekt.

**Story:** E1.2 (Phase 1.5 - step-ca Migration)

## Architektur

```
┌─────────────────┐
│   Clients       │  Importieren Root CA (einmalig)
│ (Browser/Tools) │
└────────┬────────┘
         │ HTTPS
         ↓
┌────────────────────┐
│   Caddy            │  TLS-Terminierung mit step-ca Zertifikaten
│ (Reverse Proxy)    │
└────────┬───────────┘
         │
    ┌────┴──────────────────┐
    │                       │
┌───▼──────┐         ┌──────▼────┐
│ step-ca  │         │  Backend  │
│   CA     │         │    API    │
└──────────┘         └───────────┘
```

## Vorteile gegenüber Self-Signed

| Aspekt | Self-Signed | step-ca |
|--------|-------------|---------|
| Browser-Warnung | Bei jedem Service | Nur einmaliger CA-Import |
| Zertifikatsverwaltung | Manuell | Automatisch |
| Zertifikatsrotation | Manuell | Automatisiert (Cron) |
| Multi-Service Support | Einzeln pro Service | Zentral für alle Services |
| Professionalität | MVP | Production-Ready |

## Setup

### 1. Initiale CA-Einrichtung

```bash
# step-ca Container starten
docker-compose up -d step-ca

# CA initialisieren (einmalig)
docker-compose exec step-ca /scripts/init-ca.sh

# Root CA-Zertifikat exportieren
docker cp step-ca:/home/step/certs/root_ca.crt ./root_ca.crt
```

### 2. Root CA auf Clients importieren

#### macOS
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ./root_ca.crt
```

#### Linux (Debian/Ubuntu)
```bash
sudo cp root_ca.crt /usr/local/share/ca-certificates/arasul-root-ca.crt
sudo update-ca-certificates
```

#### Windows (PowerShell als Admin)
```powershell
Import-Certificate -FilePath ".\root_ca.crt" `
  -CertStoreLocation Cert:\LocalMachine\Root
```

#### Browser (Firefox)
```
Einstellungen → Datenschutz & Sicherheit → Zertifikate anzeigen
→ Zertifizierungsstellen → Importieren → root_ca.crt
```

### 3. Caddy mit step-ca Zertifikaten konfigurieren

Die Caddyfile wurde bereits für step-ca vorbereitet. Aktivieren Sie die entsprechende Konfiguration:

```caddyfile
# Alte Konfiguration (Self-Signed):
# tls internal {
#     protocols tls1.2 tls1.3
# }

# Neue Konfiguration (step-ca):
tls /certs/arasul.local.crt /certs/arasul.local.key {
    protocols tls1.2 tls1.3
}
```

### 4. Services neu starten

```bash
docker-compose restart caddy
docker-compose ps
```

## Automatische Zertifikatserneuerung

Ein Cron-Job im step-ca Container erneuert Zertifikate automatisch 30 Tage vor Ablauf.

**Manuelle Erneuerung:**
```bash
docker-compose exec step-ca /scripts/renew-cert.sh
docker-compose restart caddy
```

**Cron-Job-Konfiguration (bereits in docker-compose.yml):**
```cron
# Täglich um 3:00 Uhr prüfen
0 3 * * * /scripts/renew-cert.sh >> /var/log/cert-renewal.log 2>&1
```

## Verzeichnisstruktur

```
step-ca/
├── config/
│   └── ca.json                 # step-ca Konfiguration
├── scripts/
│   ├── init-ca.sh              # CA-Initialisierung
│   └── renew-cert.sh           # Zertifikatserneuerung
├── certs/                      # Volume: Zertifikate (generiert)
│   ├── root_ca.crt
│   ├── intermediate_ca.crt
│   └── arasul.local.crt
├── secrets/                    # Volume: Private Keys (generiert)
│   ├── root_ca_key
│   ├── intermediate_ca_key
│   └── arasul.local.key
└── db/                         # Volume: step-ca Datenbank
```

## Zertifikatsdetails

### Root CA
- **Subject:** `CN=Arasul Root CA`
- **Gültigkeit:** 10 Jahre
- **Key-Type:** RSA 4096
- **Verwendung:** Trust Anchor (einmaliger Import auf Clients)

### Intermediate CA
- **Subject:** `CN=Arasul Intermediate CA`
- **Gültigkeit:** 5 Jahre
- **Key-Type:** RSA 2048
- **Verwendung:** Signieren von Server-Zertifikaten

### Server-Zertifikat (arasul.local)
- **Subject:** `CN=arasul.local`
- **SANs:** `arasul.local`, `localhost`, `127.0.0.1`
- **Gültigkeit:** 1 Jahr (automatische Erneuerung)
- **Key-Type:** RSA 2048
- **Verwendung:** TLS in Caddy

## Monitoring

### Zertifikatsablauf prüfen
```bash
# Caddy-Zertifikat
docker-compose exec step-ca openssl x509 -enddate -noout \
  -in /home/step/certs/arasul.local.crt

# Root CA
docker-compose exec step-ca openssl x509 -enddate -noout \
  -in /home/step/certs/root_ca.crt
```

### Logs prüfen
```bash
# Renewal-Logs
docker-compose exec step-ca cat /var/log/cert-renewal.log

# step-ca Logs
docker-compose logs step-ca
```

## Troubleshooting

### Problem: "Certificate has expired"
**Lösung:** Zertifikat manuell erneuern
```bash
docker-compose exec step-ca /scripts/renew-cert.sh
docker-compose restart caddy
```

### Problem: "unable to get local issuer certificate"
**Lösung:** Root CA auf Client importieren (siehe Setup Schritt 2)

### Problem: step-ca Container startet nicht
**Lösung:** Logs prüfen und CA neu initialisieren
```bash
docker-compose logs step-ca
docker-compose down -v
docker-compose up -d step-ca
docker-compose exec step-ca /scripts/init-ca.sh
```

## Migration von Self-Signed zu step-ca

### Schritt 1: Backup
```bash
docker-compose exec caddy tar czf /data/caddy-backup.tar.gz /data /config
docker cp caddy:/data/caddy-backup.tar.gz ./
```

### Schritt 2: step-ca einrichten (siehe Setup oben)

### Schritt 3: Caddyfile anpassen
```bash
# caddy/Caddyfile editieren (siehe Schritt 3 oben)
```

### Schritt 4: Docker Compose aktualisieren
```bash
docker-compose up -d
docker-compose restart caddy
```

### Schritt 5: Verifizieren
```bash
./scripts/verify-tls.sh arasul.local
```

## Security-Hinweise

- ⚠️ **Private Keys niemals committen!** (`secrets/` ist in `.gitignore`)
- ⚠️ **Root CA-Key schützen!** Nur im step-ca Container
- ✅ **Cron-Job prüfen:** Automatische Erneuerung sollte laufen
- ✅ **Monitoring:** Prometheus Alert bei Zertifikatsablauf (siehe E7.x)

## Weitere Ressourcen

- [step-ca Dokumentation](https://smallstep.com/docs/step-ca)
- [Certificate Lifecycle](https://smallstep.com/docs/step-ca/certificate-authority-server-production#certificate-lifecycle)
- [Best Practices](https://smallstep.com/docs/step-ca/certificate-authority-server-production)

---

**Version:** 1.0  
**Story:** E1.2 (Phase 1.5)  
**Autor:** Dev Agent (Claude Sonnet 4.5)  
**Datum:** 2025-10-14

