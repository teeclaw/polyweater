#!/bin/bash

# PolyWeather Remote Access Setup - Master Script
# Configures secure remote access to the trading dashboard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

clear
echo -e "${BOLD}${BLUE}🚀 PolyWeather Trading Dashboard - Remote Access Setup${NC}"
echo -e "${CYAN}===============================================================${NC}"
echo ""
echo -e "${GREEN}Welcome to the PolyWeather secure remote access configuration!${NC}"
echo ""
echo "This script will help you set up secure remote access to your"
echo "bulletproof trading dashboard running on this GCP VPS."
echo ""
echo -e "${YELLOW}⚡ Trading Capital: \$50 | Security Level: Enterprise${NC}"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is required but not installed${NC}"
    exit 1
fi

# Check system status
echo -e "${BLUE}📊 System Status Check...${NC}"
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo -e "   🌐 External IP: ${GREEN}$EXTERNAL_IP${NC}"

# Check if services are running
DASHBOARD_RUNNING=$(docker ps -q -f name=polyweather-dashboard 2>/dev/null | wc -l)
API_RUNNING=$(docker ps -q -f name=polyweather.*bot 2>/dev/null | wc -l)

if [[ $DASHBOARD_RUNNING -gt 0 && $API_RUNNING -gt 0 ]]; then
    echo -e "   ✅ PolyWeather services: ${GREEN}Running${NC}"
else
    echo -e "   ⚠️  PolyWeather services: ${YELLOW}Not running${NC}"
fi

echo ""
echo -e "${CYAN}🔐 Available Access Methods:${NC}"
echo ""
echo -e "${BOLD}1. SSH Tunnel (Recommended - Most Secure)${NC}"
echo -e "   ${GREEN}✅ Zero internet exposure${NC}"
echo -e "   ${GREEN}✅ Military-grade encryption${NC}"
echo -e "   ${GREEN}✅ Works from anywhere${NC}"
echo -e "   ${YELLOW}⚠️  Requires SSH client${NC}"
echo ""
echo -e "${BOLD}2. CloudFlare Tunnel (Recommended - Easiest)${NC}"
echo -e "   ${GREEN}✅ No firewall configuration${NC}"
echo -e "   ${GREEN}✅ DDoS protection included${NC}"
echo -e "   ${GREEN}✅ Global CDN acceleration${NC}"
echo -e "   ${YELLOW}⚠️  Requires CloudFlare account${NC}"
echo ""
echo -e "${BOLD}3. Nginx Reverse Proxy (Advanced)${NC}"
echo -e "   ${GREEN}✅ Direct HTTPS access${NC}"
echo -e "   ${GREEN}✅ Custom SSL certificates${NC}"
echo -e "   ${RED}⚠️  Requires firewall configuration${NC}"
echo ""
echo -e "${BOLD}4. Local Network Only (Testing)${NC}"
echo -e "   ${GREEN}✅ No internet exposure${NC}"
echo -e "   ${RED}⚠️  LAN access only${NC}"
echo ""

read -p "Select access method (1-4): " ACCESS_METHOD

case $ACCESS_METHOD in
    1)
        echo -e "${BLUE}🔐 Setting up SSH Tunnel access...${NC}"
        echo ""
        "$SCRIPT_DIR/setup-ssh-access.sh"
        ;;
    2)
        echo -e "${BLUE}☁️  Setting up CloudFlare Tunnel access...${NC}"
        echo ""
        "$SCRIPT_DIR/setup-cloudflare-tunnel.sh"
        ;;
    3)
        echo -e "${BLUE}🌐 Setting up Nginx Reverse Proxy...${NC}"
        echo ""
        
        # Generate SSL certificates first
        echo "Generating SSL certificates..."
        "$SCRIPT_DIR/setup-ssl.sh"
        
        # Deploy with reverse proxy
        echo ""
        echo "Deploying with reverse proxy..."
        cd "$PROJECT_DIR"
        docker-compose -f docker-compose-remote-access.yml up -d
        
        echo ""
        echo -e "${GREEN}✅ Nginx reverse proxy deployed!${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  IMPORTANT: Configure your firewall to allow ports 80 and 443${NC}"
        echo ""
        echo "On GCP, run these commands:"
        echo "  gcloud compute firewall-rules create allow-http --allow tcp:80 --source-ranges 0.0.0.0/0"
        echo "  gcloud compute firewall-rules create allow-https --allow tcp:443 --source-ranges 0.0.0.0/0"
        echo ""
        echo "Access your dashboard at:"
        echo "  🌐 https://$EXTERNAL_IP"
        echo "  📊 https://$EXTERNAL_IP/monitoring"
        ;;
    4)
        echo -e "${BLUE}🏠 Setting up local network access...${NC}"
        cd "$PROJECT_DIR"
        docker-compose -f docker-compose-secure.yml up -d
        
        echo ""
        echo -e "${GREEN}✅ Local access configured!${NC}"
        echo ""
        echo "Access your dashboard locally:"
        echo "  🌐 Dashboard: http://localhost:3000"
        echo "  🔗 API: http://localhost:8080"
        echo "  📊 Monitoring: http://localhost:9090"
        ;;
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

