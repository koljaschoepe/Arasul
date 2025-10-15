#!/bin/bash
# Story E1.2: CA-Zertifikat exportieren (für Client-Trust)
# Exportiert Caddy CA-Zertifikat für manuellen Import

set -e

# Konfiguration
OUTPUT_DIR="${1:-./certs}"
CA_CERT_FILE="$OUTPUT_DIR/arasul_ca.crt"

echo "=========================================="
echo "CA-Zertifikat Export (E1.2)"
echo "=========================================="
echo ""

# Output-Verzeichnis erstellen
mkdir -p "$OUTPUT_DIR"

# CA-Zertifikat von Caddy extrahieren
echo "Extrahiere CA-Zertifikat von Caddy..."
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > "$CA_CERT_FILE"

echo -e "\n✓ CA-Zertifikat exportiert: $CA_CERT_FILE"
echo ""

# Zertifikat-Info anzeigen
echo "Zertifikat-Info:"
echo "---"
openssl x509 -in "$CA_CERT_FILE" -text -noout | grep -E "(Issuer|Subject|Not After)"
echo "---"
echo ""

# Plattform-spezifische Import-Anleitung
echo "=========================================="
echo "Import-Anleitung (Trust Store)"
echo "=========================================="
echo ""

OS_TYPE=$(uname -s)

case "$OS_TYPE" in
    Darwin*)
        echo "macOS:"
        echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CA_CERT_FILE"
        echo ""
        echo "Alternativ:"
        echo "  1. Doppelklick auf $CA_CERT_FILE"
        echo "  2. Schlüsselbundverwaltung öffnet sich"
        echo "  3. Zertifikat zu 'System' hinzufügen"
        echo "  4. Doppelklick → 'Vertrauen' → 'Immer vertrauen'"
        ;;
    
    Linux*)
        echo "Linux (Ubuntu/Debian):"
        echo "  sudo cp $CA_CERT_FILE /usr/local/share/ca-certificates/"
        echo "  sudo update-ca-certificates"
        echo ""
        echo "Linux (RHEL/CentOS):"
        echo "  sudo cp $CA_CERT_FILE /etc/pki/ca-trust/source/anchors/"
        echo "  sudo update-ca-trust"
        ;;
    
    MINGW*|MSYS*|CYGWIN*)
        echo "Windows:"
        echo "  1. Doppelklick auf $CA_CERT_FILE"
        echo "  2. 'Zertifikat installieren' → 'Lokaler Computer'"
        echo "  3. 'Vertrauenswürdige Stammzertifizierungsstellen'"
        echo "  4. Browser neu starten"
        echo ""
        echo "Alternativ (PowerShell als Admin):"
        echo "  Import-Certificate -FilePath '$CA_CERT_FILE' -CertStoreLocation Cert:\LocalMachine\Root"
        ;;
    
    *)
        echo "Unbekanntes OS: $OS_TYPE"
        echo "Manuelle Import-Anleitung:"
        echo "  1. CA-Zertifikat zu System-Trust-Store hinzufügen"
        echo "  2. Browser neu starten"
        ;;
esac

echo ""
echo "=========================================="
echo "Nach Import:"
echo "=========================================="
echo "  1. Browser neu starten"
echo "  2. https://arasul.local öffnen"
echo "  3. Keine Zertifikatswarnung mehr ✓"
echo ""

