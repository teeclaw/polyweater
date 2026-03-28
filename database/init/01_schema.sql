-- PolyWeather Trading Bot Database Schema
-- Optimized for high-frequency trading operations

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create dedicated tablespace for time-series data (optional, using default for now)
-- CREATE TABLESPACE ts_data LOCATION '/var/lib/postgresql/data/ts_data';

-- Markets table (relatively static, heavily read)
CREATE TABLE markets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    polymarket_id VARCHAR(100) UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category VARCHAR(50),
    end_date TIMESTAMPTZ,
    resolution_source TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Create index for fast market lookups
CREATE INDEX CONCURRENTLY idx_markets_polymarket_id ON markets (polymarket_id);
CREATE INDEX CONCURRENTLY idx_markets_active_category ON markets (is_active, category) WHERE is_active = true;
CREATE INDEX CONCURRENTLY idx_markets_end_date ON markets (end_date) WHERE end_date > NOW();

-- Market data with time-series partitioning (main table for price feeds)
CREATE TABLE market_data (
    id BIGSERIAL,
    market_id UUID NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    yes_price DECIMAL(10,8) NOT NULL,
    no_price DECIMAL(10,8) NOT NULL,
    yes_volume DECIMAL(15,2) DEFAULT 0,
    no_volume DECIMAL(15,2) DEFAULT 0,
    spread DECIMAL(10,8) GENERATED ALWAYS AS (ABS(yes_price - no_price)) STORED,
    data_source VARCHAR(20) DEFAULT 'polymarket',
    PRIMARY KEY (timestamp, id),
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE
) PARTITION BY RANGE (timestamp);

-- Create partitions for the next 12 months (daily partitions for recent data)
DO $$
DECLARE
    start_date DATE := CURRENT_DATE - INTERVAL '30 days';
    end_date DATE := CURRENT_DATE + INTERVAL '365 days';
    partition_date DATE;
    partition_name TEXT;
BEGIN
    partition_date := start_date;
    WHILE partition_date <= end_date LOOP
        partition_name := 'market_data_' || to_char(partition_date, 'YYYY_MM_DD');
        EXECUTE format('CREATE TABLE %I PARTITION OF market_data FOR VALUES FROM (%L) TO (%L)',
                      partition_name,
                      partition_date,
                      partition_date + INTERVAL '1 day');
        
        -- Create indexes on each partition
        EXECUTE format('CREATE INDEX CONCURRENTLY idx_%I_market_timestamp ON %I (market_id, timestamp DESC)',
                      partition_name, partition_name);
        EXECUTE format('CREATE INDEX CONCURRENTLY idx_%I_timestamp ON %I (timestamp DESC)',
                      partition_name, partition_name);
        
        partition_date := partition_date + INTERVAL '1 day';
    END LOOP;
END $$;

-- Weather data with time-series partitioning
CREATE TABLE weather_data (
    id BIGSERIAL,
    location VARCHAR(100) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    forecast_timestamp TIMESTAMPTZ NOT NULL, -- When this forecast is for
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    precipitation DECIMAL(8,2),
    wind_speed DECIMAL(6,2),
    pressure DECIMAL(8,2),
    weather_condition VARCHAR(50),
    forecast_source VARCHAR(50) DEFAULT 'openweather',
    confidence_score DECIMAL(3,2), -- 0-1 confidence in forecast
    PRIMARY KEY (timestamp, id)
) PARTITION BY RANGE (timestamp);

-- Create weather data partitions (weekly partitions)
DO $$
DECLARE
    start_date DATE := CURRENT_DATE - INTERVAL '30 days';
    end_date DATE := CURRENT_DATE + INTERVAL '365 days';
    partition_date DATE;
    partition_name TEXT;
BEGIN
    partition_date := date_trunc('week', start_date)::DATE;
    WHILE partition_date <= end_date LOOP
        partition_name := 'weather_data_' || to_char(partition_date, 'YYYY_MM_DD');
        EXECUTE format('CREATE TABLE %I PARTITION OF weather_data FOR VALUES FROM (%L) TO (%L)',
                      partition_name,
                      partition_date,
                      partition_date + INTERVAL '1 week');
        
        -- Create indexes on each partition
        EXECUTE format('CREATE INDEX CONCURRENTLY idx_%I_location_forecast ON %I (location, forecast_timestamp)',
                      partition_name, partition_name);
        EXECUTE format('CREATE INDEX CONCURRENTLY idx_%I_timestamp ON %I (timestamp DESC)',
                      partition_name, partition_name);
        
        partition_date := partition_date + INTERVAL '1 week';
    END LOOP;
END $$;

-- Trading signals table (non-partitioned, recent data only)
CREATE TABLE trading_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_id UUID NOT NULL,
    signal_type VARCHAR(20) NOT NULL, -- 'BUY_YES', 'BUY_NO', 'SELL', 'HOLD'
    confidence DECIMAL(3,2) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    expected_probability DECIMAL(3,2) CHECK (expected_probability >= 0 AND expected_probability <= 1),
    market_probability DECIMAL(3,2) CHECK (market_probability >= 0 AND market_probability <= 1),
    edge DECIMAL(5,4) GENERATED ALWAYS AS (expected_probability - market_probability) STORED,
    weather_factors JSONB,
    market_factors JSONB,
    technical_indicators JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_executed BOOLEAN DEFAULT false,
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE
);

