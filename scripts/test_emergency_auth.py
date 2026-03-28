#!/usr/bin/env python3
"""
Test script for emergency authentication system.
"""

import sys
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from polyweather.security.totp_auth import totp_auth, verify_emergency_token
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def test_totp_generation():
    """Test TOTP token generation."""
    print("🔐 Testing TOTP Generation")
    print("=" * 40)
    
    try:
        # Generate current token
        token = totp_auth.generate_token()
        print(f"Current TOTP token: {token}")
        
        # Verify it
        is_valid = totp_auth.verify_token(token)
        print(f"Token verification: {'✓ Valid' if is_valid else '❌ Invalid'}")
        
        # Test time tolerance
        print("\n🕐 Testing time tolerance...")
        import time
        time.sleep(1)  # Wait a second
        is_still_valid = totp_auth.verify_token(token)
        print(f"Token after 1 second: {'✓ Valid' if is_still_valid else '❌ Invalid'}")
        
        return True
        
    except Exception as e:
        print(f"❌ TOTP test failed: {e}")
        return False


def test_backup_codes():
    """Test backup code generation and verification."""
    print("\n🔑 Testing Backup Codes")
    print("=" * 40)
    
    try:
        # Generate backup codes
        backup_codes = totp_auth.get_backup_codes(count=5)
        print(f"Generated {len(backup_codes)} backup codes:")
        for i, code in enumerate(backup_codes, 1):
            print(f"  {i}. {code}")
        
        # Test verification and consumption
        test_code = backup_codes[0]
        print(f"\nTesting backup code: {test_code}")
        
        is_valid = totp_auth.verify_backup_code(test_code)
        print(f"Backup code verification: {'✓ Valid' if is_valid else '❌ Invalid'}")
        
        # Try to use the same code again (should fail)
        is_valid_again = totp_auth.verify_backup_code(test_code)
        print(f"Reusing backup code: {'❌ Rejected' if not is_valid_again else '⚠️ Allowed (ERROR)'}")
        
        return True
        
    except Exception as e:
        print(f"❌ Backup code test failed: {e}")
        return False


def test_emergency_verification():
    """Test the main emergency verification function."""
    print("\n🚨 Testing Emergency Verification")
    print("=" * 40)
    
    try:
        # Test current TOTP
        current_token = totp_auth.generate_token()
        print(f"Testing TOTP token: {current_token}")
        
        is_valid = verify_emergency_token(current_token)
        print(f"Emergency TOTP verification: {'✓ Valid' if is_valid else '❌ Invalid'}")
        
        # Test invalid token
        invalid_token = "123456"
        is_invalid = verify_emergency_token(invalid_token)
        print(f"Invalid token rejection: {'✓ Rejected' if not is_invalid else '❌ Accepted (ERROR)'}")
        
        # Test invalid format
        bad_format = "12345"
        is_bad_format = verify_emergency_token(bad_format)
        print(f"Bad format rejection: {'✓ Rejected' if not is_bad_format else '❌ Accepted (ERROR)'}")
        
        return True
        
    except Exception as e:
        print(f"❌ Emergency verification test failed: {e}")
        return False


def interactive_test():
    """Interactive test where user enters tokens."""
    print("\n🧪 Interactive Testing")
    print("=" * 40)
    print("Enter TOTP codes from your authenticator app to test")
    print("Enter 'quit' to exit")
    
    while True:
        token = input("\nEnter TOTP token: ").strip()
        
        if token.lower() in ('quit', 'exit', 'q'):
            break
            
        if not token:
            continue
            
        try:
            is_valid = verify_emergency_token(token)
            if is_valid:
                print("✓ Token accepted!")
            else:
                print("❌ Token rejected")
                
                # Give hints
                if len(token) != 6:
                    print("   Hint: TOTP tokens are 6 digits")
                elif not token.isdigit():
                    print("   Hint: TOTP tokens are numeric")
                else:
                    print("   Hint: Check your authenticator app time sync")
                    
        except Exception as e:
            print(f"❌ Error testing token: {e}")


def show_setup_info():
    """Show setup information for TOTP."""
    print("\n📋 TOTP Setup Information")
    print("=" * 40)
    
    try:
        # Show provisioning URI
        uri = totp_auth.get_provisioning_uri("emergency")
        print(f"Setup URI: {uri}")
        
        # Try to generate QR code
        try:
            qr_path = totp_auth.generate_qr_code("emergency")
            print(f"QR code saved to: {qr_path}")
        except Exception as e:
            print(f"QR code generation failed: {e}")
            print("You can set up manually with the URI above")
            
    except Exception as e:
        print(f"❌ Setup info failed: {e}")


def main():
    """Main test function."""
    print("""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    PolyWeather Emergency Auth Test                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
""")
    
    # Run automated tests
    test_results = []
    
    test_results.append(("TOTP Generation", test_totp_generation()))
    test_results.append(("Backup Codes", test_backup_codes()))
    test_results.append(("Emergency Verification", test_emergency_verification()))
    
    # Show results summary
    print("\n📊 Test Results Summary")
    print("=" * 40)
    
    all_passed = True
    for test_name, passed in test_results:
        status = "✓ PASSED" if passed else "❌ FAILED"
        print(f"{test_name:25} {status}")
        if not passed:
            all_passed = False
    
    print(f"\nOverall: {'✓ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
    
    if not all_passed:
        print("\n⚠️  Some tests failed. Check the setup and try again.")
        return 1
    
    # Show setup info
    show_setup_info()
    
    # Offer interactive testing
    run_interactive = input("\nRun interactive test? (y/N): ")
    if run_interactive.lower() == 'y':
        interactive_test()
    
    print("\n🎉 Emergency authentication testing completed!")
    return 0


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)