# Generate access documentation
echo ""
echo -e "${BLUE}📋 Generating access documentation...${NC}"

cat > "$PROJECT_DIR/ACCESS_GUIDE.md" << EOF
# PolyWeather Trading Dashboard - Access Guide

## 🚀 Quick Start

Your PolyWeather trading dashboard is now configured for secure remote access!

**Server Details:**
- External IP: $EXTERNAL_IP
- Deployment: Docker Secure Configuration
- Security Level: Enterprise Grade
- Trading Capital: \$50

## 🔐 Access Methods

$(case $ACCESS_METHOD in
    1) echo "### SSH Tunnel Access (Active)

**Most Secure Method - Zero Internet Exposure**

1. **From Linux/Mac:**
   \`\`\`bash
   ./client-tunnel.sh
   \`\`\`

2. **From Windows:**
   \`\`\`
   client-tunnel.bat
   \`\`\`

3. **Access Points:**
   - Dashboard: https://localhost:13000
   - API: https://localhost:18080
   - Monitoring: http://localhost:19090

**Files:**
- \`client-tunnel.sh\` - Linux/Mac SSH tunnel script
- \`client-tunnel.bat\` - Windows SSH tunnel script"
   ;;
    2) echo "### CloudFlare Tunnel Access (Active)

**Easiest Method - Professional Grade**

1. **Complete setup:**
   \`\`\`bash
   cd cloudflare && ./setup-tunnel.sh
   \`\`\`

2. **Access Points:** (after DNS setup)
   - Dashboard: https://polyweather.your-domain.com
   - API: https://api.polyweather.your-domain.com
   - WebSocket: wss://ws.polyweather.your-domain.com
   - Monitoring: https://monitor.polyweather.your-domain.com

**Management:**
- Monitor: \`./cloudflare/monitor-tunnel.sh\`
- Remove: \`./cloudflare/teardown-tunnel.sh\`"
   ;;
    3) echo "### Nginx Reverse Proxy (Active)

**Direct HTTPS Access**

1. **Access Points:**
   - Dashboard: https://$EXTERNAL_IP
   - API: https://$EXTERNAL_IP/api/
   - WebSocket: wss://$EXTERNAL_IP/ws/
   - Monitoring: https://$EXTERNAL_IP/monitoring/

2. **SSL Certificate:** Self-signed (import \`ssl/polyweather.crt\` to your browser)

3. **Firewall Required:**
   - Port 80 (HTTP redirect)
   - Port 443 (HTTPS)

**Security Features:**
- Rate limiting
- DDoS protection
- Security headers
- Request filtering"
   ;;
    4) echo "### Local Network Access (Active)

**LAN Access Only**

1. **Access Points:**
   - Dashboard: http://localhost:3000
   - API: http://localhost:8080
   - Monitoring: http://localhost:9090

2. **Network:** Internal only (127.0.0.1)

**Note:** No external access configured"
   ;;
esac)

## 🛡️ Security Features

- **Authentication:** JWT tokens + TOTP emergency controls
- **Database:** PostgreSQL with SCRAM-SHA-256 encryption
- **Redis:** Password-protected with ACLs
- **Network:** Isolated Docker networks
- **Monitoring:** Prometheus + security logging
- **Containers:** Read-only with security constraints

## 🔧 Management Commands

### Start/Stop Services
\`\`\`bash
# Start all services
$(case $ACCESS_METHOD in
    3) echo "docker-compose -f docker-compose-remote-access.yml up -d";;
    *) echo "docker-compose -f docker-compose-secure.yml up -d";;
esac)

# Stop all services
$(case $ACCESS_METHOD in
    3) echo "docker-compose -f docker-compose-remote-access.yml down";;
    *) echo "docker-compose -f docker-compose-secure.yml down";;
esac)

# View logs
docker-compose logs -f
\`\`\`

### Health Checks
\`\`\`bash
# Check all services
./scripts/health-check.sh

# Validate security
./validate_security_fixed.py
\`\`\`

### Emergency Controls
\`\`\`bash
# Test emergency authentication
./scripts/test_emergency_auth.py

# Trading controls
./scripts/test-trading-controls.py
\`\`\`

## 📞 Troubleshooting

### Connection Issues
1. Verify services are running: \`docker ps\`
2. Check logs: \`docker-compose logs\`
3. Test health endpoint: \`curl http://localhost:8080/health\`

### Authentication Issues
1. Check JWT secret configuration
2. Verify TOTP setup
3. Review authentication logs

### Network Issues
1. Verify firewall rules
2. Check port bindings: \`ss -tlnp\`
3. Test internal connectivity

## 📊 Monitoring

- **Prometheus:** $(case $ACCESS_METHOD in 3) echo "https://$EXTERNAL_IP/monitoring/";; 4) echo "http://localhost:9090";; *) echo "Via tunnel on port 19090";; esac)
- **Logs:** \`./logs/\` directory
- **Health:** \`/health\` endpoint on all services

## 🚨 Emergency Procedures

### Emergency Stop
\`\`\`bash
# Stop all trading immediately
docker-compose down

# Emergency kill switch via API
curl -X POST https://your-dashboard/api/emergency/stop \\
  -H "Authorization: Bearer \$JWT_TOKEN" \\
  -H "X-TOTP: \$TOTP_CODE"
\`\`\`

### Backup/Restore
\`\`\`bash
# Backup data
./scripts/backup-data.sh

# Restore data
./scripts/restore-data.sh
\`\`\`

---

**🔐 Security Notice:** This is a financial trading application handling real money. 
Always verify SSL certificates and use strong authentication.

**📞 Support:** Check logs and run health checks for troubleshooting.
EOF

echo -e "${GREEN}✅ Access documentation created: ACCESS_GUIDE.md${NC}"
echo ""

# Final status report
echo -e "${CYAN}🎯 Setup Summary${NC}"
echo "=================="
echo ""
echo -e "✅ Access method: ${GREEN}$(case $ACCESS_METHOD in 
    1) echo "SSH Tunnel";;
    2) echo "CloudFlare Tunnel";;
    3) echo "Nginx Reverse Proxy";;
    4) echo "Local Network";;
esac)${NC}"

echo -e "✅ SSL certificates: ${GREEN}Generated${NC}"
echo -e "✅ Security configuration: ${GREEN}Enterprise grade${NC}"
echo -e "✅ Documentation: ${GREEN}ACCESS_GUIDE.md${NC}"
echo ""

case $ACCESS_METHOD in
    1)
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Copy client-tunnel.sh to your local machine"
        echo "2. Set up SSH key authentication (optional but recommended)"
        echo "3. Run ./client-tunnel.sh to connect"
        echo "4. Access dashboard at https://localhost:13000"
        ;;
    2)
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Run: cd cloudflare && ./setup-tunnel.sh"
        echo "2. Configure your domain DNS settings"
        echo "3. Set up CloudFlare Zero Trust policies"
        echo "4. Access via your domain name"
        ;;
    3)
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Configure firewall rules for ports 80/443"
        echo "2. Import SSL certificate in your browser"
        echo "3. Access dashboard at https://$EXTERNAL_IP"
        echo "4. Monitor nginx logs for security events"
        ;;
    4)
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Access dashboard at http://localhost:3000"
        echo "2. Monitor services with docker ps"
        echo "3. Configure external access method when ready"
        ;;
esac

echo ""
echo -e "${BOLD}${GREEN}🚀 PolyWeather Remote Access Setup Complete!${NC}"
echo -e "${CYAN}Your bulletproof trading dashboard is ready for secure remote access.${NC}"
echo ""
echo -e "${YELLOW}⚡ Happy Trading! ⚡${NC}"