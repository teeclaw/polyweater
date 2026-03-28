#!/bin/bash

# PolyWeather SSH Tunnel Client Script
# Run this script on your local machine to create secure tunnels

# Configuration
SERVER_IP="104.154.72.5"
SERVER_USER="phan_harry"
SSH_PORT="22"

# Local ports for forwarding
DASHBOARD_LOCAL_PORT="13000"
API_LOCAL_PORT="18080"
WS_LOCAL_PORT="18765"
MONITORING_LOCAL_PORT="19090"

echo "🔐 Creating SSH tunnels to PolyWeather dashboard..."
echo "Server: $SERVER_USER@$SERVER_IP:$SSH_PORT"
echo ""
echo "Local endpoints after tunnel is established:"
echo "  🌐 Dashboard:  https://localhost:$DASHBOARD_LOCAL_PORT"
echo "  🔗 API:        https://localhost:$API_LOCAL_PORT"
echo "  📊 Monitoring: http://localhost:$MONITORING_LOCAL_PORT"
echo ""
echo "Press Ctrl+C to close tunnels"
echo ""

# Create SSH tunnel with port forwarding
ssh -L $DASHBOARD_LOCAL_PORT:localhost:443 \
    -L $API_LOCAL_PORT:localhost:8080 \
    -L $WS_LOCAL_PORT:localhost:8765 \
    -L $MONITORING_LOCAL_PORT:localhost:9090 \
    -N -v $SERVER_USER@$SERVER_IP

echo "SSH tunnels closed."
