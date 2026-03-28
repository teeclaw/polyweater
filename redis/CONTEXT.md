# redis/ - Cache & Session Management

## PURPOSE  
Redis configuration for high-performance caching, session storage, and real-time data management.

## CONFIGURATION
- `config/redis.conf` - Optimized Redis configuration for trading applications

## CACHE STRATEGY
### Data Types & TTL
```redis
market_data:*        → 60 seconds   (Real-time market prices)
weather_forecast:*   → 300 seconds  (5-minute weather updates)
api_responses:*      → 180 seconds  (3-minute API cache)
user_sessions:*      → 3600 seconds (1-hour dashboard sessions)
```

### Performance Optimization
- **Memory Policy**: `allkeys-lru` for automatic eviction
- **Max Memory**: 256MB allocated for cache operations
- **Persistence**: AOF disabled for cache-only operation
- **Connection Pool**: 20 max connections

## KEY-VALUE PATTERNS
```
Session Management:
session:trader:{token} → {user_id, permissions, timestamp}

Market Data Cache:
market:{market_id}:price → {current_price, timestamp, volume}
market:{market_id}:history → [price_array_last_24h]

Weather Data Cache:  
weather:{location}:current → {temp, humidity, pressure, conditions}
weather:{location}:forecast → {forecast_array_next_7_days}

Trading State:
trading:positions:active → {position_array}
trading:pnl:daily → {daily_pnl_value}
```

## RELATIONS
- **Caches for**: Backend API responses and database queries
- **Sessions for**: Streamlit dashboard authentication
- **Real-time data**: WebSocket message queuing
- **Integrates with**: PostgreSQL for persistent storage backup

## MONITORING
- **Memory Usage**: Tracked via Prometheus metrics
- **Hit Rate**: >90% target for frequently accessed data
- **Connection Count**: Monitored for connection pool optimization
- **Key Expiration**: Automatic cleanup of expired cache entries

**High-performance caching ensures sub-second dashboard response times**