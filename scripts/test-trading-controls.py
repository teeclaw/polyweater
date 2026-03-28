#!/usr/bin/env python3
"""
Test script for PolyWeather Trading Bot Control System
Phase 2.2: Comprehensive validation of trading controls
"""

import asyncio
import json
import time
import requests
import websocket
from typing import Dict, Any
import logging

# Test configuration
API_BASE_URL = "http://localhost:8080"
WS_URL = "ws://localhost:8080/api/v1/ws"
EMERGENCY_TOKEN = "EMERGENCY_CONFIRM_2024"

# Test results tracking
test_results = []

def log_test_result(test_name: str, success: bool, message: str, response_time: float = 0):
    """Log test result"""
    test_results.append({
        "test": test_name,
        "success": success,
        "message": message,
        "response_time_ms": response_time * 1000
    })
    
    status = "✓ PASS" if success else "✗ FAIL"
    time_str = f"({response_time*1000:.1f}ms)" if response_time > 0 else ""
    print(f"{status} {test_name}: {message} {time_str}")

def test_api_health():
    """Test API health endpoint"""
    try:
        start_time = time.time()
        response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            log_test_result(
                "API Health Check", 
                True, 
                f"API is healthy - {data.get('status', 'unknown')}", 
                response_time
            )
        else:
            log_test_result("API Health Check", False, f"HTTP {response.status_code}")
            
    except Exception as e:
        log_test_result("API Health Check", False, f"Connection failed: {e}")

def test_bot_status():
    """Test bot status endpoint"""
    try:
        start_time = time.time()
        response = requests.get(f"{API_BASE_URL}/api/v1/bot/status", timeout=5)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            log_test_result(
                "Bot Status", 
                True, 
                f"Status retrieved - Running: {data.get('running', 'unknown')}", 
                response_time
            )
            return data
        else:
            log_test_result("Bot Status", False, f"HTTP {response.status_code}")
            
    except Exception as e:
        log_test_result("Bot Status", False, f"Request failed: {e}")
    
    return None

def test_kill_switch():
    """Test bot control (kill switch functionality)"""
    try:
        # Test stop command
        start_time = time.time()
        response = requests.post(
            f"{API_BASE_URL}/api/v1/bot/control",
            json={"action": "stop"},
            timeout=10
        )
        response_time = time.time() - start_time
        
        if response.status_code in [200, 400]:  # 400 might be "already stopped"
            log_test_result(
                "Kill Switch (Stop)", 
                response_time < 5.0, 
                f"Response time: {response_time:.2f}s (target: <5s)", 
                response_time
            )
        else:
            log_test_result("Kill Switch (Stop)", False, f"HTTP {response.status_code}")
            
    except Exception as e:
        log_test_result("Kill Switch (Stop)", False, f"Request failed: {e}")

def test_parameter_updates():
    """Test real-time parameter updates"""
    try:
        # Test getting current parameters
        response = requests.get(f"{API_BASE_URL}/api/v1/trading/parameters", timeout=5)
        
        if response.status_code == 200:
            original_params = response.json()
            log_test_result("Get Parameters", True, "Parameters retrieved successfully")
            
            # Test updating parameters
            new_params = {
                "max_trades_per_day": 5,
                "max_position_size": 8.0,
                "min_confidence": 0.7,
                "daily_loss_limit": 4.0
            }
            
            start_time = time.time()
            response = requests.post(
                f"{API_BASE_URL}/api/v1/trading/parameters",
                json=new_params,
                timeout=5
            )
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                log_test_result(
                    "Update Parameters", 
                    response_time < 1.0, 
                    f"Parameters updated in {response_time:.3f}s (target: <1s)", 
                    response_time
                )
            else:
                log_test_result("Update Parameters", False, f"HTTP {response.status_code}")
        else:
            log_test_result("Get Parameters", False, f"HTTP {response.status_code}")
            
    except Exception as e:
        log_test_result("Parameter Updates", False, f"Request failed: {e}")

def test_emergency_controls():
    """Test emergency control functions"""
    try:
        # Test emergency pause
        response = requests.post(
            f"{API_BASE_URL}/api/v1/emergency/control",
            json={
                "action": "pause_trading",
                "confirm_token": EMERGENCY_TOKEN
            },
            timeout=10
        )
        
        if response.status_code == 200:
            log_test_result("Emergency Pause", True, "Emergency pause executed successfully")
        else:
            log_test_result("Emergency Pause", False, f"HTTP {response.status_code}")
            
        # Test with invalid token
        response = requests.post(
            f"{API_BASE_URL}/api/v1/emergency/control",
            json={
                "action": "pause_trading", 
                "confirm_token": "INVALID_TOKEN"
            },
            timeout=5
        )
        
        if response.status_code == 403:
            log_test_result("Emergency Auth", True, "Invalid token correctly rejected")
        else:
            log_test_result("Emergency Auth", False, "Security vulnerability - invalid token accepted")
            
    except Exception as e:
        log_test_result("Emergency Controls", False, f"Request failed: {e}")

