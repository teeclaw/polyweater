# scripts/ - Automation & Deployment Scripts

## PURPOSE
Comprehensive automation scripts for deployment, testing, maintenance, and security validation.

## SCRIPT CATEGORIES

### 🚀 DEPLOYMENT & STARTUP
- `start-bot.sh` - Main trading bot startup
- `start-dashboard.sh` - React dashboard launcher (deprecated)
- `start-streamlit.sh` - Streamlit dashboard launcher (current)
- `start-enhanced-bot.sh` - Enhanced bot with additional features
- `start-with-controls.sh` - Bot with trading controls enabled
- `setup.sh` - Complete system setup automation

### 🔒 SECURITY & SSL
- `setup-security.sh` - Security hardening automation  
- `setup-ssl.sh` - SSL certificate generation and installation
- `setup_security.py` - Python-based security validation
- `sshd_secure.conf` - SSH hardening configuration

### 🌐 REMOTE ACCESS
- `setup-remote-access.sh` - GCP remote access configuration
- `setup-ssh-access.sh` - SSH tunnel and key setup
- `setup-cloudflare-tunnel.sh` - Cloudflare tunnel integration
- `client-tunnel.sh` - Client-side tunnel connection

### 🧪 TESTING & VALIDATION  
- `test-apis.py` - API integration testing
- `test-enhanced-apis.py` - Enhanced API testing suite
- `test-phase13.py` - Phase 1.3 validation tests
- `test-trading-controls.py` - Trading control validation
- `test_emergency_auth.py` - Emergency authentication testing
- `validate-phase13.py` - Phase 1.3 system validation
- `verify-dashboard.sh` - Dashboard functionality verification

### ⚡ HEALTH & MAINTENANCE
- `health-check.sh` - System health validation
- `health-check-remote.sh` - Remote system health checking
- `maintenance.sh` - Automated maintenance tasks

## EXECUTION PATTERNS
```bash
# Development workflow
./scripts/setup.sh                    # Initial setup
./scripts/test-apis.py                # Validate APIs  
./scripts/start-streamlit.sh          # Launch dashboard

# Production deployment
./scripts/setup-security.sh           # Harden security
./scripts/setup-ssl.sh               # Configure SSL
./scripts/setup-remote-access.sh     # Enable remote access
./scripts/start-with-controls.sh     # Launch with safety controls

# Maintenance
./scripts/health-check.sh             # System validation
./scripts/maintenance.sh              # Cleanup and optimization
```

## RELATIONS
- **Deploys**: All application services and infrastructure
- **Tests**: API integrations and system functionality  
- **Maintains**: Database, logs, and security configurations
- **Monitors**: System health and performance metrics

## SECURITY NOTES
- All scripts have proper file permissions (755)
- Sensitive operations require explicit confirmation
- API keys and secrets handled securely via environment variables

**Automation ensures consistent, repeatable deployments and operations**