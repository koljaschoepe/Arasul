#!/bin/bash
# step-ca Certificate Renewal Script
# Story E1.2: Automatische Zertifikatserneuerung
# Dieses Skript erneuert Server-Zertifikate automatisch

set -euo pipefail

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Certificate Renewal ===${NC}"

CERT_FILE="/home/step/certs/arasul.local.crt"
EXPIRY_THRESHOLD=720 # 30 Tage in Stunden

# Prüfen ob Zertifikat existiert
if [ ! -f "$CERT_FILE" ]; then
  echo -e "${RED}✗ Zertifikat nicht gefunden: $CERT_FILE${NC}"
  exit 1
fi

# Verbleibende Gültigkeit prüfen
EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
HOURS_REMAINING=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 3600 ))

echo -e "${YELLOW}Zertifikat läuft ab: $EXPIRY_DATE${NC}"
echo -e "${YELLOW}Verbleibende Zeit: $HOURS_REMAINING Stunden${NC}"

# Prüfen ob Erneuerung erforderlich
if [ $HOURS_REMAINING -gt $EXPIRY_THRESHOLD ]; then
  echo -e "${GREEN}✓ Zertifikat noch gültig. Keine Erneuerung erforderlich.${NC}"
  exit 0
fi

echo -e "${YELLOW}⚠ Zertifikat läuft bald ab. Starte Erneuerung...${NC}"

# Backup des alten Zertifikats
cp "$CERT_FILE" "$CERT_FILE.backup.$(date +%s)"

# Neues Zertifikat generieren
step certificate create arasul.local \
  /home/step/certs/arasul.local.crt \
  /home/step/secrets/arasul.local.key \
  --profile leaf \
  --ca /home/step/certs/intermediate_ca.crt \
  --ca-key /home/step/secrets/intermediate_ca_key \
  --no-password \
  --insecure \
  --san arasul.local \
  --san localhost \
  --san 127.0.0.1 \
  --not-after 8760h \
  --force

echo -e "${GREEN}✓ Zertifikat erfolgreich erneuert!${NC}"
echo -e "${YELLOW}⚠ Caddy-Container muss neu gestartet werden:${NC}"
echo -e "docker-compose restart caddy"

