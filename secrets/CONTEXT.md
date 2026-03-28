# secrets/ - API Keys & Sensitive Data

## ⚠️ SECURITY CRITICAL DIRECTORY

## PURPOSE
Secure storage for API keys, authentication tokens, database credentials, and other sensitive configuration data.

## CONTENTS
```
secrets/
├── api_keys.txt           # External API keys (weather, trading)
├── jwt_secret.txt         # JWT token signing secret
├── postgres_password.txt  # Database authentication
├── postgres_user.txt      # Database username
└── redis_password.txt     # Redis cache authentication
```

## SECURITY MEASURES
- **File Permissions**: 600 (owner read/write only)
- **Git Ignored**: Never committed to version control
- **Environment Loading**: Sourced via Docker secrets or .env files
- **Rotation Policy**: Keys rotated monthly or on security events

## API KEY MANAGEMENT
### Required Keys
```
POLYMARKET_API_KEY     → Trading operations
OPENWEATHER_API_KEY    → Weather data fetching  
NOAA_API_KEY          → Government weather data
POLYCLAW_PRIVATE_KEY  → Wallet transaction signing
```

### Secret Management Flow
```
External Services → API Keys → secrets/ → Environment Variables → Application
```

## ACCESS PATTERNS
- **Docker Compose**: Mounted as volumes with restricted permissions
- **Environment Variables**: Loaded via .env file sourcing
- **Application Code**: Accessed through environment variable lookup
- **Never**: Hardcoded in source code or configuration files

## RELATIONS
- **Sources from**: External API provider dashboards
- **Consumed by**: Backend services and trading bot
- **Protected by**: File system permissions and Docker secrets
- **Backed up to**: Encrypted offline storage only

## EMERGENCY PROCEDURES
- **Key Compromise**: Immediate rotation and service restart
- **Access Audit**: Regular review of file access patterns
- **Backup Verification**: Encrypted backups tested monthly

## ⚠️ CRITICAL SECURITY WARNINGS
- **NEVER** commit files in this directory to Git
- **NEVER** share keys via chat, email, or insecure channels  
- **ALWAYS** use environment variables in application code
- **IMMEDIATELY** rotate compromised keys

**This directory protects the $50 trading capital and system integrity**