#!/bin/bash

# PolyWeather Bot Security Setup Script
# CRITICAL: Initialize all security components for production deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_DIR/secrets"
SSL_DIR="$PROJECT_DIR/database/ssl"
DATA_DIR="$PROJECT_DIR/data"

echo "🔐 PolyWeather Bot Security Setup"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root (should not be)
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root for security reasons"
   exit 1
fi

# Create secure directory structure
log_info "Creating secure directory structure..."
mkdir -p "$SECRETS_DIR"
mkdir -p "$SSL_DIR"
mkdir -p "$DATA_DIR"/{postgres,redis,prometheus}
mkdir -p "$PROJECT_DIR/logs"

# Set secure permissions
chmod 700 "$SECRETS_DIR"
chmod 755 "$SSL_DIR"
chmod 755 "$DATA_DIR"

# Generate secure random passwords
log_info "Generating secure credentials..."

# Generate PostgreSQL credentials
POSTGRES_USER="polyweather_trader_$(openssl rand -hex 4)"
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "$POSTGRES_USER" > "$SECRETS_DIR/postgres_user.txt"
echo "$POSTGRES_PASSWORD" > "$SECRETS_DIR/postgres_password.txt"

# Generate Redis password
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "$REDIS_PASSWORD" > "$SECRETS_DIR/redis_password.txt"

# Generate JWT secret
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
echo "$JWT_SECRET" > "$SECRETS_DIR/jwt_secret.txt"

# Create API keys file template
cat > "$SECRETS_DIR/api_keys.txt" << EOF
# PolyWeather API Keys - KEEP SECURE
POLYMARKET_API_KEY=your_polymarket_api_key_here
WEATHER_API_KEY=your_openweather_api_key_here
POLYCLAW_API_KEY=your_polyclaw_api_key_here
EOF

