# Prometheus & Grafana Deployment-Anleitung

## Status: ✅ DEPLOYED (Phase 1.5.1 - 2025-10-15)

Story E1.2 Phase 1.5.1

---

## Quick Start

```bash
# 1. Prometheus & Grafana starten
docker-compose up -d prometheus grafana

# 2. Health-Checks prüfen
docker-compose ps prometheus grafana

# 3. Prometheus UI öffnen
open http://localhost:9090

# 4. Grafana UI öffnen
open http://localhost:3001
# Login: admin / change-me-in-production

# 5. Integration-Test ausführen
./scripts/test-prometheus-integration.sh
```

---

## Komponenten

### Prometheus

**Image:** `prom/prometheus:v2.47.2`  
**Port:** 9090 (Prometheus UI)  
**UI:** http://localhost:9090

**Konfiguration:**
- Config: `/monitoring/prometheus/prometheus.yml`
- Alerts: `/monitoring/prometheus/alerts/security-headers.yml`
- Retention: 30 Tage
- Scrape-Interval: 15s

**Volumes:**
- `prometheus_data`: Persistenter Metriken-Storage
- Config & Alerts: Read-Only Mounts

**Health-Check:**
```bash
curl http://localhost:9090/-/healthy
```

### Grafana

**Image:** `grafana/grafana:10.2.2`  
**Port:** 3001 (mapped von 3000)  
**UI:** http://localhost:3001  
**Login:** admin / change-me-in-production

**Konfiguration:**
- Datasource Provisioning: `/monitoring/grafana/provisioning/datasources/prometheus.yml`
- Dashboard Provisioning: `/monitoring/grafana/provisioning/dashboards/default.yml`
- Dashboards: `/monitoring/grafana/dashboards/*.json`

**Volumes:**
- `grafana_data`: Persistenter Storage
- Provisioning: Read-Only Mounts
- Dashboards: Read-Only Mount

**Health-Check:**
```bash
curl http://localhost:3001/api/health
```

---

## Dashboards

### 1. Security Headers Monitoring
**UID:** `security-headers`  
**URL:** http://localhost:3001/d/security-headers

**Panels:**
- Security-Header Status (Bar Gauge)
- Fehlende Security-Header über Zeit (Timeseries)
- Top Endpoints mit fehlenden Headern (Table)
- Aktive Security-Header Alerts (Table)

**Metriken:**
- `security_header_status{header_name, endpoint}`
- `security_headers_missing_total{header_name, endpoint}`
- `ALERTS{alertstate="firing", category="headers"}`

### 2. TLS Compliance
**UID:** `tls-compliance`  
**URL:** http://localhost:3001/d/tls-compliance

**Panels:**
- TLS-Zertifikat Ablauf (Gauge)
- TLS-Version (Stat)
- TLS-Zertifikat Ablauf Timeline (Timeseries)
- Aktive TLS/Zertifikats-Alerts (Table)

**Metriken:**
- `tls_certificate_expiry_seconds`
- `tls_version{version}`
- `ALERTS{alertstate="firing", category=~"certificates|tls"}`

### 3. Application Performance
**UID:** `application-performance`  
**URL:** http://localhost:3001/d/application-performance

**Panels:**
- HTTP-Request-Rate nach Status-Code (Timeseries)
- Request-Latenz Percentiles (Timeseries)
- Server-Fehlerrate (Gauge)
- Aktive Sessions (Timeseries)
- Service-Status (Stat)
- Top 10 langsamste Endpoints (Table)

**Metriken:**
- `http_requests_total{method, route, status_code}`
- `http_request_duration_seconds{method, route, status_code}`
- `active_sessions_total`
- `up{job="arasul-api"}`

---

## Alerts

### Kritische Alerts (severity: critical)
- **MissingHSTSHeader** - HSTS fehlt (5min)
- **TLSCertificateExpiryCritical** - Cert <7 Tage
- **TLSCertificateExpired** - Cert abgelaufen
- **HighServerErrorRate** - >5% 5xx Errors
- **APIServiceDown** - API nicht erreichbar

### Wichtige Alerts (severity: high)
- **MissingCSPHeader** - CSP fehlt
- **MissingXFrameOptions** - XFO fehlt

### Warnungen (severity: warning/medium)
- **TLSCertificateExpiryWarning** - Cert <30 Tage
- **WeakTLSVersion** - TLS <1.3
- **HighRequestLatency** - p95 >2s
- **MissingXContentTypeOptions** - X-Content-Type-Options fehlt
- **HighMissingSecurityHeadersRate** - >10 req/s mit fehlenden Headern

