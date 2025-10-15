#!/bin/bash
# Story E1.2: TLS & Security-Header Verifikation
# Testet TLS-Konfiguration und Security-Header

set -e

# Farben für Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Konfiguration
DOMAIN="${1:-arasul.local}"
SKIP_SSL_VERIFY="-k"  # Self-signed Zertifikate akzeptieren

echo "=========================================="
echo "TLS & Security-Header Verifikation (E1.2)"
echo "=========================================="
echo ""
echo "Domain: $DOMAIN"
echo ""

# Funktion: Test ausführen und Ergebnis anzeigen
run_test() {
    local test_name="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "Testing: $test_name ... "
    
    if output=$(eval "$command" 2>&1); then
        if [ -z "$expected" ] || echo "$output" | grep -q "$expected"; then
            echo -e "${GREEN}✓ PASS${NC}"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}"
            echo "  Expected: $expected"
            echo "  Got: $output"
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Error: $output"
        return 1
    fi
}

# 1. HTTPS-Erreichbarkeit testen
echo "=== 1. HTTPS-Erreichbarkeit ==="
run_test "HTTPS /health erreichbar" \
    "curl -s $SKIP_SSL_VERIFY https://$DOMAIN/health" \
    "ok"
echo ""

# 2. HTTP→HTTPS Redirect testen
echo "=== 2. HTTP→HTTPS Redirect ==="
run_test "HTTP Redirect (301)" \
    "curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN" \
    "301"
echo ""

# 3. Security-Header testen
echo "=== 3. Security-Header ==="

# HSTS (von Caddy gesetzt)
run_test "HSTS Header (Caddy)" \
    "curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'strict-transport-security'" \
    "max-age=31536000"

# CSP (von Helmet gesetzt)
run_test "CSP Header (Helmet)" \
    "curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'content-security-policy'" \
    "default-src"

# X-Frame-Options (von Helmet gesetzt)
run_test "X-Frame-Options Header" \
    "curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'x-frame-options'" \
    "SAMEORIGIN"

# X-Content-Type-Options (von Helmet gesetzt)
run_test "X-Content-Type-Options Header" \
    "curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'x-content-type-options'" \
    "nosniff"

# Referrer-Policy (von Helmet gesetzt)
run_test "Referrer-Policy Header" \
    "curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'referrer-policy'" \
    "strict-origin-when-cross-origin"

# Permissions-Policy (von Helmet gesetzt)
run_test "Permissions-Policy Header" \
    "curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'permissions-policy'" \
    ""  # Nur prüfen, dass Header existiert

echo ""

# 4. Server-Header Fingerprinting
echo "=== 4. Server-Header Fingerprinting ==="

# Server-Header sollte entfernt sein (von Caddy)
if curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -qi 'server:'; then
    SERVER_HEADER=$(curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'server:')
    echo -e "Server Header: ${YELLOW}⚠ PRESENT${NC} ($SERVER_HEADER)"
else
    echo -e "Server Header: ${GREEN}✓ REMOVED${NC}"
fi

# X-Powered-By sollte entfernt sein (von Helmet)
if curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -qi 'x-powered-by:'; then
    POWERED_BY=$(curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health | grep -i 'x-powered-by:')
    echo -e "X-Powered-By Header: ${RED}✗ PRESENT${NC} ($POWERED_BY)"
else
    echo -e "X-Powered-By Header: ${GREEN}✓ REMOVED${NC}"
fi

echo ""

# 5. TLS-Protokoll-Test
echo "=== 5. TLS-Protokoll-Test ==="

# TLS 1.3 (sollte funktionieren)
if openssl s_client -connect $DOMAIN:443 -tls1_3 </dev/null 2>&1 | grep -q "Protocol.*TLSv1.3"; then
    echo -e "TLS 1.3: ${GREEN}✓ SUPPORTED${NC}"
else
    echo -e "TLS 1.3: ${YELLOW}⚠ NOT SUPPORTED${NC}"
fi

# TLS 1.2 (sollte funktionieren - Fallback)
if openssl s_client -connect $DOMAIN:443 -tls1_2 </dev/null 2>&1 | grep -q "Protocol.*TLSv1.2"; then
    echo -e "TLS 1.2: ${GREEN}✓ SUPPORTED${NC}"
else
    echo -e "TLS 1.2: ${RED}✗ NOT SUPPORTED${NC}"
fi

# TLS 1.1 (sollte NICHT funktionieren)
if openssl s_client -connect $DOMAIN:443 -tls1_1 </dev/null 2>&1 | grep -q "Protocol.*TLSv1.1"; then
    echo -e "TLS 1.1: ${RED}✗ SHOULD BE DISABLED${NC}"
else
    echo -e "TLS 1.1: ${GREEN}✓ DISABLED${NC}"
fi

echo ""

# 6. Cipher-Suite-Test
echo "=== 6. Cipher-Suite-Test ==="
CIPHERS=$(openssl s_client -connect $DOMAIN:443 -tls1_3 </dev/null 2>&1 | grep "Cipher" | head -1)
echo "Cipher (TLS 1.3): $CIPHERS"

# Perfect Forward Secrecy prüfen
if echo "$CIPHERS" | grep -qE "(ECDHE|DHE)"; then
    echo -e "Perfect Forward Secrecy: ${GREEN}✓ ACTIVE${NC}"
else
    echo -e "Perfect Forward Secrecy: ${YELLOW}⚠ CHECK MANUALLY${NC}"
fi

echo ""

# 7. Zertifikat-Info
echo "=== 7. Zertifikat-Info ==="
CERT_INFO=$(openssl s_client -connect $DOMAIN:443 </dev/null 2>&1)

ISSUER=$(echo "$CERT_INFO" | grep "issuer=" | head -1)
SUBJECT=$(echo "$CERT_INFO" | grep "subject=" | head -1)
EXPIRY=$(echo "$CERT_INFO" | openssl x509 -noout -enddate 2>&1 | grep "notAfter")

echo "$ISSUER"
echo "$SUBJECT"
echo "$EXPIRY"

# Self-signed Check
if echo "$CERT_INFO" | grep -q "self signed certificate"; then
    echo -e "Type: ${YELLOW}⚠ SELF-SIGNED${NC} (OK für MVP, step-ca in Phase 1.5)"
fi

echo ""

# 8. Vollständiger Header-Dump (optional)
echo "=== 8. Vollständiger Header-Dump ==="
echo "Headers von https://$DOMAIN/health:"
echo "---"
curl -s -I $SKIP_SSL_VERIFY https://$DOMAIN/health
echo "---"

echo ""
echo "=========================================="
echo "Verifikation abgeschlossen!"
echo "=========================================="
echo ""
echo "Hinweise:"
echo "- Self-signed Zertifikate: CA-Import empfohlen (siehe docs/deployment/tls-setup.md)"
echo "- SSL Labs Test: 'docker run --rm -ti drwetter/testssl.sh https://$DOMAIN'"
echo "- Firewall-Regeln: Manuell verifizieren (nur VPN/LAN Zugriff)"