# Set secure permissions on secrets
chmod 600 "$SECRETS_DIR"/*.txt
chown $(whoami):$(whoami) "$SECRETS_DIR"/*.txt

log_info "Generated secure credentials in $SECRETS_DIR/"

# Generate SSL certificates for PostgreSQL
log_info "Generating SSL certificates for database encryption..."

# Create CA private key
openssl genpkey -algorithm RSA -out "$SSL_DIR/ca.key" -aes256 -pass pass:$(openssl rand -base64 32) 2>/dev/null

# Create CA certificate
openssl req -new -x509 -key "$SSL_DIR/ca.key" -out "$SSL_DIR/ca.crt" -days 3650 \
    -passin pass:$(cat "$SSL_DIR/ca.key" | head -1) \
    -subj "/C=US/ST=Trading/L=PolyWeather/O=TradingBot/OU=Database/CN=ca.polyweather.local" 2>/dev/null

# Create server private key
openssl genpkey -algorithm RSA -out "$SSL_DIR/server.key" 2>/dev/null

# Create server certificate signing request
openssl req -new -key "$SSL_DIR/server.key" -out "$SSL_DIR/server.csr" \
    -subj "/C=US/ST=Trading/L=PolyWeather/O=TradingBot/OU=Database/CN=postgres.polyweather.local" 2>/dev/null

# Sign server certificate
openssl x509 -req -in "$SSL_DIR/server.csr" -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
    -out "$SSL_DIR/server.crt" -days 365 \
    -passin pass:$(cat "$SSL_DIR/ca.key" | head -1) 2>/dev/null

# Create certificate revocation list
touch "$SSL_DIR/root.crl"

# Set appropriate permissions
chmod 600 "$SSL_DIR"/*.key
chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR"/*.csr "$SSL_DIR"/*.crl

log_info "SSL certificates generated in $SSL_DIR/"

# Create database users setup script
log_info "Creating database security setup script..."
cat > "$PROJECT_DIR/database/init/00_security_setup.sql" << EOF
-- PolyWeather Database Security Setup
-- CRITICAL: Run first to establish secure foundation

-- Enable security extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create secure database roles
DO \$\$
BEGIN
    -- Drop existing roles if they exist
    DROP ROLE IF EXISTS polyweather_readonly;
    DROP ROLE IF EXISTS polyweather_trader; 
    DROP ROLE IF EXISTS polyweather_admin;
    
    -- Create new roles with specific permissions
    CREATE ROLE polyweather_readonly LOGIN PASSWORD '$(cat "$SECRETS_DIR/postgres_password.txt")_readonly';
    CREATE ROLE polyweather_trader LOGIN PASSWORD '$(cat "$SECRETS_DIR/postgres_password.txt")';
    CREATE ROLE polyweather_admin LOGIN PASSWORD '$(cat "$SECRETS_DIR/postgres_password.txt")_admin';
    
    -- Set role attributes
    ALTER ROLE polyweather_readonly SET default_transaction_read_only = true;
    ALTER ROLE polyweather_trader SET default_transaction_isolation = 'read committed';
    ALTER ROLE polyweather_admin CREATEDB CREATEROLE;
    
    -- Connection limits for security
    ALTER ROLE polyweather_readonly CONNECTION LIMIT 5;
    ALTER ROLE polyweather_trader CONNECTION LIMIT 10;
    ALTER ROLE polyweather_admin CONNECTION LIMIT 3;
    
    RAISE NOTICE 'Database security roles created successfully';
END \$\$;

-- Enable row level security globally
ALTER DATABASE polyweather SET row_security = on;

-- Set secure default search path
ALTER DATABASE polyweather SET search_path = public;

-- Log security setup completion
DO \$\$
BEGIN
    RAISE NOTICE 'Database security setup completed at %', NOW();
END \$\$;
EOF

# Create Redis secure configuration
log_info "Creating Redis security configuration..."
cat > "$PROJECT_DIR/redis/config/redis-secure.conf" << EOF
# Redis Secure Configuration for PolyWeather Trading Bot

# Network Security
bind 127.0.0.1 ::1
protected-mode yes
port 6379
tcp-backlog 511

# Authentication
requirepass $(cat "$SECRETS_DIR/redis_password.txt")

# TLS Configuration (if needed)
# tls-port 6380
# tls-cert-file /etc/redis/tls/redis.crt
# tls-key-file /etc/redis/tls/redis.key
# tls-ca-cert-file /etc/redis/tls/ca.crt

# Memory Security
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence Security
save 900 1
save 300 10  
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename polyweather-trading.rdb
dir /data

# Logging for Security
loglevel notice
logfile /data/redis.log
syslog-enabled no

# Security Settings
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command EVAL ""
rename-command DEBUG ""
rename-command CONFIG "CONFIG_$(openssl rand -hex 8)"

# Client Security
timeout 300
tcp-keepalive 300
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

# Disable dangerous commands
rename-command SHUTDOWN SHUTDOWN_$(openssl rand -hex 8)
rename-command DEL DEL_$(openssl rand -hex 8)
EOF

# Create environment configuration
log_info "Creating secure environment configuration..."
cat > "$PROJECT_DIR/.env.secure" << EOF
# PolyWeather Bot Secure Environment Configuration
# CRITICAL: Copy to .env and customize for your deployment

# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=polyweather
DB_USER_FILE=/run/secrets/postgres_user
DB_PASSWORD_FILE=/run/secrets/postgres_password
DB_SSL_MODE=require

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD_FILE=/run/secrets/redis_password

# Security Configuration
JWT_SECRET_FILE=/run/secrets/jwt_secret
API_KEYS_FILE=/run/secrets/api_keys
ENCRYPTION_KEY_FILE=/run/secrets/encryption_key

# Trading Configuration
MAX_POSITION_SIZE=50.00
MAX_DAILY_TRADES=100
MAX_TOTAL_EXPOSURE=250.00
RISK_TOLERANCE=0.15

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=/app/logs/polyweather.log
AUDIT_LOG_FILE=/app/logs/audit.log

# Network Security
ALLOWED_ORIGINS=https://localhost:3000
CORS_ENABLED=true
RATE_LIMIT_ENABLED=true
RATE_LIMIT_MAX_REQUESTS=1000

# Monitoring
PROMETHEUS_ENABLED=true
HEALTH_CHECK_ENABLED=true
METRICS_PORT=9090

# Environment
ENVIRONMENT=production
DEBUG=false
DEVELOPMENT_MODE=false
EOF

# Create secure Docker Dockerfile
log_info "Creating secure Dockerfile..."
cat > "$PROJECT_DIR/Dockerfile.secure" << EOF
# Secure Multi-stage Dockerfile for PolyWeather Trading Bot
FROM python:3.11-slim-bullseye as builder

# Security: Create non-root user
RUN groupadd -r polyweather && useradd -r -g polyweather polyweather

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    gcc \\
    g++ \\
    libpq-dev \\
    curl \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir --user -r /tmp/requirements.txt

# Production stage
FROM python:3.11-slim-bullseye

# Security updates
RUN apt-get update && apt-get upgrade -y \\
    && apt-get install -y --no-install-recommends \\
    libpq5 \\
    curl \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN groupadd -r polyweather && useradd -r -g polyweather -u 1000 polyweather

# Copy Python packages from builder
COPY --from=builder /root/.local /home/polyweather/.local

# Set up application directory
WORKDIR /app
RUN chown -R polyweather:polyweather /app

# Copy application code
COPY --chown=polyweather:polyweather src/ /app/src/
COPY --chown=polyweather:polyweather scripts/ /app/scripts/

# Create necessary directories
RUN mkdir -p /app/logs /app/tmp /app/data \\
    && chown -R polyweather:polyweather /app

# Security: Switch to non-root user
USER polyweather

# Set Python path
ENV PYTHONPATH=/app/src
ENV PATH=/home/polyweather/.local/bin:\$PATH

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
CMD ["python", "-m", "polyweather.main"]
EOF

# Set up log rotation
log_info "Setting up log rotation..."
sudo tee /etc/logrotate.d/polyweather << EOF >/dev/null || log_warn "Could not setup log rotation (requires sudo)"
$PROJECT_DIR/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $(whoami) $(whoami)
    postrotate
        /usr/bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

# Create monitoring configuration
log_info "Creating secure Prometheus configuration..."
cat > "$PROJECT_DIR/monitoring/prometheus-secure.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'production'
    service: 'polyweather-trading'

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'polyweather-bot'
    static_configs:
      - targets: ['polyweather-bot:9090']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 5s
    
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
    scrape_interval: 30s
    
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
    scrape_interval: 30s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

# Create security validation script
log_info "Creating security validation script..."
cat > "$PROJECT_DIR/scripts/validate-security.sh" << 'EOF'
#!/bin/bash

# Security Validation Script for PolyWeather Trading Bot
set -euo pipefail

echo "🔍 Security Validation Check"
echo "============================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check secrets exist and have correct permissions
echo "Checking secrets..."
for secret in postgres_user.txt postgres_password.txt redis_password.txt jwt_secret.txt api_keys.txt; do
    if [[ -f "secrets/$secret" ]]; then
        perms=$(stat -c "%a" "secrets/$secret")
        if [[ "$perms" == "600" ]]; then
            check_pass "Secret $secret exists with correct permissions (600)"
        else
            check_fail "Secret $secret has incorrect permissions: $perms (should be 600)"
        fi
    else
        check_fail "Secret $secret missing"
    fi
done

# Check SSL certificates
echo "Checking SSL certificates..."
for cert in ca.crt server.crt server.key; do
    if [[ -f "database/ssl/$cert" ]]; then
        check_pass "SSL certificate $cert exists"
    else
        check_fail "SSL certificate $cert missing"
    fi
done

# Check directory permissions
echo "Checking directory permissions..."
if [[ -d "secrets" ]]; then
    perms=$(stat -c "%a" "secrets")
    if [[ "$perms" == "700" ]]; then
        check_pass "Secrets directory has correct permissions (700)"
    else
        check_fail "Secrets directory has incorrect permissions: $perms"
    fi
fi

# Check for default passwords
echo "Checking for default passwords..."
if grep -q "changeme\|password123\|admin" secrets/*.txt 2>/dev/null; then
    check_fail "Default passwords detected in secrets"
else
    check_pass "No default passwords found"
fi

# Check configuration files
echo "Checking configuration files..."
if [[ -f "database/config/postgresql-secure.conf" ]]; then
    check_pass "Secure PostgreSQL configuration exists"
else
    check_fail "Secure PostgreSQL configuration missing"
fi

if [[ -f "redis/config/redis-secure.conf" ]]; then
    check_pass "Secure Redis configuration exists" 
else
    check_fail "Secure Redis configuration missing"
fi

# Summary
echo ""
echo "Security Validation Summary:"
echo "============================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All security checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Security validation failed. Please fix the issues above.${NC}"
    exit 1
fi
EOF

chmod +x "$PROJECT_DIR/scripts/validate-security.sh"
chmod +x "$PROJECT_DIR/scripts/setup-security.sh"

# Create backup script
log_info "Creating backup script..."
cat > "$PROJECT_DIR/scripts/backup-secure.sh" << EOF
#!/bin/bash

# Secure Backup Script for PolyWeather Trading Bot
set -euo pipefail

BACKUP_DIR="/tmp/polyweather-backup-\$(date +%Y%m%d_%H%M%S)"
PROJECT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"

echo "Creating secure backup in \$BACKUP_DIR"
mkdir -p "\$BACKUP_DIR"

# Backup database
docker exec polyweather-postgres-secure pg_dump -U \$(cat "$SECRETS_DIR/postgres_user.txt") polyweather > "\$BACKUP_DIR/database.sql"

# Backup configuration (without secrets)
cp -r "\$PROJECT_DIR/database/config" "\$BACKUP_DIR/"
cp -r "\$PROJECT_DIR/redis/config" "\$BACKUP_DIR/"
cp "\$PROJECT_DIR/docker-compose-secure.yml" "\$BACKUP_DIR/"

# Create encrypted archive
tar czf "\$BACKUP_DIR.tar.gz" -C "\$(dirname "\$BACKUP_DIR")" "\$(basename "\$BACKUP_DIR")"
openssl enc -aes-256-cbc -salt -in "\$BACKUP_DIR.tar.gz" -out "\$BACKUP_DIR.tar.gz.enc" -k "\$(cat $SECRETS_DIR/jwt_secret.txt)"

# Cleanup
rm -rf "\$BACKUP_DIR" "\$BACKUP_DIR.tar.gz"

echo "Encrypted backup created: \$BACKUP_DIR.tar.gz.enc"
EOF

chmod +x "$PROJECT_DIR/scripts/backup-secure.sh"

# Final security summary
log_info "Security setup completed successfully!"
echo ""
echo "🔐 SECURITY SETUP SUMMARY"
echo "========================="
echo "✓ Secure credentials generated in: $SECRETS_DIR/"
echo "✓ SSL certificates created in: $SSL_DIR/"
echo "✓ Database security scripts created"
echo "✓ Redis secure configuration created"
echo "✓ Docker security configuration created"
echo "✓ Monitoring configuration secured"
echo "✓ Backup and validation scripts created"
echo ""
echo "🚨 IMPORTANT NEXT STEPS:"
echo "1. Copy .env.secure to .env and customize API keys"
echo "2. Run: ./scripts/validate-security.sh"
echo "3. Use docker-compose-secure.yml for deployment"
echo "4. Keep the secrets/ directory secure and backed up"
echo ""
log_warn "NEVER commit secrets/ directory to version control!"
log_warn "Change all default passwords before production deployment!"