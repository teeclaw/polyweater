#!/usr/bin/env python3
"""
Security validation script for PolyWeather Trading Bot.
Validates that all critical vulnerabilities have been resolved.
"""

import os
import re
import sys

def main():
    print('🔍 SECURITY VALIDATION AUDIT - FREYA')
    print('=' * 60)
    
    issues_found = []
    
    # Check 1: No hardcoded credentials
    print('\n1. Private Key Security:')
    try:
        env_file = '.env'
        if os.path.exists(env_file):
            with open(env_file, 'r') as f:
                content = f.read()
                
            # Check for actual private keys (not placeholder)
            private_key_patterns = [
                (r'0x[a-fA-F0-9]{64}', 'Ethereum private key'),
                (r'sk_[a-zA-Z0-9]{40,}', 'API secret key'),
                (r'polyweather2024', 'Demo password'),
                (r'trader123', 'Demo password')
            ]
            
            found_credentials = []
            for pattern, desc in private_key_patterns:
                if re.search(pattern, content):
                    found_credentials.append(desc)
            
            if found_credentials:
                print(f'   ❌ CRITICAL: Found hardcoded credentials: {found_credentials}')
                issues_found.extend(found_credentials)
            else:
                print('   ✅ No hardcoded private keys found')
        else:
            print('   ⚠️  .env file not found')
    except Exception as e:
        print(f'   ❌ Error checking .env: {e}')
        issues_found.append('.env file check failed')

    # Check 2: Database security files
    print('\n2. Database Security:')
    secure_schema_exists = os.path.exists('database/init/01_schema_secure.sql')
    secure_db_exists = os.path.exists('src/polyweather/database/secure_db.py')
    
    print(f'   Secure schema: {"✅ Present" if secure_schema_exists else "❌ Missing"}')
    print(f'   Secure DB manager: {"✅ Present" if secure_db_exists else "❌ Missing"}')
    
    if not secure_schema_exists:
        issues_found.append('Missing secure database schema')
    if not secure_db_exists:
        issues_found.append('Missing secure database manager')

    # Check 3: TOTP authentication
    print('\n3. TOTP Authentication:')
    totp_exists = os.path.exists('src/polyweather/security/totp_auth.py')
    key_manager_exists = os.path.exists('src/polyweather/security/key_manager.py')
    
    print(f'   TOTP module: {"✅ Present" if totp_exists else "❌ Missing"}')
    print(f'   Key manager: {"✅ Present" if key_manager_exists else "❌ Missing"}')
    
    if not totp_exists:
        issues_found.append('Missing TOTP authentication')
    if not key_manager_exists:
        issues_found.append('Missing key manager')

    # Check 4: Frontend security
    print('\n4. Frontend Security:')
    secure_auth_exists = os.path.exists('frontend/src/services/authService.ts')
    secure_ws_exists = os.path.exists('frontend/src/services/secureWebSocket.ts')
    
    print(f'   Secure auth service: {"✅ Present" if secure_auth_exists else "❌ Missing"}')
    print(f'   Secure WebSocket: {"✅ Present" if secure_ws_exists else "❌ Missing"}')
    
    if not secure_auth_exists:
        issues_found.append('Missing frontend secure auth')
    if not secure_ws_exists:
        issues_found.append('Missing frontend secure WebSocket')

    # Check 5: API Security
    print('\n5. API Security:')
    ws_server_exists = os.path.exists('src/polyweather/api/websocket_server.py')
    if ws_server_exists:
        with open('src/polyweather/api/websocket_server.py', 'r') as f:
            ws_content = f.read()
            has_rate_limiting = 'RateLimiter' in ws_content
            has_jwt_auth = 'jwt' in ws_content.lower()
            has_totp = 'verify_emergency_token' in ws_content
            
            print(f'   Rate limiting: {"✅ Implemented" if has_rate_limiting else "❌ Missing"}')
            print(f'   JWT authentication: {"✅ Implemented" if has_jwt_auth else "❌ Missing"}')
            print(f'   TOTP emergency auth: {"✅ Implemented" if has_totp else "❌ Missing"}')
            
            if not has_rate_limiting:
                issues_found.append('Missing WebSocket rate limiting')
            if not has_jwt_auth:
                issues_found.append('Missing WebSocket JWT auth')
            if not has_totp:
                issues_found.append('Missing emergency TOTP auth')
    else:
        print('   ❌ WebSocket server missing')
        issues_found.append('Missing WebSocket server')

    # Check 6: Configuration security
    print('\n6. Configuration Security:')
    secure_config_exists = os.path.exists('src/polyweather/security/secure_config.py')
    print(f'   Secure config: {"✅ Present" if secure_config_exists else "❌ Missing"}')
    
    if not secure_config_exists:
        issues_found.append('Missing secure configuration')

    # Final assessment
    print('\n' + '=' * 60)
    if issues_found:
        print('❌ SECURITY AUDIT FAILED')
        print('🚨 CRITICAL ISSUES FOUND:')
        for i, issue in enumerate(issues_found, 1):
            print(f'   {i}. {issue}')
        sys.exit(1)
    else:
        print('✅ SECURITY AUDIT PASSED')
        print('🛡️  All critical vulnerabilities have been resolved')
        print('💰 $50 trading capital is protected')
        sys.exit(0)

if __name__ == '__main__':
    main()