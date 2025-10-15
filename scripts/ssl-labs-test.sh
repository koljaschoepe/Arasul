#!/bin/bash
# Story E1.2: SSL Labs Test (via testssl.sh)
# Führt umfassenden TLS/SSL-Test durch

set -e

# Konfiguration
DOMAIN="${1:-arasul.local}"

echo "=========================================="
echo "SSL Labs Test (via testssl.sh) - E1.2"
echo "=========================================="
echo ""
echo "Domain: $DOMAIN"
echo ""
echo "Hinweis: testssl.sh ist ein umfassendes TLS/SSL-Testtool."
echo "         Dieser Test kann mehrere Minuten dauern."
echo ""

# Prüfen ob testssl.sh lokal installiert ist
if command -v testssl.sh &> /dev/null; then
    echo "Verwende lokale testssl.sh Installation..."
    testssl.sh --fast --severity HIGH https://$DOMAIN
else
    echo "testssl.sh nicht gefunden. Verwende Docker-Image..."
    echo ""
    
    # testssl.sh via Docker ausführen
    docker run --rm -ti \
        --network host \
        drwetter/testssl.sh \
        --fast \
        --severity HIGH \
        --color 3 \
        https://$DOMAIN
fi

echo ""
echo "=========================================="
echo "SSL Labs Test abgeschlossen!"
echo "=========================================="
echo ""
echo "Erwartetes Ergebnis für A+ Rating:"
echo "- TLS 1.3: Supported"
echo "- TLS 1.2: Supported (Fallback)"
echo "- TLS 1.0/1.1: NOT Supported"
echo "- Perfect Forward Secrecy: Yes"
echo "- HSTS: max-age=31536000"
echo "- Schwache Ciphers: Keine"
echo ""
echo "Für detaillierten Report:"
echo "  testssl.sh --full https://$DOMAIN"

