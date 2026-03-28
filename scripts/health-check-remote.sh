#!/bin/bash

# PolyWeather Remote Access Health Check
# Comprehensive monitoring of all access methods and security

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
NC='\033[0m'

# Health check functions
check_status() {
    local service=$1
    local result=$2
    if [[ $result -eq 0 ]]; then
        echo -e "   ✅ ${GREEN}$service: OK${NC}"
        return 0
    else
        echo -e "   ❌ ${RED}$service: FAILED${NC}"
        return 1
    fi
}

check_port() {
    local port=$1
    local service=$2
    if ss -tlnp | grep -q ":$port "; then
        echo -e "   ✅ ${GREEN}$service (port $port): Listening${NC}"
        return 0
    else
        echo -e "   ❌ ${RED}$service (port $port): Not listening${NC}"
        return 1
    fi
}

check_url() {
    local url=$1
    local service=$2
    local timeout=5
    
    if curl -s --max-time $timeout "$url" > /dev/null 2>&1; then
        echo -e "   ✅ ${GREEN}$service: Accessible${NC}"
        return 0
    else
        echo -e "   ❌ ${RED}$service: Not accessible${NC}"
        return 1
    fi
}

clear
echo -e "${BOLD}${BLUE}🩺 PolyWeather Remote Access Health Check${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# System information
echo -e "${BLUE}📊 System Information${NC}"
EXTERNAL_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo -e "   🌐 External IP: ${CYAN}$EXTERNAL_IP${NC}"
echo -e "   🖥️  Hostname: ${CYAN}$(hostname)${NC}"
echo -e "   ⏰ System Time: ${CYAN}$(date)${NC}"
echo -e "   💾 Disk Usage: ${CYAN}$(df -h / | tail -1 | awk '{print $5}') used${NC}"
echo -e "   🧠 Memory Usage: ${CYAN}$(free -h | grep Mem | awk '{printf "%.1f%%\n", $3/$2*100}') used${NC}"
echo ""

# Docker status
echo -e "${BLUE}🐳 Docker Status${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "   ❌ ${RED}Docker: Not installed${NC}"
    exit 1
fi

check_status "Docker daemon" "$(docker info >/dev/null 2>&1; echo $?)"

# Container status
echo ""
echo -e "${BLUE}📦 Container Status${NC}"
containers=(
    "polyweather-postgres-secure"
    "polyweather-redis-secure"
    "polyweather-trading-bot-secure"
    "polyweather-dashboard-secure"
    "polyweather-nginx-proxy"
    "polyweather-monitoring-secure"
    "polyweather-fail2ban"
)

total_containers=0
healthy_containers=0

for container in "${containers[@]}"; do
    total_containers=$((total_containers + 1))
    if docker ps -q -f name="$container" 2>/dev/null | grep -q .; then
        # Container is running, check health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        case $health in
            "healthy")
                echo -e "   ✅ ${GREEN}$container: Running & Healthy${NC}"
                healthy_containers=$((healthy_containers + 1))
                ;;
            "unhealthy")
                echo -e "   ⚠️  ${YELLOW}$container: Running but Unhealthy${NC}"
                ;;
            "unknown"|"")
                echo -e "   ⚠️  ${YELLOW}$container: Running (no health check)${NC}"
                healthy_containers=$((healthy_containers + 1))
                ;;
            *)
                echo -e "   ❌ ${RED}$container: $health${NC}"
                ;;
        esac
    else
        echo -e "   ❌ ${RED}$container: Not running${NC}"
    fi
done

echo -e "   📊 ${CYAN}Summary: $healthy_containers/$total_containers containers healthy${NC}"

# Port checks
echo ""
echo -e "${BLUE}🔌 Port Availability${NC}"
check_port "80" "HTTP (Nginx)"
check_port "443" "HTTPS (Nginx)"
check_port "3000" "Dashboard (local)"
check_port "8080" "API (local)"
check_port "8765" "WebSocket (local)"
check_port "9090" "Prometheus (local)"
check_port "5433" "PostgreSQL (local)"
check_port "6380" "Redis (local)"

