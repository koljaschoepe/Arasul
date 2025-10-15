# Arasul Startup-Anleitung

**Story:** E1.2 - TLS & Security-Header A+  
**Version:** 1.0  
**Datum:** 2025-10-15

---

## Quick Start

### 1. Docker starten

```bash
# Docker Desktop öffnen (macOS)
open -a Docker

# Warten bis Docker läuft (ca. 10-20 Sekunden)
# Indicator: Docker-Icon in Menüleiste zeigt grünen Punkt
```

### 2. Environment-Variablen konfigurieren

```bash
cd /Users/koljaschope/Documents/dev/jetson

# .env Datei erstellen (WICHTIG: Passwörter ändern!)
cat > .env << 'EOF'
# Grafana Admin-Zugang
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)

# Session-Secret für Express (32 Zeichen)
SESSION_SECRET=$(openssl rand -hex 32)
EOF

# Sicheres Passwort generieren und in .env eintragen
echo "Generiertes Grafana-Passwort:"
openssl rand -base64 24

# Öffne .env und ersetze $(openssl rand -base64 24) mit obigem Passwort
code .env  # oder nano .env
```

### 3. Container starten

```bash
# Alle Container starten (API, Prometheus, Grafana)
docker-compose up -d

# Status prüfen
docker-compose ps

# Logs anzeigen
docker-compose logs -f
```

### 4. Health-Checks

```bash
# API-Health-Check
curl http://localhost:3000/health
# Erwartet: {"status":"ok","timestamp":"..."}

# Prometheus Health-Check
curl http://localhost:9090/-/healthy
# Erwartet: HTTP 200 OK

# Grafana Health-Check
curl http://localhost:3001/api/health
# Erwartet: {"commit":"...","database":"ok","version":"10.2.2"}
```

### 5. UIs öffnen

```bash
# API-Metriken
open http://localhost:3000/metrics

# Prometheus UI
open http://localhost:9090

# Grafana UI (Login: admin / <IhrPasswortAus.env>)
open http://localhost:3001
```

---

## Vollständiger Start-Prozess

### Phase 1: Vorbereitung

```bash
# 1. Repository-Verzeichnis
cd /Users/koljaschope/Documents/dev/jetson

# 2. Docker starten
open -a Docker

# 3. Warten (10-20 Sekunden)
# Verifizierung:
docker ps
# Sollte keine Fehler zeigen

# 4. .env Datei erstellen (siehe Abschnitt 2 oben)
```

### Phase 2: Erste Startup

```bash
# Container builden und starten
docker-compose up -d --build

# Erwartete Ausgabe:
# [+] Building ...
# [+] Running 4/4
#  ✔ Container step-ca       Started
#  ✔ Container api           Started
#  ✔ Container prometheus    Started
#  ✔ Container grafana       Started
```

### Phase 3: Verifizierung

```bash
# Container-Status
docker-compose ps

# Erwartete Ausgabe (alle "Up"):
# NAME        IMAGE                      STATUS              PORTS
# api         jetson-api                Up (healthy)        3000/tcp
# grafana     grafana/grafana:10.2.2    Up (healthy)        0.0.0.0:3001->3000/tcp
# prometheus  prom/prometheus:v2.47.2   Up (healthy)        0.0.0.0:9090->9090/tcp
# step-ca     smallstep/step-ca:latest  Up                  9000/tcp

# Health-Checks (warten 30 Sekunden für Startup)
sleep 30

curl http://localhost:3000/health      # API
curl http://localhost:9090/-/healthy   # Prometheus
curl http://localhost:3001/api/health  # Grafana
```

### Phase 4: Tests ausführen

```bash
# Integration-Tests
./scripts/test-prometheus-integration.sh

# Erwartetes Ergebnis:
# ✅ 12/12 Validierungen erfolgreich

# Unit-Tests
cd app
npm test

# Erwartetes Ergebnis:
# ✅ 42/42 Tests erfolgreich
```

---

## Troubleshooting

### Problem: "Cannot connect to Docker daemon"

**Ursache:** Docker Desktop läuft nicht

**Lösung:**
```bash
# Docker Desktop starten
open -a Docker

# Warten bis Docker-Icon grün ist (10-20 Sekunden)

# Erneut versuchen
docker ps
```

### Problem: Container startet nicht (Unhealthy)

**Diagnose:**
```bash
# Logs anzeigen
docker-compose logs <container-name>

# Beispiel: API-Container
docker-compose logs api
```

