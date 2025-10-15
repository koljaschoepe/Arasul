#!/bin/bash
# step-ca Initialization Script
# Story E1.2: step-ca Migration (Phase 1.5)
# Dieses Skript initialisiert die step-ca Certificate Authority

set -euo pipefail

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== step-ca Initialization ===${NC}"

# Verzeichnisse erstellen
mkdir -p /home/step/certs
mkdir -p /home/step/secrets
mkdir -p /home/step/db
mkdir -p /home/step/config

# Prüfen ob CA bereits initialisiert
if [ -f "/home/step/certs/root_ca.crt" ]; then
  echo -e "${YELLOW}⚠ CA bereits initialisiert. Überspringe Initialisierung.${NC}"
  exit 0
fi

echo -e "${GREEN}✓ Generiere Root CA...${NC}"

# Root CA generieren
step certificate create "Arasul Root CA" \
  /home/step/certs/root_ca.crt \
  /home/step/secrets/root_ca_key \
  --profile root-ca \
  --no-password \
  --insecure \
  --kty RSA \
  --size 4096 \
  --not-after 87600h

echo -e "${GREEN}✓ Generiere Intermediate CA...${NC}"

# Intermediate CA generieren
step certificate create "Arasul Intermediate CA" \
  /home/step/certs/intermediate_ca.crt \
  /home/step/secrets/intermediate_ca_key \
  --profile intermediate-ca \
  --ca /home/step/certs/root_ca.crt \
  --ca-key /home/step/secrets/root_ca_key \
  --no-password \
  --insecure \
  --kty RSA \
  --size 2048 \
  --not-after 43800h

echo -e "${GREEN}✓ Generiere Server-Zertifikat für arasul.local...${NC}"

# Server-Zertifikat für arasul.local
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
  --not-after 8760h

echo -e "${GREEN}✓ Setze Berechtigungen...${NC}"

# Berechtigungen setzen
chmod 600 /home/step/secrets/*
chmod 644 /home/step/certs/*

echo -e "${GREEN}✓ CA-Initialisierung abgeschlossen!${NC}"
echo ""
echo -e "${YELLOW}Root CA Zertifikat: /home/step/certs/root_ca.crt${NC}"
echo -e "${YELLOW}Server-Zertifikat: /home/step/certs/arasul.local.crt${NC}"
echo -e "${YELLOW}Server-Key: /home/step/secrets/arasul.local.key${NC}"
echo ""
echo -e "${GREEN}Zum Importieren des Root CA auf Clients:${NC}"
echo -e "docker cp step-ca:/home/step/certs/root_ca.crt ./root_ca.crt"