### Alert-UI
- **Prometheus:** http://localhost:9090/alerts
- **Grafana:** Alerts in jedem Dashboard als Table

---

## Testing

### Unit-Tests
```bash
# Prometheus Monitoring Tests ausführen
cd /Users/koljaschope/Documents/dev/jetson/app
npm test -- e12_prometheus_monitoring.test.ts

# Erwartetes Ergebnis: 32/32 Tests erfolgreich
```

**Test-Coverage:**
- Metriken-Endpoint-Validierung
- Security-Header-Tracking
- HTTP-Metriken (Requests, Latenz)
- TLS-Metriken (Version, Cert-Expiry)
- Session-Metriken
- Alert-Simulationen
- Performance-Tests

### Integration-Tests
```bash
# Integration-Test ausführen
cd /Users/koljaschope/Documents/dev/jetson
./scripts/test-prometheus-integration.sh

# Erwartetes Ergebnis: 12/12 Validierungen erfolgreich
```

**Test-Validierungen:**
1. Docker Compose Syntax
2. Prometheus Container-Start
3. Prometheus Health-Check
4. Prometheus Config-Validierung
5. Alert-Regeln-Validierung
6. Prometheus Targets
7. Grafana Container-Start
8. Grafana Health-Check
9. Grafana Datasource
10. Grafana Dashboards (3)
11. Backend Metriken-Endpoint
12. Alert-Evaluation

---

## Security: Admin-Passwort ändern

### ⚠️ WICHTIG: Vor Production-Deployment!

**Default-Passwort:** `change-me-in-production`  
**Status:** ⚠️ **MUSS GEÄNDERT WERDEN!**

### Methode 1: Via Environment-Variable (empfohlen)

```bash
# 1. .env Datei erstellen
cd /Users/koljaschope/Documents/dev/jetson
cat > .env << 'EOF'
# Grafana Admin-Zugang
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=IhrSicheresPasswortHier123!

# Session-Secret für Express
SESSION_SECRET=$(openssl rand -hex 32)
EOF

# 2. Passwort generieren (empfohlen)
openssl rand -base64 24

# 3. Passwort in .env eintragen (obiges generiertes Passwort verwenden)
# nano .env  # oder vim/code

# 4. Container neu starten
docker-compose restart grafana

# 5. Login testen
open http://localhost:3001
# Login: admin / <IhrNeuesPasswort>
```

### Methode 2: Via Grafana UI

```bash
# 1. Grafana öffnen
open http://localhost:3001

# 2. Login mit Default-Passwort
# User: admin
# Password: change-me-in-production

# 3. Passwort ändern
# Grafana UI → Settings (Zahnrad unten links) → Profile → Change Password

# 4. Neues Passwort eingeben (min. 12 Zeichen)
```

### Passwort-Anforderungen

✅ **Best Practices:**
- Min. 12 Zeichen (empfohlen: 24+)
- Groß- und Kleinbuchstaben
- Zahlen und Sonderzeichen
- Keine Wörterbuchwörter
- Einzigartig (nicht wiederverwendet)

✅ **Passwort-Generierung:**
```bash
# Starkes Passwort (24 Zeichen)
openssl rand -base64 24

# Oder mit tr für URL-sichere Zeichen
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
```

✅ **Passwort-Speicherung:**
- Verwende einen Password-Manager (1Password, Bitwarden, etc.)
- **NIEMALS** Passwörter in Git committen
- .env ist bereits in .gitignore

### Verifizierung

```bash
# Login-Test
curl -u admin:IhrNeuesPasswort http://localhost:3001/api/health

# Erwartete Ausgabe: {"commit": "...", "database": "ok", "version": "10.2.2"}
```

---

## Troubleshooting

### Problem: Prometheus zeigt keine Metriken

**Diagnose:**
```bash
# API-Container Status prüfen
docker-compose ps api

# API-Metriken-Endpoint prüfen
curl http://localhost:3000/metrics

# Prometheus-Targets prüfen
open http://localhost:9090/targets
```

**Lösung:**
- API muss laufen: `docker-compose up -d api`
- Backend muss `/metrics` Endpoint exponieren (via prometheusService.ts)

### Problem: Grafana Dashboards fehlen