-- Indexes for trading signals
CREATE INDEX CONCURRENTLY idx_trading_signals_market_created ON trading_signals (market_id, created_at DESC);
CREATE INDEX CONCURRENTLY idx_trading_signals_pending ON trading_signals (is_executed, expires_at) 
    WHERE is_executed = false AND expires_at > NOW();
CREATE INDEX CONCURRENTLY idx_trading_signals_confidence ON trading_signals (confidence DESC) 
    WHERE is_executed = false;
CREATE INDEX CONCURRENTLY idx_trading_signals_edge ON trading_signals (edge DESC) 
    WHERE is_executed = false AND edge > 0;

-- Positions table (active trading positions)
CREATE TABLE positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_id UUID NOT NULL,
    position_type VARCHAR(10) NOT NULL, -- 'YES', 'NO'
    shares DECIMAL(15,8) NOT NULL,
    entry_price DECIMAL(10,8) NOT NULL,
    current_price DECIMAL(10,8),
    unrealized_pnl DECIMAL(10,2) GENERATED ALWAYS AS (
        CASE 
            WHEN position_type = 'YES' THEN shares * (COALESCE(current_price, entry_price) - entry_price)
            WHEN position_type = 'NO' THEN shares * (entry_price - COALESCE(current_price, entry_price))
        END
    ) STORED,
    entry_signal_id UUID,
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    is_open BOOLEAN DEFAULT true,
    notes TEXT,
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
    FOREIGN KEY (entry_signal_id) REFERENCES trading_signals(id)
);

-- Indexes for positions
CREATE INDEX CONCURRENTLY idx_positions_open ON positions (is_open, market_id) WHERE is_open = true;
CREATE INDEX CONCURRENTLY idx_positions_market_opened ON positions (market_id, opened_at DESC);
CREATE INDEX CONCURRENTLY idx_positions_pnl ON positions (unrealized_pnl DESC) WHERE is_open = true;

-- Trades table (completed transactions)
CREATE TABLE trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_id UUID NOT NULL,
    position_id UUID,
    trade_type VARCHAR(10) NOT NULL, -- 'BUY', 'SELL'
    position_side VARCHAR(10) NOT NULL, -- 'YES', 'NO'
    shares DECIMAL(15,8) NOT NULL,
    price DECIMAL(10,8) NOT NULL,
    total_cost DECIMAL(10,2) GENERATED ALWAYS AS (shares * price) STORED,
    fee DECIMAL(10,2) DEFAULT 0,
    polymarket_order_id VARCHAR(100),
    executed_at TIMESTAMPTZ DEFAULT NOW(),
    signal_id UUID,
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
    FOREIGN KEY (position_id) REFERENCES positions(id),
    FOREIGN KEY (signal_id) REFERENCES trading_signals(id)
);

-- Indexes for trades
CREATE INDEX CONCURRENTLY idx_trades_executed_at ON trades (executed_at DESC);
CREATE INDEX CONCURRENTLY idx_trades_market_executed ON trades (market_id, executed_at DESC);
CREATE INDEX CONCURRENTLY idx_trades_position ON trades (position_id);
CREATE INDEX CONCURRENTLY idx_trades_polymarket_order ON trades (polymarket_order_id);

-- Portfolio performance tracking
CREATE TABLE portfolio_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    total_value DECIMAL(12,2) NOT NULL,
    cash_balance DECIMAL(12,2) NOT NULL,
    positions_value DECIMAL(12,2) NOT NULL,
    unrealized_pnl DECIMAL(10,2) NOT NULL,
    realized_pnl_today DECIMAL(10,2) DEFAULT 0,
    total_trades_today INTEGER DEFAULT 0,
    active_positions INTEGER NOT NULL,
    daily_return DECIMAL(8,4),
    cumulative_return DECIMAL(8,4)
);

CREATE INDEX CONCURRENTLY idx_portfolio_snapshots_timestamp ON portfolio_snapshots (timestamp DESC);

-- Market correlations for risk management
CREATE TABLE market_correlations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_a_id UUID NOT NULL,
    market_b_id UUID NOT NULL,
    correlation_coefficient DECIMAL(5,4) NOT NULL,
    lookback_days INTEGER NOT NULL,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (market_a_id) REFERENCES markets(id),
    FOREIGN KEY (market_b_id) REFERENCES markets(id),
    UNIQUE(market_a_id, market_b_id, lookback_days)
);

CREATE INDEX CONCURRENTLY idx_correlations_markets ON market_correlations (market_a_id, market_b_id);
CREATE INDEX CONCURRENTLY idx_correlations_coefficient ON market_correlations (ABS(correlation_coefficient) DESC);

-- Trigger to update market updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_markets_updated_at BEFORE UPDATE ON markets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();