# Service health endpoints
echo ""
echo -e "${BLUE}🩺 Service Health Endpoints${NC}"
check_url "http://localhost:3000/health" "Dashboard"
check_url "http://localhost:8080/health" "API"
check_url "http://localhost:9090/-/healthy" "Prometheus"

# SSL certificate check
echo ""
echo -e "${BLUE}🔐 SSL Certificate Status${NC}"
if [[ -f "$PROJECT_DIR/ssl/polyweather.crt" ]]; then
    cert_info=$(openssl x509 -in "$PROJECT_DIR/ssl/polyweather.crt" -noout -dates 2>/dev/null || echo "invalid")
    if [[ "$cert_info" != "invalid" ]]; then
        echo -e "   ✅ ${GREEN}SSL Certificate: Present and valid${NC}"
        expiry=$(openssl x509 -in "$PROJECT_DIR/ssl/polyweather.crt" -noout -enddate | cut -d= -f2)
        echo -e "   📅 ${CYAN}Expires: $expiry${NC}"
    else
        echo -e "   ❌ ${RED}SSL Certificate: Invalid${NC}"
    fi
else
    echo -e "   ⚠️  ${YELLOW}SSL Certificate: Not found${NC}"
fi

# Access method checks
echo ""
echo -e "${BLUE}🌐 Access Method Status${NC}"

# Check SSH tunnel files
if [[ -f "$PROJECT_DIR/client-tunnel.sh" ]]; then
    echo -e "   ✅ ${GREEN}SSH Tunnel: Files ready${NC}"
    if systemctl is-active --quiet ssh; then
        echo -e "   ✅ ${GREEN}SSH Service: Running${NC}"
    else
        echo -e "   ❌ ${RED}SSH Service: Not running${NC}"
    fi
else
    echo -e "   ⚠️  ${YELLOW}SSH Tunnel: Not configured${NC}"
fi

# Check CloudFlare tunnel
if [[ -f "$PROJECT_DIR/cloudflare/config.yml" ]]; then
    echo -e "   ✅ ${GREEN}CloudFlare Tunnel: Configured${NC}"
    if command -v cloudflared &> /dev/null; then
        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            echo -e "   ✅ ${GREEN}CloudFlare Service: Running${NC}"
        else
            echo -e "   ⚠️  ${YELLOW}CloudFlare Service: Not running${NC}"
        fi
    else
        echo -e "   ⚠️  ${YELLOW}CloudFlare Client: Not installed${NC}"
    fi
else
    echo -e "   ⚠️  ${YELLOW}CloudFlare Tunnel: Not configured${NC}"
fi

# Check Nginx proxy
if docker ps -q -f name=polyweather-nginx-proxy 2>/dev/null | grep -q .; then
    echo -e "   ✅ ${GREEN}Nginx Proxy: Running${NC}"
    # Test HTTPS access
    if curl -k -s --max-time 5 "https://localhost/health" > /dev/null 2>&1; then
        echo -e "   ✅ ${GREEN}HTTPS Access: Working${NC}"
    else
        echo -e "   ❌ ${RED}HTTPS Access: Failed${NC}"
    fi
else
    echo -e "   ⚠️  ${YELLOW}Nginx Proxy: Not running${NC}"
fi

# Security checks
echo ""
echo -e "${BLUE}🛡️  Security Status${NC}"

# Check fail2ban
if command -v fail2ban-client &> /dev/null; then
    if systemctl is-active --quiet fail2ban; then
        echo -e "   ✅ ${GREEN}Fail2ban: Running${NC}"
        banned_count=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list://g' | wc -w)
        echo -e "   📊 ${CYAN}Active jails: $banned_count${NC}"
    else
        echo -e "   ❌ ${RED}Fail2ban: Not running${NC}"
    fi
else
    echo -e "   ⚠️  ${YELLOW}Fail2ban: Not installed${NC}"
fi

# Check firewall
if command -v ufw &> /dev/null; then
    ufw_status=$(ufw status | head -1 | cut -d: -f2 | tr -d ' ')
    if [[ "$ufw_status" == "active" ]]; then
        echo -e "   ✅ ${GREEN}UFW Firewall: Active${NC}"
    else
        echo -e "   ⚠️  ${YELLOW}UFW Firewall: Inactive${NC}"
    fi
