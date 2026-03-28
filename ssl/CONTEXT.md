# ssl/ - SSL Certificates & Encryption

## PURPOSE
SSL/TLS certificate management for secure HTTPS communication, database encryption, and service-to-service authentication.

## CERTIFICATE STRUCTURE
```
ssl/
├── polyweather.key        # Private key for HTTPS
├── polyweather.crt        # SSL certificate for domain
├── polyweather.csr        # Certificate signing request
├── dhparam.pem           # Diffie-Hellman parameters for Perfect Forward Secrecy
└── openssl.conf          # OpenSSL configuration for certificate generation
```

## ENCRYPTION COVERAGE
### Web Services
- **Dashboard Access**: HTTPS encryption for Streamlit (Port 3000)
- **API Endpoints**: Secure backend API communication (Port 8080)
- **WebSocket**: WSS encryption for real-time data (Port 8765)

### Database Connections  
- **PostgreSQL**: Client-server SSL encryption
- **Redis**: TLS-enabled cache connections (if configured)

## CERTIFICATE DETAILS
- **Type**: Self-signed for development, Let's Encrypt recommended for production
- **Validity**: 365 days (annual renewal required)
- **Key Length**: 2048-bit RSA or 256-bit ECDSA  
- **Cipher Suites**: Modern TLS 1.2/1.3 with Perfect Forward Secrecy

## SECURITY FEATURES
```
Nginx SSL Configuration:
- HSTS (HTTP Strict Transport Security)
- Perfect Forward Secrecy (PFS)
- OCSP Stapling for performance
- Strong cipher suite selection
- TLS 1.2+ enforcement
```

## RELATIONS  
- **Used by**: Nginx reverse proxy configuration
- **Protects**: All external communication channels
- **Integrated with**: Database SSL in `/database/ssl/`
- **Managed by**: Setup scripts in `/scripts/setup-ssl.sh`

## MAINTENANCE
- **Renewal**: Automated via scripts or manual process
- **Backup**: Encrypted backup of private keys
- **Monitoring**: Certificate expiration alerts
- **Rotation**: Annual key rotation for security

## PRODUCTION DEPLOYMENT
For production, replace self-signed certificates with:
- **Let's Encrypt**: Free automated certificates
- **Commercial CA**: Extended validation certificates
- **Cloudflare**: Managed SSL with CDN integration

**Critical for protecting $50 trading capital and user data in transit**