**Häufige Ursachen:**
- **API:** Datenbank-Migration fehlt → `docker-compose exec api npx prisma migrate deploy`
- **Prometheus:** Config-Syntax-Fehler → `docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml`
- **Grafana:** Provisioning-Fehler → `docker-compose logs grafana | grep -i provisioning`

### Problem: .env Datei fehlt

**Symptome:**
- Grafana Login: "Invalid credentials"
- API: Session-Fehler

**Lösung:**
```bash
# .env erstellen (siehe Abschnitt 2)
cd /Users/koljaschope/Documents/dev/jetson

cat > .env << 'EOF'
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=IhrSicheresPasswort
SESSION_SECRET=$(openssl rand -hex 32)
EOF

# Container neu starten
docker-compose restart
```

### Problem: Port bereits belegt

**Symptome:**
```
Error: bind: address already in use
```

**Diagnose:**
```bash
# Prüfen welcher Prozess Port belegt
lsof -i :3000  # API
lsof -i :3001  # Grafana
lsof -i :9090  # Prometheus
```

**Lösung:**
```bash
# Option 1: Prozess beenden
kill -9 <PID>

# Option 2: Port in docker-compose.yml ändern
# z.B. "3002:3000" statt "3001:3000"
```

---

## Container-Management

### Stoppen

```bash
# Alle Container stoppen
docker-compose down

# Container stoppen + Volumes löschen (ACHTUNG: Datenverlust!)
docker-compose down -v
```

### Neu starten

```bash
# Einzelnen Container neu starten
docker-compose restart api

# Alle Container neu starten
docker-compose restart
```

### Logs anzeigen

```bash
# Alle Logs (live)
docker-compose logs -f

# Einzelner Container
docker-compose logs -f api

# Letzte 100 Zeilen
docker-compose logs --tail=100 api
```

### Updates

```bash
# Code-Änderungen deployen (rebuild)
docker-compose up -d --build api

# Images aktualisieren
docker-compose pull
docker-compose up -d
```

---

## Checkliste: Production-Ready

Vor dem Production-Deployment:

- [ ] ✅ Docker läuft
- [ ] ✅ .env Datei erstellt
- [ ] ⚠️ **ALLE Passwörter in .env geändert** (siehe monitoring/DEPLOYMENT.md)
- [ ] ✅ Container gestartet (`docker-compose up -d`)
- [ ] ✅ Health-Checks grün (alle Container "Up (healthy)")
- [ ] ✅ Integration-Tests erfolgreich (`./scripts/test-prometheus-integration.sh`)
- [ ] ✅ Unit-Tests erfolgreich (`cd app && npm test`)
- [ ] ⚠️ Grafana Admin-Passwort geändert (siehe monitoring/DEPLOYMENT.md)
- [ ] ⚠️ Grafana Dashboards sichtbar (3 Dashboards im "Arasul" Folder)
- [ ] ⚠️ Prometheus Targets aktiv (`http://localhost:9090/targets` → "api" = UP)
- [ ] ⚠️ API-Metriken erreichbar (`curl http://localhost:3000/metrics`)

**Story-Dependencies:**
- [ ] E1.3 (VPN-only Zugriff) implementiert
- [ ] Firewall-Regeln aktiv (Port 443 nur über VPN)

---

## Nächste Schritte

**Short-Term (heute):**
1. Docker starten
2. .env konfigurieren
3. Container starten
4. Tests ausführen
5. Grafana-Passwort ändern

**Mid-Term (diese Woche):**
1. E1.3 (VPN-only Zugriff) implementieren
2. Manual TLS-Tests durchführen
3. Prometheus-Alerts testen

**Long-Term (nächste Woche):**
1. Production-Deployment vorbereiten
2. Backup-Strategie implementieren
3. Monitoring-Dashboards fine-tunen

---

## Weitere Ressourcen

- **Monitoring-Deployment:** [monitoring/DEPLOYMENT.md](./monitoring/DEPLOYMENT.md)
- **Passwort-Änderung:** [monitoring/DEPLOYMENT.md#security-admin-passwort-ändern](./monitoring/DEPLOYMENT.md#security-admin-passwort-ändern)
- **TLS-Setup:** [docs/deployment/tls-setup.md](./docs/deployment/tls-setup.md)
- **Story E1.2:** [docs/prd.sharded/epics/E1/E1.2.md](./docs/prd.sharded/epics/E1/E1.2.md)

---

**Version:** 1.0  
**Story:** E1.2 Phase 1.5.1  
**Autor:** Dev Agent (Claude Sonnet 4.5)  
**Datum:** 2025-10-15