def test_risk_overrides():
    """Test risk management overrides"""
    try:
        override_data = {
            "override_type": "daily_limit",
            "value": 10,
            "duration_hours": 1.0,
            "reason": "Testing risk override functionality for automated validation"
        }
        
        response = requests.post(
            f"{API_BASE_URL}/api/v1/risk/override",
            json=override_data,
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            override_id = data.get("override_id")
            log_test_result("Create Risk Override", True, f"Override created: {override_id}")
            
            # Test deleting the override
            if override_id:
                response = requests.delete(
                    f"{API_BASE_URL}/api/v1/risk/override/{override_id}",
                    timeout=5
                )
                
                if response.status_code == 200:
                    log_test_result("Delete Risk Override", True, "Override deleted successfully")
                else:
                    log_test_result("Delete Risk Override", False, f"HTTP {response.status_code}")
        else:
            log_test_result("Create Risk Override", False, f"HTTP {response.status_code}")
            
    except Exception as e:
        log_test_result("Risk Overrides", False, f"Request failed: {e}")

def test_websocket_connection():
    """Test WebSocket real-time updates"""
    try:
        connected = False
        messages_received = 0
        connection_time = 0
        
        def on_open(ws):
            nonlocal connected, connection_time
            connected = True
            connection_time = time.time()
            # Send ping to test communication
            ws.send(json.dumps({"type": "ping"}))
        
        def on_message(ws, message):
            nonlocal messages_received
            messages_received += 1
            data = json.loads(message)
            if data.get("type") == "pong":
                ws.close()
        
        def on_error(ws, error):
            log_test_result("WebSocket Connection", False, f"WebSocket error: {error}")
        
        # Create WebSocket connection
        ws = websocket.WebSocketApp(
            WS_URL,
            on_open=on_open,
            on_message=on_message,
            on_error=on_error
        )
        
        # Run with timeout
        ws.run_forever(ping_timeout=5)
        
        if connected and messages_received > 0:
            log_test_result("WebSocket Connection", True, "WebSocket communication successful")
        else:
            log_test_result("WebSocket Connection", False, "WebSocket communication failed")
            
    except Exception as e:
        log_test_result("WebSocket Connection", False, f"Connection failed: {e}")

def test_performance_requirements():
    """Test performance requirements"""
    print("\n=== Performance Requirements ===")
    
    # Analyze test results for performance metrics
    kill_switch_tests = [r for r in test_results if "Kill Switch" in r["test"]]
    parameter_tests = [r for r in test_results if "Parameter" in r["test"]]
    
    # Kill switch performance (target: <5 seconds)
    kill_switch_times = [r["response_time_ms"] for r in kill_switch_tests if r["response_time_ms"] > 0]
    if kill_switch_times:
        avg_kill_switch_time = sum(kill_switch_times) / len(kill_switch_times)
        meets_requirement = avg_kill_switch_time < 5000
        log_test_result(
            "Kill Switch Performance", 
            meets_requirement, 
            f"Average: {avg_kill_switch_time:.1f}ms (requirement: <5000ms)"
        )
    
    # Parameter update performance (target: <1 second)
    param_update_times = [r["response_time_ms"] for r in parameter_tests if r["response_time_ms"] > 0]
    if param_update_times:
        avg_param_time = sum(param_update_times) / len(param_update_times)
        meets_requirement = avg_param_time < 1000
        log_test_result(
            "Parameter Update Performance", 
            meets_requirement, 
            f"Average: {avg_param_time:.1f}ms (requirement: <1000ms)"
        )

def print_test_summary():
    """Print comprehensive test summary"""
    print("\n" + "="*60)
    print("POLYWEATHER TRADING CONTROLS TEST SUMMARY")
    print("="*60)
    
    total_tests = len(test_results)
    passed_tests = len([r for r in test_results if r["success"]])
    failed_tests = total_tests - passed_tests
    
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {failed_tests}")
    print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")
    
    if failed_tests > 0:
        print(f"\nFAILED TESTS:")
        for result in test_results:
            if not result["success"]:
                print(f"  ✗ {result['test']}: {result['message']}")
    
    print(f"\nPERFORMANCE SUMMARY:")
    response_times = [r["response_time_ms"] for r in test_results if r["response_time_ms"] > 0]
    if response_times:
        print(f"  Average Response Time: {sum(response_times)/len(response_times):.1f}ms")
        print(f"  Fastest Response: {min(response_times):.1f}ms")
        print(f"  Slowest Response: {max(response_times):.1f}ms")
    
    # Critical requirements check
    critical_fails = []
    for result in test_results:
        if not result["success"] and any(keyword in result["test"] for keyword in ["Kill Switch", "Emergency", "API Health"]):
            critical_fails.append(result["test"])
    
    if critical_fails:
        print(f"\n⚠️  CRITICAL FAILURES DETECTED:")
        for fail in critical_fails:
            print(f"  - {fail}")
        print("\nThe trading bot control system may not be safe for production use!")
    else:
        print(f"\n✅ All critical safety systems are operational")
    
    print("="*60)

def main():
    """Main test execution"""
    print("PolyWeather Trading Bot Control System Test Suite")
    print("Phase 2.2: Comprehensive Trading Controls Validation")
    print("=" * 60)
    
    # Basic connectivity tests
    print("\n=== Connectivity Tests ===")
    test_api_health()
    test_bot_status()
    
    # Core functionality tests
    print("\n=== Core Functionality Tests ===")
    test_kill_switch()
    test_parameter_updates()
    
    # Safety and security tests
    print("\n=== Safety & Security Tests ===")
    test_emergency_controls()
    test_risk_overrides()
    
    # Real-time communication tests
    print("\n=== Real-time Communication Tests ===")
    test_websocket_connection()
    
    # Performance validation
    test_performance_requirements()
    
    # Final summary
    print_test_summary()
    
    # Exit code based on results
    critical_failed = any(
        not r["success"] and any(keyword in r["test"] for keyword in ["Kill Switch", "Emergency", "API Health"])
        for r in test_results
    )
    
    exit(1 if critical_failed else 0)

if __name__ == "__main__":
    main()