-- Performance tuning and maintenance for PolyWeather trading bot

-- Create function to manage partition lifecycle
CREATE OR REPLACE FUNCTION manage_time_series_partitions()
RETURNS TEXT AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
    result_message TEXT := '';
BEGIN
    -- Create future partitions for market_data (daily partitions for next 30 days)
    FOR i IN 1..30 LOOP
        start_date := CURRENT_DATE + (i || ' days')::INTERVAL;
        partition_name := 'market_data_' || to_char(start_date, 'YYYY_MM_DD');
        
        -- Check if partition exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = partition_name
        ) THEN
            EXECUTE format('CREATE TABLE %I PARTITION OF market_data FOR VALUES FROM (%L) TO (%L)',
                          partition_name, start_date, start_date + INTERVAL '1 day');
            
            -- Create indexes
            EXECUTE format('CREATE INDEX idx_%I_market_timestamp ON %I (market_id, timestamp DESC)',
                          partition_name, partition_name);
            EXECUTE format('CREATE INDEX idx_%I_timestamp ON %I (timestamp DESC)',
                          partition_name, partition_name);
            
            result_message := result_message || 'Created partition: ' || partition_name || E'\n';
        END IF;
    END LOOP;
    
    -- Clean up old partitions (older than 90 days)
    FOR partition_name IN
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public' 
          AND tablename LIKE 'market_data_%'
          AND tablename < 'market_data_' || to_char(CURRENT_DATE - INTERVAL '90 days', 'YYYY_MM_DD')
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || partition_name || ' CASCADE';
        result_message := result_message || 'Dropped old partition: ' || partition_name || E'\n';
    END LOOP;
    
    RETURN result_message;
END;
$$ LANGUAGE plpgsql;

-- Create function for database maintenance
CREATE OR REPLACE FUNCTION perform_maintenance()
RETURNS TEXT AS $$
DECLARE
    result_message TEXT := '';
BEGIN
    -- Update table statistics for query planner
    ANALYZE markets;
    ANALYZE trading_signals;
    ANALYZE positions;
    ANALYZE trades;
    
    result_message := result_message || 'Updated table statistics' || E'\n';
    
    -- Clean up old trading signals (older than 7 days)
    DELETE FROM trading_signals 
    WHERE created_at < NOW() - INTERVAL '7 days'
      AND is_executed = false;
    
    result_message := result_message || 'Cleaned up expired trading signals' || E'\n';
    
    -- Clean up old portfolio snapshots (keep only last 90 days of hourly data)
    DELETE FROM portfolio_snapshots 
    WHERE timestamp < NOW() - INTERVAL '90 days';
    
    result_message := result_message || 'Cleaned up old portfolio snapshots' || E'\n';
    
    -- Reindex critical tables if needed
    REINDEX INDEX CONCURRENTLY idx_trading_signals_pending;
    REINDEX INDEX CONCURRENTLY idx_positions_open;
    
    result_message := result_message || 'Reindexed critical indexes' || E'\n';
    
    RETURN result_message;
END;
$$ LANGUAGE plpgsql;

-- Create materialized view for frequently accessed market summary
CREATE MATERIALIZED VIEW market_summary_mv AS
SELECT 
    m.id,
    m.polymarket_id,
    m.title,
    m.category,
    m.end_date,
    COALESCE(latest.yes_price, 0.5) as current_yes_price,
    COALESCE(latest.no_price, 0.5) as current_no_price,
    COALESCE(latest.spread, 0) as current_spread,
    COALESCE(vol.total_volume_24h, 0) as volume_24h,
    COALESCE(vol.price_change_24h, 0) as price_change_24h,
    COALESCE(signals.active_signals, 0) as active_signals_count,
    CASE 
        WHEN positions.position_count > 0 THEN true
        ELSE false
    END as has_active_positions,
    NOW() as last_updated
