#!/bin/bash

# PolyWeather SSH Tunnel Setup for Secure Remote Access
# Creates SSH tunnels for secure dashboard access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 PolyWeather SSH Tunnel Setup${NC}"
echo "Setting up secure SSH access to trading dashboard..."
echo ""

# Check if SSH is running
if ! systemctl is-active --quiet ssh; then
    echo -e "${YELLOW}⚠️  SSH service is not running. Starting SSH...${NC}"
    sudo systemctl start ssh
    sudo systemctl enable ssh
fi

# Get current user and home directory
CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
SSH_DIR="$HOME_DIR/.ssh"

# Create SSH directory if it doesn't exist
if [[ ! -d "$SSH_DIR" ]]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    echo -e "${GREEN}✅ Created SSH directory: $SSH_DIR${NC}"
fi

# Get server IP
EXTERNAL_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo -e "${BLUE}📡 Server IP: $EXTERNAL_IP${NC}"

# Create SSH tunnel script for clients
cat > "$PROJECT_DIR/client-tunnel.sh" << EOF
#!/bin/bash

# PolyWeather SSH Tunnel Client Script
# Run this script on your local machine to create secure tunnels

# Configuration
SERVER_IP="$EXTERNAL_IP"
SERVER_USER="$CURRENT_USER"
SSH_PORT="22"

# Local ports for forwarding
DASHBOARD_LOCAL_PORT="13000"
API_LOCAL_PORT="18080"
WS_LOCAL_PORT="18765"
MONITORING_LOCAL_PORT="19090"

echo "🔐 Creating SSH tunnels to PolyWeather dashboard..."
echo "Server: \$SERVER_USER@\$SERVER_IP:\$SSH_PORT"
echo ""
echo "Local endpoints after tunnel is established:"
echo "  🌐 Dashboard:  https://localhost:\$DASHBOARD_LOCAL_PORT"
echo "  🔗 API:        https://localhost:\$API_LOCAL_PORT"
echo "  📊 Monitoring: http://localhost:\$MONITORING_LOCAL_PORT"
echo ""
echo "Press Ctrl+C to close tunnels"
echo ""

# Create SSH tunnel with port forwarding
ssh -L \$DASHBOARD_LOCAL_PORT:localhost:443 \\
    -L \$API_LOCAL_PORT:localhost:8080 \\
    -L \$WS_LOCAL_PORT:localhost:8765 \\
    -L \$MONITORING_LOCAL_PORT:localhost:9090 \\
    -N -v \$SERVER_USER@\$SERVER_IP

echo "SSH tunnels closed."
EOF

chmod +x "$PROJECT_DIR/client-tunnel.sh"

# Create Windows batch file for Windows users
cat > "$PROJECT_DIR/client-tunnel.bat" << 'EOF'
@echo off
REM PolyWeather SSH Tunnel for Windows
REM Requires OpenSSH client or PuTTY

set SERVER_IP=REPLACE_WITH_SERVER_IP
set SERVER_USER=REPLACE_WITH_USERNAME
set DASHBOARD_PORT=13000
set API_PORT=18080
set MONITORING_PORT=19090

echo Creating SSH tunnels to PolyWeather dashboard...
echo Server: %SERVER_USER%@%SERVER_IP%
echo.
echo Local endpoints:
echo   Dashboard:  https://localhost:%DASHBOARD_PORT%
echo   API:        https://localhost:%API_PORT%
echo   Monitoring: http://localhost:%MONITORING_PORT%
echo.
echo Press Ctrl+C to close tunnels

ssh -L %DASHBOARD_PORT%:localhost:443 -L %API_PORT%:localhost:8080 -L %MONITORING_PORT%:localhost:9090 -N %SERVER_USER%@%SERVER_IP%
EOF

# Replace placeholders in Windows batch file
sed -i "s/REPLACE_WITH_SERVER_IP/$EXTERNAL_IP/g" "$PROJECT_DIR/client-tunnel.bat"
sed -i "s/REPLACE_WITH_USERNAME/$CURRENT_USER/g" "$PROJECT_DIR/client-tunnel.bat"

# Create authorized_keys setup
echo ""
echo -e "${YELLOW}🔑 SSH Key Setup${NC}"
echo "For passwordless SSH access, add your public key to authorized_keys:"
echo ""
echo "1. On your local machine, generate SSH key if you don't have one:"
echo "   ssh-keygen -t rsa -b 4096 -C \"polyweather-access\""
echo ""
echo "2. Copy your public key to this server:"
echo "   ssh-copy-id $CURRENT_USER@$EXTERNAL_IP"
echo ""
echo "3. Or manually add your public key:"
echo "   echo 'your-public-key-here' >> $SSH_DIR/authorized_keys"
echo ""

# Set up SSH security configuration
SSHD_CONFIG="/etc/ssh/sshd_config"
echo -e "${YELLOW}🛡️  SSH Security Configuration${NC}"

# Backup original sshd_config
if [[ ! -f "${SSHD_CONFIG}.backup" ]]; then
    sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup"
    echo -e "${GREEN}✅ Backed up SSH configuration${NC}"
fi

# Create secure SSH configuration
cat > "$PROJECT_DIR/sshd_secure.conf" << EOF
# PolyWeather Secure SSH Configuration

# Security settings
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Connection settings
Port 22
Protocol 2
MaxAuthTries 3
MaxStartups 10:30:100
LoginGraceTime 120

# Logging
LogLevel INFO
SyslogFacility AUTH

# Allow specific users only
AllowUsers $CURRENT_USER

# Disable dangerous features
X11Forwarding no
AllowTcpForwarding yes
GatewayPorts no
PermitTunnel no

# Client timeout
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

echo ""
echo -e "${GREEN}📋 Setup Complete!${NC}"
echo ""
echo -e "${BLUE}Client Files Created:${NC}"
echo "  📁 $PROJECT_DIR/client-tunnel.sh (Linux/Mac)"
echo "  📁 $PROJECT_DIR/client-tunnel.bat (Windows)"
echo ""
echo -e "${BLUE}Usage Instructions:${NC}"
echo ""
echo -e "${YELLOW}For Linux/Mac users:${NC}"
echo "  1. Copy client-tunnel.sh to your local machine"
echo "  2. Make it executable: chmod +x client-tunnel.sh" 
echo "  3. Run: ./client-tunnel.sh"
echo "  4. Access dashboard at: https://localhost:13000"
echo ""
echo -e "${YELLOW}For Windows users:${NC}"
echo "  1. Install OpenSSH client or PuTTY"
echo "  2. Copy client-tunnel.bat to your local machine"
echo "  3. Run: client-tunnel.bat"
echo "  4. Access dashboard at: https://localhost:13000"
echo ""
echo -e "${YELLOW}Security Notes:${NC}"
echo "  ✅ All traffic encrypted via SSH tunnel"
echo "  ✅ No direct internet exposure of dashboard"
echo "  ✅ Authentication required at multiple layers"
echo "  ⚠️  Set up SSH keys for passwordless access"
echo ""
echo -e "${RED}⚡ To apply SSH security config, run:${NC}"
echo "  sudo cp $PROJECT_DIR/sshd_secure.conf /etc/ssh/sshd_config"
echo "  sudo systemctl restart ssh"