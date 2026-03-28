# nginx/ - Reverse Proxy & Load Balancing

## PURPOSE
Nginx configuration for reverse proxy, SSL termination, load balancing, and security hardening.

## CONFIGURATION
- `nginx-secure.conf` - Production-ready configuration with SSL, security headers, and rate limiting

## KEY FEATURES
### SSL/TLS Security
- **SSL Termination**: Handles HTTPS encryption/decryption
- **Certificate Management**: Auto-renewal and secure key storage
- **Security Headers**: HSTS, CSP, X-Frame-Options protection
- **Perfect Forward Secrecy**: DHE and ECDHE cipher suites

### Load Balancing
```nginx
upstream polyweather_backend {
    server backend:8080 weight=3;
    server backend:8080 backup;
}

upstream streamlit_dashboard {
    server streamlit:3000;
}
```

### Rate Limiting
- **Dashboard**: 60 requests/minute per IP
- **API Endpoints**: 100 requests/minute per IP  
- **Authentication**: 10 requests/minute per IP
- **Burst Handling**: 20 request burst tolerance

## PROXY CONFIGURATION
```
Client → Nginx (443/80) → Backend Services
├── /api/* → Backend API (8080)
├── /dashboard/* → Streamlit (3000)  
└── /ws/* → WebSocket (8765)
```

## RELATIONS
- **Frontend for**: Backend API and Streamlit dashboard
- **Integrates with**: SSL certificates in `/ssl/` directory
- **Protected by**: Fail2ban rules for intrusion prevention
- **Monitored by**: Prometheus for performance metrics

## SECURITY HARDENING
- **Hide Server Version**: Remove Nginx version disclosure
- **Request Size Limits**: 1MB max for API calls
- **Timeout Configuration**: 30s proxy timeout
- **Log Sanitization**: Remove sensitive data from access logs

**Production-ready reverse proxy ensuring secure and performant access**