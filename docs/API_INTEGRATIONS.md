# PolyWeather Bot API Integrations - Phase 1.2

## Overview

Phase 1.2 implements comprehensive API integrations for the PolyWeather trading bot, including weather data pipeline, Polymarket market data, PolyClaw trading interface, and real-time WebSocket streams.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Weather APIs  │    │ Polymarket API  │    │ PolyClaw API    │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │    NOAA     │ │    │ │   Markets   │ │    │ │   Trading   │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │OpenWeather  │ │    │ │ WebSockets  │ │    │ │   Wallet    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
              ┌─────────────────────────────────┐
              │      PolyWeather Bot            │
              │                                 │
              │ ┌─────────────────────────────┐ │
              │ │    Weather Data Pipeline    │ │
              │ │    (Consensus Building)     │ │
              │ └─────────────────────────────┘ │
              │ ┌─────────────────────────────┐ │
              │ │     Trading Engine          │ │
              │ └─────────────────────────────┘ │
              │ ┌─────────────────────────────┐ │
              │ │   WebSocket Server          │ │
              │ └─────────────────────────────┘ │
              └─────────────────────────────────┘
                                 │
              ┌─────────────────────────────────┐
              │     Infrastructure Layer        │
              │                                 │
              │ PostgreSQL │ Redis │ Prometheus │
              └─────────────────────────────────┘
```

## API Integrations

### 1. Weather Data Pipeline

#### Components
- **NOAA Weather API**: Primary weather data source with high reliability
- **OpenWeatherMap API**: Secondary source for consensus building
- **Consensus Engine**: Combines multiple sources with confidence scoring

#### Key Features
- Multi-source weather data aggregation
- Confidence-weighted consensus building
- Standard deviation analysis for agreement measurement
- Rate limiting and error handling
- Automated location extraction from market descriptions

#### Usage
```python
from polyweather.api.weather import WeatherDataPipeline

pipeline = WeatherDataPipeline()
consensus_data = await pipeline.get_consensus_forecast(40.7128, -74.0060)

print(f"Temperature: {consensus_data.temperature}°C")
print(f"Precipitation: {consensus_data.precipitation_chance}%")
print(f"Confidence: {consensus_data.consensus_confidence}")
```

#### Configuration
```bash
NOAA_API_KEY=your_noaa_api_key
OPENWEATHER_API_KEY=your_openweather_api_key
WEATHER_API_RATE_LIMIT=1000  # requests per hour
```

### 2. Polymarket API Integration

#### Components
- **Market Discovery**: Find and filter weather-related prediction markets
- **Real-time Data**: WebSocket connections for live market updates
- **Order Book Access**: Deep market data for optimal trade execution

#### Key Features
- Automated weather market discovery using keyword matching
- Real-time price and order book updates via WebSocket
- Market filtering by liquidity, activity, and time to expiry
- Comprehensive market metadata extraction

#### Usage
```python
from polyweather.api.polymarket import PolymarketClient

client = PolymarketClient()

# Find weather markets
weather_markets = await client.search_weather_markets()

# Subscribe to real-time updates
await client.subscribe_market_updates(market_id, callback)
```

#### WebSocket Subscriptions
- Market price updates
- Order book changes
- Volume and liquidity updates
- Market resolution events

### 3. PolyClaw Trading Interface

#### Components
- **Wallet Management**: Secure private key handling and transaction signing
- **Order Execution**: Limit and market order placement
- **Portfolio Tracking**: Position monitoring and P&L calculation

#### Key Features
- Ethereum wallet integration with private key management
- Automated position sizing using Kelly criterion
- Risk management with position limits and daily trade limits
- Gas optimization and transaction monitoring

#### Usage
```python
from polyweather.api.polyclaw import PolyClawInterface

interface = PolyClawInterface()

# Check balance
balance = await interface.get_balance()

# Place order
execution = await interface.place_order(
    market_id="0x123...",
    outcome="yes",
    side="buy",
    price=Decimal("0.65"),
    size=Decimal("10.0")
)
```

#### Position Sizing Algorithm
```python
def calculate_position_size(confidence, balance):
    # Kelly fraction with conservative multiplier
    kelly_fraction = max(0.01, min(0.15, (confidence - 0.5) * 2))
    position_size = balance * kelly_fraction
    
    # Apply limits
    return min(max(position_size, MIN_SIZE), MAX_SIZE)
```

### 4. WebSocket Real-time Streaming

#### Server Features
- Multi-client connection handling
- Channel-based subscription system
- Real-time data broadcasting
- Connection health monitoring

#### Supported Channels
- `weather`: Weather forecast updates
- `markets`: General market updates
- `market:<market_id>`: Specific market updates
- `trades`: Trade execution notifications
- `portfolio`: Portfolio value updates

#### Client Connection
```javascript
const ws = new WebSocket('ws://localhost:8765');