FROM markets m
LEFT JOIN LATERAL (
    SELECT yes_price, no_price, spread, timestamp
    FROM market_data md
    WHERE md.market_id = m.id
      AND md.timestamp >= NOW() - INTERVAL '1 hour'
    ORDER BY timestamp DESC
    LIMIT 1
) latest ON true
LEFT JOIN LATERAL (
    SELECT 
        SUM(yes_volume + no_volume) as total_volume_24h,
        (LAST(yes_price ORDER BY timestamp) - FIRST(yes_price ORDER BY timestamp)) as price_change_24h
    FROM market_data md
    WHERE md.market_id = m.id
      AND md.timestamp >= NOW() - INTERVAL '24 hours'
) vol ON true
LEFT JOIN LATERAL (
    SELECT COUNT(*) as active_signals
    FROM trading_signals ts
    WHERE ts.market_id = m.id
      AND ts.is_executed = false
      AND ts.expires_at > NOW()
) signals ON true
LEFT JOIN LATERAL (
    SELECT COUNT(*) as position_count
    FROM positions p
    WHERE p.market_id = m.id
      AND p.is_open = true
) positions ON true
WHERE m.is_active = true;

-- Create unique index for materialized view
CREATE UNIQUE INDEX idx_market_summary_mv_id ON market_summary_mv (id);
CREATE INDEX idx_market_summary_mv_category ON market_summary_mv (category);
CREATE INDEX idx_market_summary_mv_volume ON market_summary_mv (volume_24h DESC);
CREATE INDEX idx_market_summary_mv_signals ON market_summary_mv (active_signals_count DESC);

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_market_summary()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY market_summary_mv;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for faster weather data queries
CREATE INDEX CONCURRENTLY idx_weather_data_location_forecast_time 
ON weather_data (location, forecast_timestamp, timestamp DESC);

CREATE INDEX CONCURRENTLY idx_weather_data_condition_confidence 
ON weather_data (weather_condition, confidence_score DESC) 
WHERE confidence_score > 0.7;

-- Function to calculate market volatility
CREATE OR REPLACE FUNCTION calculate_market_volatility(
    p_market_id UUID,
    p_hours_back INTEGER DEFAULT 24
)
RETURNS DECIMAL AS $$
DECLARE
    volatility DECIMAL;
BEGIN
    SELECT STDDEV(yes_price) INTO volatility
    FROM market_data
    WHERE market_id = p_market_id
      AND timestamp >= NOW() - (p_hours_back || ' hours')::INTERVAL;
    
    RETURN COALESCE(volatility, 0);
END;
$$ LANGUAGE plpgsql;

-- Performance monitoring function
CREATE OR REPLACE FUNCTION get_performance_metrics()
RETURNS TABLE (
    metric_name TEXT,
    metric_value NUMERIC,
    unit TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Active Connections'::TEXT, 
           COUNT(*)::NUMERIC, 
           'connections'::TEXT
    FROM pg_stat_activity 
    WHERE state = 'active'
    
    UNION ALL
    
    SELECT 'Slow Queries (>1s)'::TEXT,
           COUNT(*)::NUMERIC,
           'queries'::TEXT
    FROM pg_stat_statements
    WHERE mean_exec_time > 1000
    
    UNION ALL
    
    SELECT 'Cache Hit Ratio'::TEXT,
           ROUND((sum(heap_blks_hit) * 100.0 / 
                  NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0))::NUMERIC, 2),
           'percent'::TEXT
    FROM pg_statio_user_tables
    
    UNION ALL
    
    SELECT 'Market Data Points Today'::TEXT,
           COUNT(*)::NUMERIC,
           'records'::TEXT
    FROM market_data
    WHERE timestamp >= CURRENT_DATE
    
    UNION ALL
    
    SELECT 'Active Trading Signals'::TEXT,
           COUNT(*)::NUMERIC,
           'signals'::TEXT
    FROM trading_signals
    WHERE is_executed = false AND expires_at > NOW();
END;
$$ LANGUAGE plpgsql;