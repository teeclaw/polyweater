#!/bin/bash

# PolyWeather CloudFlare Tunnel Setup
# Secure public access without exposing ports directly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}☁️  PolyWeather CloudFlare Tunnel Setup${NC}"
echo "Setting up secure public access via CloudFlare Zero Trust..."
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo -e "${YELLOW}📦 Installing CloudFlare Tunnel (cloudflared)...${NC}"
    
    # Detect OS and install accordingly
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bullseye main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
        sudo apt-get update
        sudo apt-get install -y cloudflared
    elif [[ -f /etc/redhat-release ]]; then
        # RHEL/CentOS/Fedora
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
        echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bullseye main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
        sudo yum install -y cloudflared
    else
        echo -e "${RED}❌ Unsupported OS for automatic installation${NC}"
        echo "Please install cloudflared manually from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation"
        exit 1
    fi
    
    echo -e "${GREEN}✅ CloudFlare Tunnel installed${NC}"
fi

# Create cloudflare directory
CLOUDFLARE_DIR="$PROJECT_DIR/cloudflare"
mkdir -p "$CLOUDFLARE_DIR"

# Create tunnel configuration
cat > "$CLOUDFLARE_DIR/config.yml" << EOF
# PolyWeather CloudFlare Tunnel Configuration

# Tunnel UUID will be set after login
tunnel: polyweather-trading-bot

# Credentials file (will be created after login)
credentials-file: $CLOUDFLARE_DIR/polyweather-trading-bot.json

# Ingress rules - map external URLs to internal services
ingress:
  # Main dashboard
  - hostname: polyweather.your-domain.com
    service: https://localhost:443
    originRequest:
      noTLSVerify: true
      httpHostHeader: localhost
  
  # API endpoint with path prefix
  - hostname: api.polyweather.your-domain.com
    service: https://localhost:8080
    originRequest:
      noTLSVerify: true
      httpHostHeader: localhost
  
  # WebSocket endpoint
  - hostname: ws.polyweather.your-domain.com
    service: https://localhost:8765
    originRequest:
      noTLSVerify: true
      httpHostHeader: localhost
  
  # Monitoring dashboard (restricted)
  - hostname: monitor.polyweather.your-domain.com
    service: http://localhost:9090
    originRequest:
      httpHostHeader: localhost
  
  # Catch-all rule (required)
  - service: http_status:404

# Logging
logLevel: info
logFile: $CLOUDFLARE_DIR/tunnel.log

# Metrics
metrics: localhost:8081
EOF

# Create systemd service for automatic startup
cat > "$CLOUDFLARE_DIR/cloudflared.service" << EOF
[Unit]
Description=CloudFlare Tunnel for PolyWeather
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config $CLOUDFLARE_DIR/config.yml run
Restart=on-failure
RestartSec=10
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Create setup script
cat > "$CLOUDFLARE_DIR/setup-tunnel.sh" << 'EOF'
#!/bin/bash

# CloudFlare Tunnel Authentication and Setup
# Run this script to complete the CloudFlare Tunnel setup

set -euo pipefail

CLOUDFLARE_DIR="$(dirname "$0")"
PROJECT_DIR="$(dirname "$CLOUDFLARE_DIR")"

echo "🔐 CloudFlare Tunnel Authentication Setup"
echo ""

# Step 1: Login to CloudFlare
echo "Step 1: Authenticate with CloudFlare"
echo "This will open a browser window for you to log in to CloudFlare..."
read -p "Press Enter to continue..."

cloudflared tunnel login

# Step 2: Create tunnel
echo ""
echo "Step 2: Creating tunnel 'polyweather-trading-bot'..."
cloudflared tunnel create polyweather-trading-bot

# Step 3: Get tunnel info and update config
TUNNEL_UUID=$(cloudflared tunnel list | grep polyweather-trading-bot | awk '{print $1}')
echo "Tunnel UUID: $TUNNEL_UUID"

# Update config with actual tunnel UUID
sed -i "s/tunnel: polyweather-trading-bot/tunnel: $TUNNEL_UUID/g" "$CLOUDFLARE_DIR/config.yml"

# Update credentials file path
CREDENTIALS_FILE="$HOME/.cloudflared/$TUNNEL_UUID.json"
sed -i "s|credentials-file: .*|credentials-file: $CREDENTIALS_FILE|g" "$CLOUDFLARE_DIR/config.yml"

echo ""
echo "Step 3: DNS Configuration"
echo "You need to add the following DNS records to your domain:"
echo ""
echo "Type: CNAME, Name: polyweather, Content: $TUNNEL_UUID.cfargotunnel.com"
echo "Type: CNAME, Name: api.polyweather, Content: $TUNNEL_UUID.cfargotunnel.com"
echo "Type: CNAME, Name: ws.polyweather, Content: $TUNNEL_UUID.cfargotunnel.com"
echo "Type: CNAME, Name: monitor.polyweather, Content: $TUNNEL_UUID.cfargotunnel.com"
echo ""
echo "Or run these commands (replace YOUR-DOMAIN with your actual domain):"
echo ""
echo "cloudflared tunnel route dns polyweather-trading-bot polyweather.YOUR-DOMAIN"
echo "cloudflared tunnel route dns polyweather-trading-bot api.polyweather.YOUR-DOMAIN"
echo "cloudflared tunnel route dns polyweather-trading-bot ws.polyweather.YOUR-DOMAIN"
echo "cloudflared tunnel route dns polyweather-trading-bot monitor.polyweather.YOUR-DOMAIN"
echo ""

