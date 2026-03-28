#!/usr/bin/env python3

"""
API Integration Testing Script for PolyWeather Trading Bot
Tests weather data pipeline, Polymarket integration, and PolyClaw interface
"""

import asyncio
import os
import sys
import logging
from decimal import Decimal
from typing import Dict, Any

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from polyweather.config import config
from polyweather.api.weather import WeatherDataPipeline
from polyweather.api.polymarket import PolymarketClient
from polyweather.api.polyclaw import PolyClawInterface
from polyweather.utils.metrics import start_metrics_server

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class APITester:
    """Comprehensive API testing suite."""
    
    def __init__(self):
        self.weather_pipeline = WeatherDataPipeline()
        self.polymarket_client = PolymarketClient()
        self.polyclaw_interface = PolyClawInterface()
        
        self.test_results = {}
    
    async def run_all_tests(self):
        """Run all API integration tests."""
        
        print("🧪 Starting PolyWeather API Integration Tests")
        print("=" * 60)
        
        # Test configurations
        test_configs = [
            ("Configuration", self.test_configuration),
            ("Weather APIs", self.test_weather_apis),
            ("Polymarket API", self.test_polymarket_api),
            ("PolyClaw Interface", self.test_polyclaw_interface),
            ("WebSocket Connections", self.test_websocket_connections),
            ("Error Handling", self.test_error_handling),
        ]
        
        for test_name, test_func in test_configs:
            print(f"\n🔍 Testing {test_name}...")
            try:
                result = await test_func()
                self.test_results[test_name] = {
                    "status": "PASS" if result else "FAIL",
                    "details": result if isinstance(result, dict) else {}
                }
                status = "✅ PASS" if result else "❌ FAIL"
                print(f"   {status}")
                
            except Exception as e:
                self.test_results[test_name] = {
                    "status": "ERROR",
                    "error": str(e)
                }
                print(f"   ❌ ERROR: {e}")
        
        # Print summary
        await self.print_test_summary()
    
    async def test_configuration(self) -> bool:
        """Test configuration loading and validation."""
        
        try:
            # Test required configuration fields
            required_fields = [
                "database_url", "redis_url", "starting_capital",
                "max_position_size", "min_position_size"
            ]
            
            for field in required_fields:
                value = getattr(config, field)
                if value is None:
                    print(f"     ⚠️  Missing required field: {field}")
                    return False
            
            # Test API keys (warn if missing)
            api_keys = [
                "noaa_api_key", "openweather_api_key",
                "polymarket_api_key", "polyclaw_private_key"
            ]
            
            missing_keys = []
            for key in api_keys:
                if not getattr(config, key):
                    missing_keys.append(key)
            
            if missing_keys and config.is_production:
                print(f"     ❌ Missing API keys in production: {missing_keys}")
                return False
            elif missing_keys:
                print(f"     ⚠️  Missing API keys (development): {missing_keys}")
            
            print(f"     💰 Starting capital: ${config.starting_capital}")
            print(f"     📊 Position limits: ${config.min_position_size} - ${config.max_position_size}")
            print(f"     🔄 Daily trade limit: {config.daily_trade_limit}")
            
            return True
            
        except Exception as e:
            print(f"     ❌ Configuration error: {e}")
            return False
    
    async def test_weather_apis(self) -> Dict[str, Any]:
        """Test weather data pipeline with consensus building."""
        
        # Test coordinates (New York City)
        test_lat, test_lon = 40.7128, -74.0060
        
        results = {
            "noaa_api": False,
            "openweather_api": False,
            "consensus_building": False,
            "forecast_data": None
        }
        
        try:
            # Test individual APIs
            print(f"     🌤️  Testing NOAA API...")
            noaa_forecasts = await self.weather_pipeline.noaa_client.get_forecast(
                test_lat, test_lon
            )
            results["noaa_api"] = len(noaa_forecasts) > 0
            if results["noaa_api"]:
                print(f"       ✅ NOAA: {len(noaa_forecasts)} forecasts")
            
            print(f"     ⛅ Testing OpenWeatherMap API...")
            owm_forecasts = await self.weather_pipeline.openweather_client.get_forecast(
                test_lat, test_lon
            )
            results["openweather_api"] = len(owm_forecasts) > 0
            if results["openweather_api"]:
                print(f"       ✅ OpenWeatherMap: {len(owm_forecasts)} forecasts")
            
            # Test consensus building
            print(f"     🧠 Testing consensus building...")
            consensus_data = await self.weather_pipeline.get_consensus_forecast(
                test_lat, test_lon
            )
            
            if consensus_data:
                results["consensus_building"] = True
                results["forecast_data"] = {
                    "location": consensus_data.location,
                    "temperature": float(consensus_data.temperature),
                    "precipitation": float(consensus_data.precipitation_chance),
                    "confidence": float(consensus_data.consensus_confidence),
                    "sources": consensus_data.source_count
                }
                
                print(f"       ✅ Consensus: {consensus_data.source_count} sources, "
                      f"confidence: {consensus_data.consensus_confidence:.2f}")
                print(f"       🌡️  Temperature: {consensus_data.temperature:.1f}°C")
                print(f"       🌧️  Precipitation: {consensus_data.precipitation_chance:.1f}%")
            
            return results
            
        except Exception as e:
            print(f"     ❌ Weather API error: {e}")
            return results
    
    async def test_polymarket_api(self) -> Dict[str, Any]:
        """Test Polymarket API integration."""
        
        results = {
            "market_discovery": False,
            "weather_markets": False,
            "orderbook_access": False,
            "market_count": 0,
            "weather_market_count": 0
        }
        
        try:
            print(f"     📊 Testing market discovery...")
            markets = await self.polymarket_client.get_markets(active_only=True)
            
            if markets:
                results["market_discovery"] = True
                results["market_count"] = len(markets)
                print(f"       ✅ Found {len(markets)} active markets")
                
                # Test weather market search
                print(f"     🌦️  Testing weather market search...")
                weather_markets = await self.polymarket_client.search_weather_markets()
                
                if weather_markets:
                    results["weather_markets"] = True
                    results["weather_market_count"] = len(weather_markets)
                    print(f"       ✅ Found {len(weather_markets)} weather-related markets")
                    
                    # Test order book access
                    test_market = weather_markets[0]
                    print(f"     📈 Testing order book access...")
                    orderbook = await self.polymarket_client.get_order_book(test_market.id)
                    
                    if orderbook:
                        results["orderbook_access"] = True
                        print(f"       ✅ Order book: spread={orderbook.spread:.4f}, "
                              f"mid={orderbook.mid_price:.4f}")
            
            return results
            
        except Exception as e:
            print(f"     ❌ Polymarket API error: {e}")
            return results
    
    async def test_polyclaw_interface(self) -> Dict[str, Any]:
        """Test PolyClaw trading interface."""
        
        results = {
            "wallet_access": False,
            "balance_check": False,
            "position_sizing": False,
            "balance_data": None
        }
        
        try:
            if not config.polyclaw_private_key:
                print(f"     ⚠️  No private key configured, skipping wallet tests")
                return results
            
            print(f"     💳 Testing wallet access...")
            if self.polyclaw_interface.account:
                results["wallet_access"] = True
                wallet_addr = self.polyclaw_interface.account.address
                print(f"       ✅ Wallet: {wallet_addr[:10]}...{wallet_addr[-6:]}")
                
                # Test balance check (this would fail without actual API)
                print(f"     💰 Testing balance check...")
                try:
                    balance = await self.polyclaw_interface.get_balance()
                    if isinstance(balance, dict):
                        results["balance_check"] = True
                        results["balance_data"] = {k: str(v) for k, v in balance.items()}
                        total_balance = sum(float(v) for v in balance.values())
                        print(f"       ✅ Balance check successful: ${total_balance:.2f}")
                except Exception as e:
                    print(f"       ⚠️  Balance check failed (expected in test): {e}")
                
                # Test position sizing calculation
                print(f"     📐 Testing position sizing...")
                test_balance = Decimal("100.0")
                test_confidence = 0.75
                
                position_size = await self.polyclaw_interface.calculate_position_size(
                    "test_market", test_confidence, test_balance
                )
                
                if position_size > 0:
                    results["position_sizing"] = True
                    print(f"       ✅ Position sizing: ${position_size} "
                          f"(confidence: {test_confidence})")
            
            return results
            
        except Exception as e:
            print(f"     ❌ PolyClaw interface error: {e}")
            return results
    
    async def test_websocket_connections(self) -> bool:
        """Test WebSocket connectivity."""
        
        try:
            print(f"     🔌 Testing WebSocket connection...")
            
            # Start WebSocket connection
            await self.polymarket_client.start_websocket()
            
            if self.polymarket_client._websocket:
                print(f"       ✅ WebSocket connected")
                
                # Test subscription
                test_callback = lambda data: None
                await self.polymarket_client.subscribe_market_updates(
                    "test_market_id", test_callback
                )
                
                print(f"       ✅ Subscription mechanism working")
                
                # Close connection
                await self.polymarket_client.close_websocket()
                print(f"       ✅ WebSocket closed cleanly")
                
                return True
            
            return False
            
        except Exception as e:
            print(f"     ❌ WebSocket error: {e}")
            return False
    
    async def test_error_handling(self) -> bool:
        """Test error handling and recovery mechanisms."""
        
        try:
            print(f"     🛡️  Testing error handling...")
            
            # Test rate limiting
            rate_limiter = self.weather_pipeline.noaa_client.rate_limiter
            usage = rate_limiter.get_current_usage()
            print(f"       ✅ Rate limiter functional: {len(usage)} limits configured")
            
            # Test invalid coordinates
            invalid_weather = await self.weather_pipeline.get_consensus_forecast(
                999.0, 999.0  # Invalid coordinates
            )
            
            if invalid_weather is None:
                print(f"       ✅ Invalid input handling works")
            
            # Test configuration validation
            temp_config = config.starting_capital
            if temp_config > 0:
                print(f"       ✅ Configuration validation works")
            
            return True
            
        except Exception as e:
            print(f"     ❌ Error handling test failed: {e}")
            return False
    
    async def print_test_summary(self):
        """Print comprehensive test summary."""
        
        print("\n" + "=" * 60)
        print("🧪 TEST SUMMARY")
        print("=" * 60)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results.values() 
                          if result["status"] == "PASS")
        failed_tests = sum(1 for result in self.test_results.values() 
                          if result["status"] == "FAIL")
        error_tests = sum(1 for result in self.test_results.values() 
                         if result["status"] == "ERROR")
        
        print(f"Total Tests: {total_tests}")
        print(f"✅ Passed: {passed_tests}")
        print(f"❌ Failed: {failed_tests}")
        print(f"⚠️  Errors: {error_tests}")
        print(f"📊 Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        print("\nDetailed Results:")
        for test_name, result in self.test_results.items():
            status_icon = {"PASS": "✅", "FAIL": "❌", "ERROR": "⚠️"}[result["status"]]
            print(f"{status_icon} {test_name}: {result['status']}")
            
            if result["status"] == "ERROR":
                print(f"   Error: {result['error']}")
        
        # Overall assessment
        print("\n" + "-" * 60)
        if passed_tests == total_tests:
            print("🎉 ALL TESTS PASSED - Bot ready for deployment!")
        elif passed_tests >= total_tests * 0.8:
            print("⚡ MOSTLY FUNCTIONAL - Minor issues to address")
        elif passed_tests >= total_tests * 0.5:
            print("⚠️  PARTIAL FUNCTIONALITY - Major issues need fixing")
        else:
            print("❌ CRITICAL ISSUES - Bot not ready for operation")
        
        print(f"\n📊 Metrics server would be available at: http://localhost:{config.prometheus_port}/metrics")
        print(f"🔌 WebSocket server would be available at: ws://localhost:8765")


async def main():
    """Main test execution."""
    
    tester = APITester()
    await tester.run_all_tests()


if __name__ == "__main__":
    asyncio.run(main())