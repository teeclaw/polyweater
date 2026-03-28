#!/usr/bin/env python3
"""
Security setup script for PolyWeather trading bot.
Sets up encryption keys, TOTP authentication, and migrates plaintext credentials.
"""

import os
import sys
import asyncio
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from polyweather.security.key_manager import migrate_plaintext_keys, key_manager
from polyweather.security.totp_auth import setup_emergency_auth
from polyweather.security.secure_config import secure_config, validate_security_setup
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def print_banner():
    """Print security setup banner."""
    print("""
╔══════════════════════════════════════════════════════════════════════════════╗
║                        PolyWeather Security Setup                           ║
║                                                                              ║
║   This script will configure enterprise-grade security for your trading     ║
║   bot, including encrypted key storage and TOTP emergency authentication.   ║
║                                                                              ║
║   ⚠️  CRITICAL: Store all generated keys and codes securely!                ║
╚══════════════════════════════════════════════════════════════════════════════╝
""")


def check_dependencies():
    """Check if required security dependencies are installed."""
    required_packages = [
        'cryptography',
        'PyJWT',
        'qrcode',
        'pillow'
    ]
    
    missing = []
    for package in required_packages:
        try:
            __import__(package.replace('-', '_').lower())
        except ImportError:
            missing.append(package)
    
    if missing:
        print(f"❌ Missing required packages: {', '.join(missing)}")
        print(f"Install with: pip install {' '.join(missing)}")
        return False
    
    return True


def setup_encryption_keys():
    """Set up encryption keys for sensitive data."""
    print("\n🔐 Setting up encryption keys...")
    
    # This will auto-generate keys if they don't exist
    from polyweather.security.key_manager import key_manager
    from polyweather.utils.redis_cache import redis_cache
    
    print("✓ Private key encryption initialized")
    print("✓ Redis cache encryption initialized")
    
    # Migrate any plaintext keys
    migrated = migrate_plaintext_keys()
    if migrated:
        print(f"✓ Migrated {len(migrated)} plaintext keys to encrypted storage")
        for env_var, key_id, path in migrated:
            print(f"  • {env_var} -> {path}")
    else:
        print("✓ No plaintext keys found to migrate")


def setup_emergency_authentication():
    """Set up TOTP-based emergency authentication."""
    print("\n🔒 Setting up emergency authentication...")
    
    try:
        success = setup_emergency_auth()
        if success:
            print("✓ TOTP emergency authentication configured")
        else:
            print("❌ TOTP setup failed")
            return False
    except Exception as e:
        print(f"❌ Emergency auth setup failed: {e}")
        return False
    
    return True


def validate_redis_security():
    """Validate Redis security configuration."""
    print("\n🗄️ Checking Redis security...")
    
    redis_password = os.getenv('REDIS_PASSWORD')
    if not redis_password:
        print("⚠️  WARNING: No Redis password configured")
        print("   Set REDIS_PASSWORD environment variable for secure Redis access")
        
        password = input("Generate Redis password? (Y/n): ")
        if password.lower() != 'n':
            import secrets
            redis_password = secrets.token_urlsafe(16)
            print(f"Generated Redis password: {redis_password}")
            print("Add this to your .env file:")
            print(f"REDIS_PASSWORD={redis_password}")
            print("And restart Redis with authentication enabled")
    else:
        print("✓ Redis password configured")


def validate_database_security():
    """Validate database security configuration."""
    print("\n🗃️ Checking database security...")
    
    db_url = os.getenv('DATABASE_URL', '')
    
    if 'localhost' in db_url or '127.0.0.1' in db_url:
        print("⚠️  WARNING: Database appears to be on localhost")
        print("   For production, use a dedicated database server with proper authentication")
    
    if '@' not in db_url:
        print("❌ No database authentication found in DATABASE_URL")
        print("   Ensure DATABASE_URL includes username and password")
    else:
        print("✓ Database authentication configured")


def setup_cors_security():
    """Configure CORS security settings."""
    print("\n🌐 Configuring CORS security...")
    
    cors_origins = os.getenv('CORS_ALLOWED_ORIGINS')
    if not cors_origins:
        print("⚠️  WARNING: No CORS origins configured")
        print("   Set CORS_ALLOWED_ORIGINS to restrict API access")
        
        origins = input("Enter allowed origins (comma-separated): ")
        if origins.strip():
            print(f"Add to .env file:")
            print(f"CORS_ALLOWED_ORIGINS={origins}")
    else:
        print("✓ CORS origins configured")


def generate_security_checklist():
    """Generate post-setup security checklist."""
    print("""
╔══════════════════════════════════════════════════════════════════════════════╗
║                           SECURITY CHECKLIST                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 Post-Setup Security Tasks:

1. 🔐 ENVIRONMENT VARIABLES
   □ Remove plaintext keys from .env files
   □ Set POLYWEATHER_MASTER_KEY securely
   □ Set REDIS_PASSWORD for Redis authentication
   □ Set CORS_ALLOWED_ORIGINS for API security

2. 📱 EMERGENCY AUTHENTICATION  
   □ Configure TOTP in your authenticator app
   □ Store backup codes securely (printed above)
   □ Test emergency authentication

3. 🖥️ SERVER SECURITY
   □ Enable Redis authentication (requirepass)
   □ Use TLS for Redis connections in production
   □ Enable PostgreSQL SSL/TLS
   □ Configure firewall to restrict access

4. 🔄 ONGOING SECURITY
   □ Rotate keys regularly (quarterly)
   □ Monitor rate limiting logs
   □ Review authentication logs
   □ Update security dependencies

5. 🚨 EMERGENCY PROCEDURES
   □ Document key recovery process
   □ Test emergency shutdown procedures
   □ Backup encrypted key files
   □ Document TOTP recovery process

⚠️  CRITICAL REMINDERS:
   • Store master keys and backup codes separately
   • Never commit secrets to version control
   • Use environment variables for all sensitive data
   • Test all authentication before production deployment
""")


async def main():
    """Main setup function."""
    print_banner()
    
    # Check dependencies
    if not check_dependencies():
        return 1
    
    # Validate existing security setup
    print("🔍 Validating current security setup...")
    is_valid = validate_security_setup()
    
    if is_valid:
        print("✓ Basic security validation passed")
    else:
        print("⚠️  Security issues detected - proceeding with setup")
    
    # Setup encryption
    setup_encryption_keys()
    
    # Setup emergency auth
    if not setup_emergency_authentication():
        print("❌ Emergency authentication setup failed")
        return 1
    
    # Validate infrastructure security
    validate_redis_security()
    validate_database_security()
    setup_cors_security()
    
    # Final validation
    print("\n🔍 Final security validation...")
    final_validation = secure_config.validate_configuration()
    
    print(f"Security status: {'✓ Valid' if final_validation['valid'] else '❌ Issues detected'}")
    print(f"Secure keys: {final_validation['secure_keys_count']}")
    print(f"Plaintext keys: {final_validation['plaintext_keys_count']}")
    
    if final_validation['warnings']:
        print("\nRemaining warnings:")
        for warning in final_validation['warnings']:
            print(f"  ⚠️  {warning}")
    
    if final_validation['errors']:
        print("\nRemaining errors:")
        for error in final_validation['errors']:
            print(f"  ❌ {error}")
    
    # Generate checklist
    generate_security_checklist()
    
    print("\n🎉 Security setup completed!")
    print("🔒 Your trading bot is now configured with enterprise-grade security.")
    
    return 0 if final_validation['valid'] else 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)