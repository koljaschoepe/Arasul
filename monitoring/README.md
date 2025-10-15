# Monitoring & Observability

## Übersicht

Diese Konfiguration implementiert umfassendes Monitoring für das Arasul-Projekt mit Fokus auf **Security-Header-Monitoring** (Story E1.2).

**Komponenten:**
- **Prometheus**: Metriken-Sammlung und Alerting
- **Grafana**: Visualisierung und Dashboards (E7.x)
- **Prom-Client**: Backend-Metriken-Exporter

## Architektur

```
┌─────────────────┐
│   Backend API   │  Exportiert Metriken (/metrics)
│  (prom-client)  │
└────────┬────────┘
         │ HTTP GET /metrics (15s)
         ↓
┌────────────────────┐
│   Prometheus       │  Sammelt Metriken, evaluiert Alerts
│ (Scraper + Rules)  │
└────────┬───────────┘
         │
    ┌────┴──────────────────┐
    │                       │
┌───▼──────┐         ┌──────▼────────┐
│ Grafana  │         │ Alertmanager  │
│ (Visualisierung)   │   (Optional)  │
└──────────┘         └───────────────┘
```

## Security-Header-Monitoring

### Überwachte Metriken

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `security_header_status` | Gauge | Status jedes Security-Headers (1 = vorhanden, 0 = fehlt) |
| `security_headers_missing_total` | Counter | Gesamtzahl der Requests mit fehlenden Headern |
| `tls_certificate_expiry_seconds` | Gauge | Sekunden bis zum Zertifikatsablauf |
| `tls_version` | Gauge | Verwendete TLS-Version (12 = 1.2, 13 = 1.3) |
| `http_requests_total` | Counter | Gesamtzahl HTTP-Requests |
| `http_request_duration_seconds` | Histogram | Request-Latenz |

### Alert-Regeln

#### Kritische Alerts (severity: critical)
- **MissingHSTSHeader**: HSTS-Header fehlt (kritisches Security-Risiko)
- **TLSCertificateExpiryCritical**: Zertifikat läuft in <7 Tagen ab
- **TLSCertificateExpired**: Zertifikat ist abgelaufen
- **HighServerErrorRate**: >5% Server-Fehler (5xx)
- **APIServiceDown**: API nicht erreichbar

#### Wichtige Alerts (severity: high)
- **MissingCSPHeader**: Content-Security-Policy fehlt
- **MissingXFrameOptions**: X-Frame-Options fehlt

#### Warnungen (severity: warning/medium)
- **TLSCertificateExpiryWarning**: Zertifikat läuft in <30 Tagen ab
- **WeakTLSVersion**: TLS 1.2 oder niedriger in Verwendung
- **HighRequestLatency**: 95% Requests >2s

## Setup

### 1. Prometheus aktivieren

```bash
# In docker-compose.yml Prometheus aktivieren
# (Siehe auskommentierte Konfiguration)

# Prometheus starten
docker-compose up -d prometheus

# Logs prüfen
docker-compose logs prometheus
```

### 2. Metriken prüfen

```bash
# Metriken manuell abrufen
curl http://localhost:3000/metrics

# Via Prometheus
open http://localhost:9090/graph
# Query: security_header_status
```

### 3. Alerts prüfen

```bash
# Alerts im Prometheus UI
open http://localhost:9090/alerts

# Alert-Regeln validieren
docker-compose exec prometheus promtool check rules /etc/prometheus/alerts/security-headers.yml
```

## Grafana-Dashboards (E7.x)

### Security-Header-Dashboard

**Visualisierungen:**
- Security-Header-Status (Heatmap)
- Fehlende Header über Zeit (Graph)
- Top-Endpoints mit fehlenden Headern (Table)
- Zertifikatsablauf (Gauge)
- TLS-Version-Distribution (Pie Chart)

**Import:**
```bash
# Dashboard-JSON wird in E7.x bereitgestellt
# Grafana → Dashboards → Import → Upload JSON
```

## Alerting-Integration

### Alertmanager (Optional)

```yaml
# docker-compose.yml
alertmanager:
  image: prom/alertmanager:latest
  volumes:
    - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
  ports:
    - "9093:9093"
```

**Notification-Channels:**
- Email (SMTP)
- Slack/Discord Webhooks
- PagerDuty (für Production)

### Alert-Konfiguration

```yaml
# monitoring/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: 'email-default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'email-default'
    email_configs:
      - to: 'admin@arasul.local'
        from: 'prometheus@arasul.local'
        smarthost: 'smtp.example.com:587'
        auth_username: 'prometheus'
        auth_password: '${SMTP_PASSWORD}'
```

## Custom Metriken

### Eigene Metriken hinzufügen

```typescript
// app/src/services/prometheusService.ts
import client from 'prom-client';

const myCustomMetric = new client.Counter({
  name: 'my_custom_metric_total',
  help: 'Description of my metric',
  labelNames: ['label1', 'label2'],
  registers: [register],
});

// Metrik inkrementieren
myCustomMetric.inc({ label1: 'value1', label2: 'value2' });
```

## Troubleshooting

### Problem: Prometheus zeigt keine Metriken

**Lösung:**
```bash
# API-Metriken-Endpoint prüfen
curl http://api:3000/metrics

# Prometheus-Targets prüfen
open http://localhost:9090/targets

# Prometheus-Logs
docker-compose logs prometheus
```

### Problem: Alerts werden nicht ausgelöst

**Lösung:**
```bash
# Alert-Regeln validieren
docker-compose exec prometheus promtool check rules /etc/prometheus/alerts/*.yml

# Evaluation-Interval prüfen
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml | grep evaluation_interval

# Prometheus neu laden
docker-compose exec prometheus kill -HUP 1
```

### Problem: Fehlende Security-Header-Metriken

**Lösung:**
```bash
# Backend-Logs prüfen
docker-compose logs api

# Middleware-Reihenfolge prüfen (server.ts)
# trackSecurityHeaders muss VOR routes registriert sein
```

## Performance-Optimierung

### Metriken-Retention

```yaml
# prometheus.yml
storage:
  tsdb:
    retention.time: 30d
    retention.size: 10GB
```

### Scrape-Intervall anpassen

```yaml
# Für High-Traffic Systeme
global:
  scrape_interval: 30s  # Statt 15s
```

## Security-Hinweise

- ⚠️ `/metrics` Endpoint sollte nur intern erreichbar sein (nicht öffentlich exponieren)
- ✅ Basic-Auth für Prometheus-Scraper (optional)
- ✅ Prometheus hinter Reverse-Proxy mit Authentifizierung
- ✅ Metriken enthalten keine sensiblen Daten (Passwords, Tokens)

## Weitere Ressourcen

- [Prometheus Dokumentation](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [prom-client API](https://github.com/siimon/prom-client)
- [Alert Best Practices](https://prometheus.io/docs/practices/alerting/)

---

**Version:** 1.0  
**Story:** E1.2 (Prometheus Integration)  
**Autor:** Dev Agent (Claude Sonnet 4.5)  
**Datum:** 2025-10-14