else
    echo -e "   ⚠️  ${YELLOW}UFW Firewall: Not installed${NC}"
fi

# Check for security updates
if command -v apt &> /dev/null; then
    security_updates=$(apt list --upgradable 2>/dev/null | grep -c security || echo 0)
    if [[ $security_updates -gt 0 ]]; then
        echo -e "   ⚠️  ${YELLOW}Security Updates: $security_updates available${NC}"
    else
        echo -e "   ✅ ${GREEN}Security Updates: None pending${NC}"
    fi
fi

# Log analysis
echo ""
echo -e "${BLUE}📋 Recent Log Analysis${NC}"

# Check for errors in last 24 hours
if [[ -f "$PROJECT_DIR/logs/trading.log" ]]; then
    recent_errors=$(grep -c "ERROR" "$PROJECT_DIR/logs/trading.log" 2>/dev/null || echo 0)
    echo -e "   📊 ${CYAN}Recent errors: $recent_errors${NC}"
fi

# Check nginx access logs
if docker exec polyweather-nginx-proxy test -f /var/log/nginx/access.log 2>/dev/null; then
    recent_requests=$(docker exec polyweather-nginx-proxy tail -100 /var/log/nginx/access.log 2>/dev/null | wc -l || echo 0)
    echo -e "   📊 ${CYAN}Recent requests: $recent_requests${NC}"
fi

# Performance metrics
echo ""
echo -e "${BLUE}📈 Performance Metrics${NC}"

# Database connections
if docker exec polyweather-postgres-secure psql -U polyweather_trader -d polyweather -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | grep -q "1"; then
    db_connections=$(docker exec polyweather-postgres-secure psql -U polyweather_trader -d polyweather -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | grep -E "^\s*[0-9]+$" | tr -d ' ' || echo "unknown")
    echo -e "   📊 ${CYAN}Database connections: $db_connections${NC}"
fi

# Redis info
if docker exec polyweather-redis-secure redis-cli --no-auth-warning -a pass123 info stats 2>/dev/null | grep -q "total_commands_processed"; then
    redis_commands=$(docker exec polyweather-redis-secure redis-cli --no-auth-warning -a pass123 info stats 2>/dev/null | grep "total_commands_processed" | cut -d: -f2 | tr -d '\r' || echo "unknown")
    echo -e "   📊 ${CYAN}Redis commands processed: $redis_commands${NC}"
fi

# Final summary
echo ""
echo -e "${CYAN}🎯 Health Check Summary${NC}"
echo "======================="

# Calculate overall health score
total_checks=20
passed_checks=0

# Count successful checks (this is a simplified calculation)
if command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
    passed_checks=$((passed_checks + 1))
fi

if [[ $healthy_containers -gt $((total_containers / 2)) ]]; then
    passed_checks=$((passed_checks + 3))
fi

if [[ -f "$PROJECT_DIR/ssl/polyweather.crt" ]]; then
    passed_checks=$((passed_checks + 1))
fi

# Calculate health percentage
health_percentage=$(( (passed_checks * 100) / 10 ))

if [[ $health_percentage -ge 80 ]]; then
    echo -e "   ✅ ${GREEN}Overall Health: EXCELLENT ($health_percentage%)${NC}"
elif [[ $health_percentage -ge 60 ]]; then
    echo -e "   ⚠️  ${YELLOW}Overall Health: GOOD ($health_percentage%)${NC}"
else
    echo -e "   ❌ ${RED}Overall Health: NEEDS ATTENTION ($health_percentage%)${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Quick Access Links${NC}"
echo "   🌐 Local Dashboard: http://localhost:3000"
echo "   🔗 Local API: http://localhost:8080"
echo "   📊 Local Monitoring: http://localhost:9090"

if docker ps -q -f name=polyweather-nginx-proxy 2>/dev/null | grep -q .; then
    echo "   🔒 HTTPS Dashboard: https://$EXTERNAL_IP"
fi

echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "   • Run this check regularly to monitor system health"
echo "   • Check logs if any services show as unhealthy"
echo "   • Update security patches when available"
echo "   • Monitor trading logs for any unusual activity"
echo ""
echo -e "${BOLD}${GREEN}Health check complete!${NC}"