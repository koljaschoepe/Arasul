#!/bin/bash
# Integration Test für Prometheus & Grafana Deployment
# Story E1.2 Phase 1.5

set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Prometheus & Grafana Integration Test"
echo "Story E1.2 Phase 1.5"
echo "=========================================="
echo ""

# ==========================================================================
# Helper Functions
# ==========================================================================

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  exit 1
}

warn() {
  echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

# ==========================================================================
# Test 1: Docker Compose Syntax
# ==========================================================================

echo "Test 1: Docker Compose Syntax validieren..."
if docker-compose config > /dev/null 2>&1; then
  pass "Docker Compose Syntax korrekt"
else
  fail "Docker Compose Syntax fehlerhaft"
fi

# ==========================================================================
# Test 2: Prometheus Container starten
# ==========================================================================

echo ""
echo "Test 2: Prometheus Container starten..."
docker-compose up -d prometheus 2>&1 | grep -q "Started" || true
sleep 5

if docker-compose ps prometheus | grep -q "Up"; then
  pass "Prometheus Container läuft"
else
  fail "Prometheus Container konnte nicht gestartet werden"
fi

# ==========================================================================
# Test 3: Prometheus Health-Check
# ==========================================================================

echo ""
echo "Test 3: Prometheus Health-Check..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
    pass "Prometheus Health-Check erfolgreich"
    break
  fi
  
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    fail "Prometheus Health-Check fehlgeschlagen nach $MAX_ATTEMPTS Versuchen"
  fi
  
  echo "  Warte auf Prometheus... ($ATTEMPT/$MAX_ATTEMPTS)"
  sleep 2
  ATTEMPT=$((ATTEMPT + 1))
done

# ==========================================================================
# Test 4: Prometheus Konfiguration validieren
# ==========================================================================

echo ""
echo "Test 4: Prometheus Konfiguration validieren..."
if docker-compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml > /dev/null 2>&1; then
  pass "Prometheus Konfiguration gültig"
else
  fail "Prometheus Konfiguration ungültig"
fi

# ==========================================================================
# Test 5: Alert-Regeln validieren
# ==========================================================================

echo ""
echo "Test 5: Alert-Regeln validieren..."
if docker-compose exec -T prometheus promtool check rules /etc/prometheus/alerts/security-headers.yml > /dev/null 2>&1; then
  pass "Alert-Regeln syntaktisch korrekt"
else
  fail "Alert-Regeln enthalten Fehler"
fi

# ==========================================================================
# Test 6: Prometheus Targets prüfen
# ==========================================================================

echo ""
echo "Test 6: Prometheus Targets prüfen..."
sleep 5 # Warten bis Scrape durchgeführt wurde

if curl -sf http://localhost:9090/api/v1/targets | grep -q '"health":"up"'; then
  pass "Prometheus scrapet Targets erfolgreich"
else
  warn "Prometheus-Targets noch nicht up (API muss laufen)"
fi

# ==========================================================================
# Test 7: Grafana Container starten
# ==========================================================================

echo ""
echo "Test 7: Grafana Container starten..."
docker-compose up -d grafana 2>&1 | grep -q "Started" || true
sleep 10

if docker-compose ps grafana | grep -q "Up"; then
  pass "Grafana Container läuft"
else
  fail "Grafana Container konnte nicht gestartet werden"
fi

# ==========================================================================
# Test 8: Grafana Health-Check
# ==========================================================================

echo ""
echo "Test 8: Grafana Health-Check..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  if curl -sf http://localhost:3001/api/health > /dev/null 2>&1; then
    pass "Grafana Health-Check erfolgreich"
    break
  fi
  
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    fail "Grafana Health-Check fehlgeschlagen nach $MAX_ATTEMPTS Versuchen"
  fi
  
  echo "  Warte auf Grafana... ($ATTEMPT/$MAX_ATTEMPTS)"
  sleep 2
  ATTEMPT=$((ATTEMPT + 1))
done

# ==========================================================================
# Test 9: Grafana Datasource prüfen
# ==========================================================================

echo ""
echo "Test 9: Grafana Datasource prüfen..."
sleep 5

DATASOURCES=$(curl -sf -u admin:change-me-in-production http://localhost:3001/api/datasources 2>/dev/null || echo "[]")

if echo "$DATASOURCES" | grep -q "Prometheus"; then
  pass "Grafana Datasource 'Prometheus' konfiguriert"
else
  warn "Grafana Datasource 'Prometheus' nicht gefunden (Provisioning dauert evtl. länger)"
fi

# ==========================================================================
# Test 10: Grafana Dashboards prüfen
# ==========================================================================

echo ""
echo "Test 10: Grafana Dashboards prüfen..."

DASHBOARDS=$(curl -sf -u admin:change-me-in-production http://localhost:3001/api/search?type=dash-db 2>/dev/null || echo "[]")

EXPECTED_DASHBOARDS=("security-headers" "tls-compliance" "application-performance")
FOUND_COUNT=0

for DASHBOARD in "${EXPECTED_DASHBOARDS[@]}"; do
  if echo "$DASHBOARDS" | grep -q "$DASHBOARD"; then
    pass "Dashboard '$DASHBOARD' importiert"
    FOUND_COUNT=$((FOUND_COUNT + 1))
  else
    warn "Dashboard '$DASHBOARD' nicht gefunden (Provisioning dauert evtl. länger)"
  fi
done

if [ $FOUND_COUNT -eq 3 ]; then
  pass "Alle 3 Dashboards erfolgreich importiert"
elif [ $FOUND_COUNT -gt 0 ]; then
  warn "$FOUND_COUNT von 3 Dashboards importiert (Provisioning evtl. noch nicht abgeschlossen)"
else
  warn "Keine Dashboards gefunden (Provisioning dauert evtl. länger)"
fi

# ==========================================================================
# Test 11: Prometheus Metriken-Endpoint prüfen
# ==========================================================================

echo ""
echo "Test 11: Backend Metriken-Endpoint prüfen..."

# Nur prüfen wenn API läuft
if docker-compose ps api | grep -q "Up"; then
  if curl -sf http://localhost:3000/metrics | grep -q "security_header_status"; then
    pass "Backend Metriken-Endpoint funktioniert"
  else
    warn "Backend Metriken-Endpoint antwortet nicht korrekt (API muss laufen)"
  fi
else
  warn "API-Container läuft nicht (manuell starten für vollständigen Test)"
fi

# ==========================================================================
# Test 12: Alert-Evaluation prüfen
# ==========================================================================

echo ""
echo "Test 12: Alert-Evaluation prüfen..."

ALERTS=$(curl -sf http://localhost:9090/api/v1/rules 2>/dev/null || echo "{}")

if echo "$ALERTS" | grep -q "security_headers"; then
  pass "Alert-Regeln werden evaluiert"
else
  fail "Alert-Regeln werden nicht evaluiert"
fi

# ==========================================================================
# Zusammenfassung
# ==========================================================================

echo ""
echo "=========================================="
echo "Integration Test abgeschlossen"
echo "=========================================="
echo ""
echo "Prometheus UI: http://localhost:9090"
echo "Grafana UI: http://localhost:3001 (admin / change-me-in-production)"
echo ""
echo "Nächste Schritte:"
echo "1. Grafana Login durchführen"
echo "2. Dashboards überprüfen"
echo "3. Alert-Regeln in Prometheus UI prüfen (http://localhost:9090/alerts)"
echo "4. API starten für vollständige Metriken: docker-compose up -d api"
echo ""

