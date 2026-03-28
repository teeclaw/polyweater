#!/usr/bin/env python3
"""
Phase 1.3 Core Trading Engine Test Script
Validates all major components are properly integrated and functional.
"""

import asyncio
import sys
import os
from decimal import Decimal
from datetime import datetime

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from polyweather.config_phase13 import phase13_config
from polyweather.trading.signal_engine import WeatherSignalEngine, TradingSignal
from polyweather.trading.risk_manager import RiskManager, RiskLimits
from polyweather.trading.position_tracker import PositionTracker
from polyweather.trading.execution_engine import ExecutionEngine, ExecutionStrategy


class MockWeatherData:
    """Mock weather data for testing."""
    def __init__(self):
        self.temperature = Decimal("72.5")
        self.temperature_std = 2.1
        self.precipitation_chance = 25.0
        self.precipitation_std = 15.0
        self.wind_speed = 8.5
        self.consensus_confidence = 0.82


class MockMarket:
    """Mock market for testing."""
    def __init__(self):
        self.id = "test_market_123"
        self.question = "Will the temperature in New York be above 70 degrees on Friday?"
        self.description = "Temperature prediction market for NYC"
        self.end_date = datetime.now()
        self.active = True
        self.closed = False
        self.liquidity = Decimal("500")


class MockWeatherPipeline:
    """Mock weather pipeline for testing."""
    async def get_consensus_forecast(self, lat, lon, forecast_hours=48):
        return MockWeatherData()


class MockPolyClawInterface:
    """Mock PolyClaw interface for testing."""
    async def get_balance(self):
        return {"USDC": Decimal("48.50")}
    
    async def get_positions(self):
        return []
    
    async def place_order(self, **kwargs):
        class MockExecution:
            def __init__(self):
                self.order_id = "test_order_456"
                self.market_id = kwargs.get("market_id", "test")
                self.outcome = kwargs.get("outcome", "yes")
                self.side = kwargs.get("side", "buy")
                self.price = kwargs.get("price", Decimal("0.65"))
                self.size = kwargs.get("size", Decimal("3.00"))
                self.fees = Decimal("0.03")
                self.success = True
                self.error_message = None
                self.timestamp = datetime.now()
        return MockExecution()
    
    async def get_order_status(self, order_id):
        class MockOrderStatus:
            def __init__(self):
                self.id = order_id
                self.market_id = "test_market_123"
                self.outcome = "yes"
                self.side = "buy"
                self.price = Decimal("0.65")
                self.size = Decimal("3.00")
                self.filled_size = Decimal("3.00")
                self.remaining_size = Decimal("0")
                self.status = "filled"
                self.created_at = datetime.now()
                self.updated_at = datetime.now()
        return MockOrderStatus()


class MockPolymarketClient:
    """Mock Polymarket client for testing."""
    async def get_order_book(self, market_id):
        class MockOrderBook:
            def __init__(self):
                self.market_id = market_id
                self.mid_price = Decimal("0.64")
                self.best_bid = Decimal("0.63")
                self.best_ask = Decimal("0.65")
                self.spread = Decimal("0.02")
        return MockOrderBook()
    
    async def get_market(self, market_id):
        return MockMarket()


async def test_phase13_configuration():
    """Test Phase 1.3 configuration."""
    print("🔧 Testing Phase 1.3 Configuration...")
    
    try:
        # Test configuration validation
        assert phase13_config.validate_configuration() == True
        
        # Test parameter access
        assert phase13_config.starting_capital == Decimal("50.00")
        assert phase13_config.min_signal_confidence == 0.65
        assert phase13_config.max_position_size == Decimal("5.00")
        assert phase13_config.min_position_size == Decimal("2.00")
        assert phase13_config.daily_trade_limit == 3
        
        # Test configuration dictionaries
        risk_limits = phase13_config.get_risk_limits()
        assert "max_daily_trades" in risk_limits
        assert "max_position_size" in risk_limits
        
        signal_params = phase13_config.get_signal_parameters()
        assert "min_confidence" in signal_params
        assert "min_edge" in signal_params
        
        print("✅ Phase 1.3 Configuration: PASSED")
        return True
        
    except Exception as e:
        print(f"❌ Phase 1.3 Configuration: FAILED - {e}")
        return False