// Subscribe to weather updates
ws.send(JSON.stringify({
    type: 'subscribe',
    channel: 'weather'
}));

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Update:', data);
};
```

## Error Handling & Recovery

### Rate Limiting
- Token bucket algorithm implementation
- Adaptive rate limiting based on API responses
- Automatic backoff on rate limit violations

### Fault Tolerance
- Exponential backoff for API failures
- Circuit breaker pattern for persistent failures
- Graceful degradation with single data sources
- WebSocket auto-reconnection with jitter

### Monitoring & Metrics
- Prometheus metrics for all API calls
- Success/failure rate tracking
- Response time monitoring
- Connection health indicators

## Security & Configuration

### API Key Management
```bash
# Required for production
POLYMARKET_API_KEY=your_polymarket_api_key
POLYCLAW_PRIVATE_KEY=your_wallet_private_key  # Secure storage recommended

# Optional for development
NOAA_API_KEY=your_noaa_api_key
OPENWEATHER_API_KEY=your_openweather_api_key
```

### Rate Limits
```bash
WEATHER_API_RATE_LIMIT=1000        # requests per hour
POLYMARKET_API_RATE_LIMIT=100      # requests per minute
WEBSOCKET_MAX_RETRIES=10
WEBSOCKET_RECONNECT_DELAY=5.0
```

### Trading Configuration
```bash
STARTING_CAPITAL=50.00
MAX_POSITION_SIZE=10.00
MIN_POSITION_SIZE=1.00
DAILY_TRADE_LIMIT=3
```

## Testing

### API Integration Tests
```bash
cd /path/to/polyweather-bot
python scripts/test-apis.py
```

### Test Coverage
- Configuration validation
- Weather API connectivity
- Polymarket market discovery
- PolyClaw wallet access
- WebSocket connections
- Error handling mechanisms

### Expected Test Results
```
🧪 Starting PolyWeather API Integration Tests
==============================================================

🔍 Testing Configuration...
   ✅ PASS

🔍 Testing Weather APIs...
   ✅ PASS

🔍 Testing Polymarket API...
   ✅ PASS

🔍 Testing PolyClaw Interface...
   ⚠️  PASS (with warnings)

🔍 Testing WebSocket Connections...
   ✅ PASS

🔍 Testing Error Handling...
   ✅ PASS

==============================================================
🧪 TEST SUMMARY
==============================================================
Total Tests: 6
✅ Passed: 6
❌ Failed: 0
⚠️  Errors: 0
📊 Success Rate: 100.0%

🎉 ALL TESTS PASSED - Bot ready for deployment!
```

## Performance Characteristics

### Latency Targets
- Weather API calls: < 2 seconds
- Polymarket API calls: < 500ms
- Trade execution: < 1 second
- WebSocket message delivery: < 100ms

### Throughput Limits
- Weather updates: 1 per 15 minutes
- Market monitoring: Real-time via WebSocket
- Trade execution: Max 3 per day
- Portfolio updates: 1 per 5 minutes

### Resource Usage
- Memory: ~100MB baseline
- CPU: < 5% average utilization
- Network: ~1MB/hour normal operation
- Database connections: 5-10 concurrent

## Deployment

### Docker Deployment
```bash
cd polyweather-bot
docker-compose up -d polyweather-bot
```

### Manual Deployment
```bash
cd polyweather-bot

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your API keys

# Start the bot
./scripts/start-bot.sh
```

### Health Checks
- HTTP endpoint: `http://localhost:8000/metrics`
- WebSocket endpoint: `ws://localhost:8765`
- Database connectivity: Auto-verified on startup
- API key validation: Checked during initialization

## Monitoring

### Prometheus Metrics
- API call counts and success rates
- Weather consensus accuracy
- Trading operation metrics
- WebSocket connection status
- Portfolio performance indicators

### Key Metrics to Monitor
```
polyweather_weather_api_calls_total
polyweather_trading_operations_total
polyweather_portfolio_value_usd
polyweather_websocket_connections
polyweather_consensus_confidence
```

### Alerting Thresholds
- API failure rate > 10%
- WebSocket disconnections > 5/hour
- Portfolio loss > 10%
- Daily trade limit reached

## Future Enhancements

### Phase 1.3 Planning
- Additional weather data sources (AccuWeather, Weather Underground)
- Machine learning models for weather prediction accuracy
- Advanced trading strategies (mean reversion, momentum)
- Risk management improvements (VaR, stop-losses)
- Mobile app for monitoring and manual intervention

### Scalability Considerations
- Horizontal scaling of WebSocket servers
- Database sharding for time-series data
- Caching layer for frequently accessed data
- Load balancing for high-availability deployment

## Support & Troubleshooting

### Common Issues
1. **Missing API keys**: Check .env configuration
2. **Database connection**: Verify PostgreSQL is running
3. **Network timeouts**: Check firewall and proxy settings
4. **Rate limit errors**: Reduce request frequency in config

### Debug Mode
```bash
export LOG_LEVEL=DEBUG
python src/polyweather/main.py
```

### Logs Location
- Docker: `/app/logs/polyweather.log`
- Local: `./logs/polyweather.log`
- Startup logs: `./logs/startup-YYYYMMDD-HHMMSS.log`

---

**Note**: This implementation provides a robust foundation for automated weather-based trading on Polymarket. All components include comprehensive error handling, monitoring, and testing to ensure production reliability with the $50 starting capital constraint.