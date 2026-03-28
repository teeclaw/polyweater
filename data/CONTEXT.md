# data/ - Trading Data & Cache Storage

## PURPOSE
Local data storage for trading operations, market data cache, and historical analysis.

## TYPICAL CONTENTS
- `market_data/` - Polymarket historical data and real-time snapshots
- `weather_data/` - Weather API responses and forecast cache
- `trading_logs/` - Trade execution history and P&L records
- `cache/` - Temporary data storage for API responses
- `backups/` - Database dumps and configuration backups

## DATA FLOW
```
Weather APIs → data/weather_data/ → Bot Analysis
Polymarket API → data/market_data/ → Trading Decisions
Trading Execution → data/trading_logs/ → P&L Tracking
```

## RELATIONS
- **Feeds into**: PostgreSQL database via ETL scripts
- **Sources from**: Weather APIs, Polymarket API, PolyClaw
- **Accessed by**: Backend API services and analytics
- **Backed up to**: Remote storage and database

## CACHING STRATEGY
- **Weather data**: 5-minute TTL for forecast updates
- **Market data**: Real-time via WebSocket, 1-minute cache fallback
- **Trading logs**: Immediate write, daily aggregation

## SECURITY NOTES
- Contains sensitive trading data - ensure proper file permissions
- Regularly cleaned via maintenance scripts in `/scripts/maintenance.sh`