**Diagnose:**
```bash
# Grafana-Logs prüfen
docker-compose logs grafana | grep -i provisioning

# Dashboards-Verzeichnis prüfen
ls -la /Users/koljaschope/Documents/dev/jetson/monitoring/grafana/dashboards/
```

**Lösung:**
- Warten (~30s für Provisioning)
- Grafana neu starten: `docker-compose restart grafana`
- Manueller Import: Grafana UI → Dashboards → Import → JSON hochladen

### Problem: Alerts werden nicht ausgelöst

**Diagnose:**
```bash
# Alert-Regeln validieren
docker-compose exec prometheus promtool check rules /etc/prometheus/alerts/security-headers.yml

# Prometheus-Logs prüfen
docker-compose logs prometheus | grep -i alert
```

**Lösung:**
- Prometheus neu laden: `docker-compose restart prometheus`
- Evaluation-Interval abwarten (15s)

### Problem: Grafana Datasource nicht verbunden

**Diagnose:**
```bash
# Datasource testen (via API)
curl -u admin:change-me-in-production \
  http://localhost:3001/api/datasources/proxy/1/api/v1/query?query=up
```

**Lösung:**
- Datasource in Grafana UI testen: Settings → Data Sources → Prometheus → Test
- Prometheus muss erreichbar sein: http://prometheus:9090

---

## Monitoring Best Practices

### 1. Alert-Tuning
- **False Positives reduzieren:** `for` Dauer in Alert-Regeln anpassen
- **Thresholds anpassen:** Basierend auf Baseline (z.B. Error-Rate)

### 2. Dashboard-Organisation
- **Folder-Struktur:** Alle Dashboards im "Arasul" Folder
- **Naming Convention:** `<component>-<aspect>` (z.B. `security-headers`)
- **Tags:** Für Filterung und Suche

### 3. Retention-Management
- **Prometheus:** 30 Tage (Disk-Space beachten)
- **Grafana:** Persistenter Storage für Dashboards/Config

### 4. Performance
- **Scrape-Interval:** 15s (Standard)
- **Query-Performance:** Histogramme für Percentiles (p95, p99)
- **Dashboard-Refresh:** 30s-1m (nicht <10s)

---

## Backup & Restore

### Prometheus Backup
```bash
# Metriken-Daten sichern
docker run --rm \
  --volumes-from prometheus \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/prometheus-data.tar.gz /prometheus
```

### Grafana Backup
```bash
# Dashboards & Config sichern
docker run --rm \
  --volumes-from grafana \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/grafana-data.tar.gz /var/lib/grafana
```

### Restore
```bash
# Prometheus Restore
docker run --rm \
  --volumes-from prometheus \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/prometheus-data.tar.gz -C /

# Grafana Restore
docker run --rm \
  --volumes-from grafana \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/grafana-data.tar.gz -C /

# Container neu starten
docker-compose restart prometheus grafana
```

---

## Nächste Schritte

### Short-Term
1. ✅ Prometheus & Grafana deployen
2. ✅ Dashboards importieren
3. ✅ Tests ausführen
4. ⚠️ **API starten für vollständige Metriken:** `docker-compose up -d api`
5. ⚠️ **Grafana Admin-Passwort ändern** (siehe Abschnitt "Admin-Passwort ändern" oben)
6. ⚠️ **Environment-Variablen konfigurieren** (`.env` Datei erstellen)

### Mid-Term
1. Alertmanager konfigurieren (Slack/Email Notifications)
2. Grafana Reverse-Proxy via Caddy (Sub-Path `/monitor`)
3. Weitere Dashboards erstellen (Database, System-Metriken)
4. Backup-Automatisierung einrichten

### Long-Term
1. Multi-Tenancy in Grafana (Rollen/Teams)
2. Langzeit-Metriken-Storage (>30 Tage)
3. Distributed Tracing (Jaeger/Tempo)
4. Log-Aggregation (Loki)

---

## Ressourcen

- **Prometheus Dokumentation:** https://prometheus.io/docs/
- **Grafana Dokumentation:** https://grafana.com/docs/
- **prom-client (Node.js):** https://github.com/siimon/prom-client
- **Prometheus Best Practices:** https://prometheus.io/docs/practices/

---

**Version:** 1.0  
**Story:** E1.2 Phase 1.5.1  
**Autor:** Dev Agent (Claude Sonnet 4.5)  
**Datum:** 2025-10-15  
**Status:** ✅ DEPLOYED