async def test_signal_engine():
    """Test signal generation engine."""
    print("🎯 Testing Signal Generation Engine...")
    
    try:
        # Initialize components
        weather_pipeline = MockWeatherPipeline()
        signal_engine = WeatherSignalEngine(weather_pipeline)
        
        # Test signal generation
        market = MockMarket()
        weather_data = MockWeatherData()
        current_price = Decimal("0.64")
        
        signal = await signal_engine.generate_signal(market, weather_data, current_price)
        
        # Validate signal
        assert signal is not None
        assert isinstance(signal, TradingSignal)
        assert signal.market_id == market.id
        assert signal.final_confidence > 0
        assert signal.edge != 0
        assert signal.max_position_size > 0
        assert signal.weather_pattern in ["temperature", "precipitation", "wind", "extreme_weather"]
        
        print(f"✅ Signal Generated - Confidence: {signal.final_confidence:.3f}, Edge: {signal.edge:+.3f}")
        print("✅ Signal Generation Engine: PASSED")
        return True
        
    except Exception as e:
        print(f"❌ Signal Generation Engine: FAILED - {e}")
        return False


async def test_risk_manager():
    """Test risk management system."""
    print("🛡️  Testing Risk Management System...")
    
    try:
        # Initialize components
        polyclaw = MockPolyClawInterface()
        risk_manager = RiskManager(polyclaw)
        
        # Create test signal
        signal = TradingSignal(
            market_id="test_market_123",
            action="buy",
            outcome="yes",
            side="buy",
            base_confidence=0.75,
            weather_confidence=0.82,
            market_confidence=0.68,
            final_confidence=0.75,
            edge=0.08,
            kelly_fraction=0.12,
            max_position_size=Decimal("3.50"),
            weather_pattern="temperature",
            threshold_analysis={"forecast_value": 72.5, "threshold_value": 70.0},
            market_analysis={"confidence": 0.68},
            target_price=Decimal("0.65"),
            price_range=(Decimal("0.63"), Decimal("0.67")),
            time_horizon=datetime.now(),
            generated_at=datetime.now(),
            expiry_time=datetime.now(),
            reason="Test signal"
        )
        
        # Test trade evaluation
        current_balance = {"USDC": Decimal("48.50")}
        approval = await risk_manager.evaluate_trade(signal, current_balance)
        
        # Validate approval
        assert approval is not None
        assert approval.approved == True  # Should approve good signal
        assert approval.recommended_size > 0
        assert approval.recommended_size <= phase13_config.max_position_size
        assert approval.risk_score >= 0
        
        # Test position monitoring
        position_alerts = await risk_manager.monitor_positions()
        assert isinstance(position_alerts, list)
        
        # Test drawdown limits
        drawdown_ok = await risk_manager.check_drawdown_limits()
        assert drawdown_ok == True
        
        print(f"✅ Trade Approved - Size: ${approval.recommended_size:.2f}, Risk Score: {approval.risk_score:.3f}")
        print("✅ Risk Management System: PASSED")
        return True
        
    except Exception as e:
        print(f"❌ Risk Management System: FAILED - {e}")
        return False


async def test_position_tracker():
    """Test position tracking system."""
    print("📊 Testing Position Tracking System...")
    
    try:
        # Initialize components
        polyclaw = MockPolyClawInterface()
        polymarket = MockPolymarketClient()
        position_tracker = PositionTracker(polyclaw, polymarket)
        
        # Test position updates
        portfolio_summary = await position_tracker.update_positions()
        
        # Validate portfolio summary
        assert portfolio_summary is not None
        assert portfolio_summary.current_capital > 0
        assert portfolio_summary.starting_capital == Decimal("50.00")
        assert portfolio_summary.position_count >= 0
        assert portfolio_summary.last_updated is not None
        
        # Test analytics
        analytics = await position_tracker.get_portfolio_analytics()
        assert isinstance(analytics, dict)
        assert "portfolio_summary" in analytics
        assert "generated_at" in analytics
        
        print(f"✅ Portfolio Value: ${portfolio_summary.current_capital:.2f}")
        print(f"✅ P&L: {portfolio_summary.total_pnl_percent:+.2%}")
        print("✅ Position Tracking System: PASSED")
        return True
        
    except Exception as e:
        print(f"❌ Position Tracking System: FAILED - {e}")
        return False


