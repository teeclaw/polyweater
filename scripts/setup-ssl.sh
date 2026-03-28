#!/bin/bash

# PolyWeather SSL Certificate Setup
# Creates self-signed certificates for secure access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_DIR/ssl"

echo "🔐 Setting up SSL certificates for PolyWeather dashboard..."

# Create SSL directory
mkdir -p "$SSL_DIR"
cd "$SSL_DIR"

# Generate strong DH parameters
echo "⚙️  Generating DH parameters (this may take a while)..."
if [[ ! -f dhparam.pem ]]; then
    openssl dhparam -out dhparam.pem 2048
    echo "✅ DH parameters generated"
else
    echo "✅ DH parameters already exist"
fi

# Get external IP for certificate
EXTERNAL_IP=""
if command -v curl >/dev/null 2>&1; then
    EXTERNAL_IP=$(curl -s --connect-timeout 5 ifconfig.me || echo "")
fi

if [[ -z "$EXTERNAL_IP" ]]; then
    EXTERNAL_IP=$(hostname -I | awk '{print $1}')
fi

echo "📡 Detected external IP: $EXTERNAL_IP"

# Create certificate configuration
cat > openssl.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Digital
L = Cloud
O = PolyWeather Trading
OU = Security Department
CN = polyweather.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = polyweather.local
DNS.2 = localhost
DNS.3 = *.polyweather.local
IP.1 = 127.0.0.1
IP.2 = $EXTERNAL_IP
EOF

# Generate private key
echo "🔑 Generating private key..."
if [[ ! -f polyweather.key ]]; then
    openssl genrsa -out polyweather.key 4096
    chmod 600 polyweather.key
    echo "✅ Private key generated"
else
    echo "✅ Private key already exists"
fi

# Generate certificate signing request
echo "📝 Generating certificate signing request..."
openssl req -new -key polyweather.key -out polyweather.csr -config openssl.conf

# Generate self-signed certificate
echo "📜 Generating self-signed certificate..."
openssl x509 -req -in polyweather.csr -signkey polyweather.key -out polyweather.crt -days 365 -extensions v3_req -extfile openssl.conf

# Set proper permissions
chmod 644 polyweather.crt
chmod 600 polyweather.key
chmod 644 dhparam.pem

echo "✅ SSL certificates generated successfully!"
echo ""
echo "📋 Certificate Information:"
openssl x509 -in polyweather.crt -text -noout | grep -A 5 "Subject Alternative Name"

echo ""
echo "🚀 Next steps:"
echo "1. Import polyweather.crt into your browser's trusted certificates"
echo "2. Access dashboard via: https://$EXTERNAL_IP"
echo "3. Or add '${EXTERNAL_IP} polyweather.local' to your /etc/hosts file"
echo "   Then access via: https://polyweather.local"
echo ""
echo "📁 Certificate files location: $SSL_DIR/"
echo "   - polyweather.crt (certificate)"
echo "   - polyweather.key (private key)"
echo "   - dhparam.pem (DH parameters)"