read -p "Enter your domain name: " DOMAIN_NAME

if [[ -n "$DOMAIN_NAME" ]]; then
    echo "Creating DNS records for $DOMAIN_NAME..."
    cloudflared tunnel route dns polyweather-trading-bot polyweather.$DOMAIN_NAME || true
    cloudflared tunnel route dns polyweather-trading-bot api.polyweather.$DOMAIN_NAME || true
    cloudflared tunnel route dns polyweather-trading-bot ws.polyweather.$DOMAIN_NAME || true
    cloudflared tunnel route dns polyweather-trading-bot monitor.polyweather.$DOMAIN_NAME || true
    
    # Update config with actual domain
    sed -i "s/your-domain.com/$DOMAIN_NAME/g" "$CLOUDFLARE_DIR/config.yml"
fi

echo ""
echo "Step 4: Install systemd service"
sudo cp "$CLOUDFLARE_DIR/cloudflared.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo ""
echo "✅ CloudFlare Tunnel setup complete!"
echo ""
echo "Your PolyWeather dashboard is now accessible at:"
echo "  🌐 Dashboard: https://polyweather.$DOMAIN_NAME"
echo "  🔗 API: https://api.polyweather.$DOMAIN_NAME"
echo "  📊 WebSocket: wss://ws.polyweather.$DOMAIN_NAME"
echo "  📈 Monitoring: https://monitor.polyweather.$DOMAIN_NAME"
echo ""
echo "Security features:"
echo "  ✅ No inbound ports opened on your server"
echo "  ✅ CloudFlare DDoS protection"
echo "  ✅ CloudFlare SSL/TLS encryption"
echo "  ✅ Access policies can be applied via CloudFlare Zero Trust"
echo ""
echo "To check tunnel status: sudo systemctl status cloudflared"
echo "To view logs: journalctl -u cloudflared -f"
EOF

chmod +x "$CLOUDFLARE_DIR/setup-tunnel.sh"

# Create monitoring script
cat > "$CLOUDFLARE_DIR/monitor-tunnel.sh" << 'EOF'
#!/bin/bash

# CloudFlare Tunnel Monitoring Script

CLOUDFLARE_DIR="$(dirname "$0")"

echo "📊 CloudFlare Tunnel Status for PolyWeather"
echo "==========================================="
echo ""

# Service status
echo "🔧 Service Status:"
systemctl status cloudflared --no-pager -l

echo ""
echo "📋 Tunnel List:"
cloudflared tunnel list

echo ""
echo "🌐 Tunnel Info:"
cloudflared tunnel info polyweather-trading-bot

echo ""
echo "📊 Recent Logs:"
journalctl -u cloudflared --no-pager -n 20

echo ""
echo "📈 Metrics (if enabled):"
curl -s http://localhost:8081/metrics | head -20 || echo "Metrics not available"
EOF

chmod +x "$CLOUDFLARE_DIR/monitor-tunnel.sh"

# Create teardown script
cat > "$CLOUDFLARE_DIR/teardown-tunnel.sh" << 'EOF'
#!/bin/bash

# CloudFlare Tunnel Teardown Script

echo "🗑️  Tearing down CloudFlare Tunnel..."

# Stop service
sudo systemctl stop cloudflared
sudo systemctl disable cloudflared

# Remove service file
sudo rm -f /etc/systemd/system/cloudflared.service
sudo systemctl daemon-reload

# Delete tunnel
cloudflared tunnel delete polyweather-trading-bot

echo "✅ CloudFlare Tunnel removed"
EOF

chmod +x "$CLOUDFLARE_DIR/teardown-tunnel.sh"

echo -e "${GREEN}📋 CloudFlare Tunnel Setup Complete!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Run the setup script to authenticate and configure:"
echo "   cd $CLOUDFLARE_DIR && ./setup-tunnel.sh"
echo ""
echo "2. Update your domain DNS settings as instructed"
echo ""
echo "3. Configure CloudFlare Zero Trust for additional security:"
echo "   - Go to CloudFlare Zero Trust dashboard"
echo "   - Set up Access policies for your tunnels"
echo "   - Configure authentication (Google, GitHub, etc.)"
echo ""
echo -e "${BLUE}Available Scripts:${NC}"
echo "  📁 $CLOUDFLARE_DIR/setup-tunnel.sh - Complete tunnel setup"
echo "  📁 $CLOUDFLARE_DIR/monitor-tunnel.sh - Monitor tunnel status"
echo "  📁 $CLOUDFLARE_DIR/teardown-tunnel.sh - Remove tunnel"
echo ""
echo -e "${YELLOW}Benefits of CloudFlare Tunnel:${NC}"
echo "  ✅ No firewall ports to open"
echo "  ✅ DDoS protection included"
echo "  ✅ Free SSL certificates"
echo "  ✅ Global CDN acceleration"
echo "  ✅ Access control via Zero Trust"