async def test_execution_engine():
    """Test execution engine."""
    print("⚡ Testing Execution Engine...")
    
    try:
        # Initialize components
        polyclaw = MockPolyClawInterface()
        polymarket = MockPolymarketClient()
        risk_manager = RiskManager(polyclaw)
        position_tracker = PositionTracker(polyclaw, polymarket)
        execution_engine = ExecutionEngine(polyclaw, polymarket, risk_manager, position_tracker)
        
        # Create test signal
        signal = TradingSignal(
            market_id="test_market_123",
            action="buy",
            outcome="yes",
            side="buy",
            base_confidence=0.75,
            weather_confidence=0.82,
            market_confidence=0.68,
            final_confidence=0.75,
            edge=0.08,
            kelly_fraction=0.12,
            max_position_size=Decimal("3.50"),
            weather_pattern="temperature",
            threshold_analysis={"forecast_value": 72.5, "threshold_value": 70.0},
            market_analysis={"confidence": 0.68},
            target_price=Decimal("0.65"),
            price_range=(Decimal("0.63"), Decimal("0.67")),
            time_horizon=datetime.now(),
            generated_at=datetime.now(),
            expiry_time=datetime.now(),
            reason="Test signal"
        )
        
        # Test trade execution
        execution_result = await execution_engine.execute_trade(signal, ExecutionStrategy.CONSERVATIVE)
        
        # Validate execution
        assert execution_result is not None
        assert execution_result.success == True
        assert execution_result.total_filled > 0
        assert execution_result.avg_fill_price > 0
        assert execution_result.execution_time >= 0
        assert execution_result.completion_status in ["complete", "partial", "failed", "rejected"]
        
        # Test order monitoring
        order_alerts = await execution_engine.monitor_active_orders()
        assert isinstance(order_alerts, list)
        
        # Test analytics
        analytics = await execution_engine.get_execution_analytics()
        assert isinstance(analytics, dict)
        
        print(f"✅ Execution Successful - Filled: {execution_result.total_filled} @ ${execution_result.avg_fill_price:.3f}")
        print(f"✅ Execution Time: {execution_result.execution_time:.2f}s")
        print("✅ Execution Engine: PASSED")
        return True
        
    except Exception as e:
        print(f"❌ Execution Engine: FAILED - {e}")
        return False


async def test_integration():
    """Test complete integration of all components."""
    print("🔗 Testing Complete Integration...")
    
    try:
        # Initialize all components
        weather_pipeline = MockWeatherPipeline()
        polyclaw = MockPolyClawInterface()
        polymarket = MockPolymarketClient()
        
        signal_engine = WeatherSignalEngine(weather_pipeline)
        risk_manager = RiskManager(polyclaw)
        position_tracker = PositionTracker(polyclaw, polymarket)
        execution_engine = ExecutionEngine(polyclaw, polymarket, risk_manager, position_tracker)
        
        # Simulate complete trading cycle
        market = MockMarket()
        weather_data = MockWeatherData()
        current_price = Decimal("0.64")
        
        # 1. Generate signal
        signal = await signal_engine.generate_signal(market, weather_data, current_price)
        assert signal is not None
        
        # 2. Risk approval
        current_balance = {"USDC": Decimal("48.50")}
        approval = await risk_manager.evaluate_trade(signal, current_balance)
        assert approval.approved == True
        
        # 3. Execute trade
        execution_result = await execution_engine.execute_trade(signal, ExecutionStrategy.CONSERVATIVE)
        assert execution_result.success == True
        
        # 4. Update positions
        portfolio_summary = await position_tracker.update_positions()
        assert portfolio_summary is not None
        
        print("✅ Complete Trading Cycle: Signal → Risk Check → Execution → Tracking")
        print("✅ Integration Test: PASSED")
        return True
        
    except Exception as e:
        print(f"❌ Integration Test: FAILED - {e}")
        return False


async def main():
    """Run all Phase 1.3 tests."""
    print("🚀 PolyWeather Phase 1.3 Core Trading Engine Test Suite")
    print("=" * 60)
    
    tests = [
        ("Configuration", test_phase13_configuration),
        ("Signal Engine", test_signal_engine),
        ("Risk Manager", test_risk_manager),
        ("Position Tracker", test_position_tracker),
        ("Execution Engine", test_execution_engine),
        ("Integration", test_integration),
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        print()
        try:
            result = await test_func()
            results[test_name] = result
        except Exception as e:
            print(f"❌ {test_name}: FAILED with exception - {e}")
            results[test_name] = False
    
    print()
    print("=" * 60)
    print("📋 Test Results Summary:")
    
    passed = 0
    total = len(tests)
    
    for test_name, result in results.items():
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"   {test_name:<20}: {status}")
        if result:
            passed += 1
    
    print()
    print(f"🎯 Overall Results: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        print("🎉 All Phase 1.3 components are working correctly!")
        print("🚀 Ready for production deployment with $50 starting capital")
        print("💰 Target: 1-3 trades/day, 15-25% monthly returns, 15% max drawdown")
    else:
        print("⚠️  Some components need attention before deployment")
        return 1
    
    return 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)