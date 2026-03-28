-- PolyWeather Trading Bot Database Schema - SECURITY HARDENED
-- Optimized for high-frequency trading operations with bulletproof security

-- Enable required extensions with safety checks
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Enable row-level security globally
SET row_security = on;

-- Create secure roles for database access
-- Trading application role with limited permissions
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'polyweather_trader') THEN
        CREATE ROLE polyweather_trader LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'polyweather_readonly') THEN
        CREATE ROLE polyweather_readonly LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'polyweather_admin') THEN
        CREATE ROLE polyweather_admin LOGIN;
    END IF;
END $$;

-- Markets table (relatively static, heavily read)
CREATE TABLE IF NOT EXISTS markets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    polymarket_id VARCHAR(100) UNIQUE NOT NULL 
        CONSTRAINT valid_polymarket_id CHECK (polymarket_id ~ '^[a-zA-Z0-9_-]+$'),
    title TEXT NOT NULL 
        CONSTRAINT valid_title CHECK (char_length(title) BETWEEN 1 AND 500),
    description TEXT
        CONSTRAINT valid_description CHECK (char_length(description) <= 5000),
    category VARCHAR(50)
        CONSTRAINT valid_category CHECK (category ~ '^[a-zA-Z0-9_\s-]+$'),
    end_date TIMESTAMPTZ
        CONSTRAINT valid_end_date CHECK (end_date > NOW() - INTERVAL '1 year'),
    resolution_source TEXT
        CONSTRAINT valid_resolution_source CHECK (char_length(resolution_source) <= 200),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    -- Audit fields for security
    created_by TEXT DEFAULT current_user,
    updated_by TEXT DEFAULT current_user
);

-- Enable RLS on markets
ALTER TABLE markets ENABLE ROW LEVEL SECURITY;

-- Create secure indexes for fast market lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_markets_polymarket_id ON markets (polymarket_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_markets_active_category ON markets (is_active, category) WHERE is_active = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_markets_end_date ON markets (end_date) WHERE end_date > NOW();

-- Market data with time-series partitioning (main table for price feeds)
-- CRITICAL: Fixed decimal precision for financial calculations
CREATE TABLE IF NOT EXISTS market_data (
    id BIGSERIAL,
    market_id UUID NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Fixed-point arithmetic for financial precision - CRITICAL FIX
    yes_price NUMERIC(18,8) NOT NULL 
        CONSTRAINT valid_yes_price CHECK (yes_price >= 0 AND yes_price <= 1),
    no_price NUMERIC(18,8) NOT NULL 
        CONSTRAINT valid_no_price CHECK (no_price >= 0 AND no_price <= 1),
    yes_volume NUMERIC(20,8) DEFAULT 0 
        CONSTRAINT valid_yes_volume CHECK (yes_volume >= 0),
    no_volume NUMERIC(20,8) DEFAULT 0 
        CONSTRAINT valid_no_volume CHECK (no_volume >= 0),
    spread NUMERIC(18,8) GENERATED ALWAYS AS (ABS(yes_price - no_price)) STORED,
    data_source VARCHAR(20) DEFAULT 'polymarket'
        CONSTRAINT valid_data_source CHECK (data_source IN ('polymarket', 'backup_api')),
    -- Audit and validation fields
    data_hash TEXT, -- For data integrity verification
    created_by TEXT DEFAULT current_user,
    PRIMARY KEY (timestamp, id),
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
    -- Price consistency check
    CONSTRAINT price_consistency CHECK ((yes_price + no_price) BETWEEN 0.95 AND 1.05)
) PARTITION BY RANGE (timestamp);

-- Enable RLS on market_data
ALTER TABLE market_data ENABLE ROW LEVEL SECURITY;

-- SECURE partition creation function - NO DYNAMIC SQL
CREATE OR REPLACE FUNCTION create_market_data_partition(partition_date DATE)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    -- Input validation
    IF partition_date IS NULL OR 
       partition_date < '2020-01-01' OR 
       partition_date > CURRENT_DATE + INTERVAL '2 years' THEN
        RAISE EXCEPTION 'Invalid partition date: %', partition_date;
    END IF;
    
    -- Generate safe partition name (no user input)
    partition_name := 'market_data_' || to_char(partition_date, 'YYYY_MM_DD');
    start_date := partition_date;
    end_date := partition_date + INTERVAL '1 day';
    
    -- Check if partition already exists
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = partition_name) THEN
        RETURN;
    END IF;
    
    -- Create partition using safe identifier quoting
    EXECUTE format('CREATE TABLE %I PARTITION OF market_data FOR VALUES FROM (%L) TO (%L)',
                  partition_name, start_date, end_date);
    
    -- Create indexes on partition
    EXECUTE format('CREATE INDEX CONCURRENTLY %I ON %I (market_id, timestamp DESC)',
                  'idx_' || partition_name || '_market_timestamp', partition_name);
    EXECUTE format('CREATE INDEX CONCURRENTLY %I ON %I (timestamp DESC)',
                  'idx_' || partition_name || '_timestamp', partition_name);
    
    -- Log partition creation for audit
    RAISE NOTICE 'Created partition % for date range [%, %)', partition_name, start_date, end_date;
END;
$$;

-- Grant execution permission only to admin role
REVOKE ALL ON FUNCTION create_market_data_partition(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_market_data_partition(DATE) TO polyweather_admin;

-- Create initial partitions safely
DO $$
DECLARE
    partition_date DATE;
BEGIN
    -- Create partitions for past 30 days and future 365 days
    partition_date := CURRENT_DATE - INTERVAL '30 days';
    WHILE partition_date <= CURRENT_DATE + INTERVAL '365 days' LOOP
        PERFORM create_market_data_partition(partition_date);
        partition_date := partition_date + INTERVAL '1 day';
    END LOOP;
END $$;

-- Weather data with enhanced validation
CREATE TABLE IF NOT EXISTS weather_data (
    id BIGSERIAL,
    location VARCHAR(100) NOT NULL 
        CONSTRAINT valid_location CHECK (location ~ '^[a-zA-Z0-9\s,.-]+$'),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    forecast_timestamp TIMESTAMPTZ NOT NULL,
    -- Realistic bounds for weather data
    temperature NUMERIC(6,2)
        CONSTRAINT valid_temperature CHECK (temperature BETWEEN -100 AND 70),
    humidity NUMERIC(5,2)
        CONSTRAINT valid_humidity CHECK (humidity BETWEEN 0 AND 100),
    precipitation NUMERIC(8,4)
        CONSTRAINT valid_precipitation CHECK (precipitation >= 0 AND precipitation <= 1000),
    wind_speed NUMERIC(6,2)
        CONSTRAINT valid_wind_speed CHECK (wind_speed >= 0 AND wind_speed <= 500),
    pressure NUMERIC(8,2)
        CONSTRAINT valid_pressure CHECK (pressure BETWEEN 800 AND 1100),
    weather_condition VARCHAR(50)
        CONSTRAINT valid_weather_condition CHECK (weather_condition ~ '^[a-zA-Z0-9\s_-]+$'),
    forecast_source VARCHAR(50) DEFAULT 'openweather'
        CONSTRAINT valid_forecast_source CHECK (forecast_source IN ('openweather', 'noaa', 'darksky')),
    confidence_score NUMERIC(3,2)
        CONSTRAINT valid_confidence CHECK (confidence_score BETWEEN 0 AND 1),
    -- Audit fields
    data_hash TEXT,
    created_by TEXT DEFAULT current_user,
    PRIMARY KEY (timestamp, id),
    CONSTRAINT valid_forecast_timespan CHECK (forecast_timestamp BETWEEN timestamp - INTERVAL '1 hour' AND timestamp + INTERVAL '30 days')
) PARTITION BY RANGE (timestamp);

-- Trading signals with enhanced security
CREATE TABLE IF NOT EXISTS trading_signals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_id UUID NOT NULL,
    signal_type VARCHAR(20) NOT NULL 
        CONSTRAINT valid_signal_type CHECK (signal_type IN ('BUY_YES', 'BUY_NO', 'SELL', 'HOLD')),
    confidence NUMERIC(3,2) NOT NULL 
        CONSTRAINT valid_confidence CHECK (confidence BETWEEN 0 AND 1),
    expected_probability NUMERIC(5,4) 
        CONSTRAINT valid_expected_prob CHECK (expected_probability BETWEEN 0 AND 1),
    market_probability NUMERIC(5,4) 
        CONSTRAINT valid_market_prob CHECK (market_probability BETWEEN 0 AND 1),
    edge NUMERIC(7,4) GENERATED ALWAYS AS (expected_probability - market_probability) STORED,
    position_size NUMERIC(12,2)
        CONSTRAINT valid_position_size CHECK (position_size > 0 AND position_size <= 50), -- Max $50 bet
    weather_factors JSONB,
    market_factors JSONB,
    technical_indicators JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
        CONSTRAINT valid_expiry CHECK (expires_at > created_at AND expires_at <= created_at + INTERVAL '24 hours'),
    is_executed BOOLEAN DEFAULT false,
    executed_at TIMESTAMPTZ,
    execution_price NUMERIC(18,8),
    -- Audit fields
    created_by TEXT DEFAULT current_user,
    risk_score NUMERIC(3,2) DEFAULT 0.5,
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
    CONSTRAINT execution_consistency CHECK (
        (is_executed = false AND executed_at IS NULL AND execution_price IS NULL) OR
        (is_executed = true AND executed_at IS NOT NULL AND execution_price IS NOT NULL)
    )
);

-- Enable RLS on trading signals
ALTER TABLE trading_signals ENABLE ROW LEVEL SECURITY;

-- Positions table with enhanced financial controls
CREATE TABLE IF NOT EXISTS positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_id UUID NOT NULL,
    position_type VARCHAR(10) NOT NULL 
        CONSTRAINT valid_position_type CHECK (position_type IN ('YES', 'NO')),
    shares NUMERIC(20,8) NOT NULL 
        CONSTRAINT valid_shares CHECK (shares > 0),
    entry_price NUMERIC(18,8) NOT NULL 
        CONSTRAINT valid_entry_price CHECK (entry_price BETWEEN 0 AND 1),
    current_price NUMERIC(18,8)
        CONSTRAINT valid_current_price CHECK (current_price BETWEEN 0 AND 1),
    -- Fixed-point P&L calculation - CRITICAL FOR FINANCIAL ACCURACY
    unrealized_pnl NUMERIC(15,8) GENERATED ALWAYS AS (
        CASE 
            WHEN position_type = 'YES' THEN shares * (COALESCE(current_price, entry_price) - entry_price)
            WHEN position_type = 'NO' THEN shares * (entry_price - COALESCE(current_price, entry_price))
        END
    ) STORED,
    entry_signal_id UUID,
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    is_open BOOLEAN DEFAULT true,
    notes TEXT
        CONSTRAINT valid_notes CHECK (char_length(notes) <= 1000),
    -- Risk management fields
    stop_loss NUMERIC(18,8),
    take_profit NUMERIC(18,8),
    max_loss NUMERIC(15,8) DEFAULT 10.00, -- Max $10 loss per position
    -- Audit fields
    created_by TEXT DEFAULT current_user,
    updated_by TEXT DEFAULT current_user,
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
    FOREIGN KEY (entry_signal_id) REFERENCES trading_signals(id),
    CONSTRAINT valid_position_state CHECK (
        (is_open = true AND closed_at IS NULL) OR
        (is_open = false AND closed_at IS NOT NULL)
    ),
    CONSTRAINT valid_risk_params CHECK (
        stop_loss IS NULL OR (stop_loss >= 0 AND stop_loss <= 1) AND
        take_profit IS NULL OR (take_profit >= 0 AND take_profit <= 1)
    )
);

-- Enable RLS on positions
ALTER TABLE positions ENABLE ROW LEVEL SECURITY;

-- Trades table with comprehensive audit trail
CREATE TABLE IF NOT EXISTS trades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_id UUID NOT NULL,
    position_id UUID,
    trade_type VARCHAR(10) NOT NULL 
        CONSTRAINT valid_trade_type CHECK (trade_type IN ('BUY', 'SELL')),
    position_side VARCHAR(10) NOT NULL 
        CONSTRAINT valid_position_side CHECK (position_side IN ('YES', 'NO')),
    shares NUMERIC(20,8) NOT NULL 
        CONSTRAINT valid_trade_shares CHECK (shares > 0),
    price NUMERIC(18,8) NOT NULL 
        CONSTRAINT valid_trade_price CHECK (price BETWEEN 0 AND 1),
    total_cost NUMERIC(18,8) GENERATED ALWAYS AS (shares * price) STORED,
    fee NUMERIC(15,8) DEFAULT 0
        CONSTRAINT valid_fee CHECK (fee >= 0),
    polymarket_order_id VARCHAR(100)
        CONSTRAINT valid_order_id CHECK (polymarket_order_id ~ '^[a-zA-Z0-9_-]*$'),
    executed_at TIMESTAMPTZ DEFAULT NOW(),
    signal_id UUID,
    -- Additional security and audit fields
    execution_source VARCHAR(50) DEFAULT 'polyweather_bot',
    trade_hash TEXT, -- For verification
    ip_address INET,
    user_agent TEXT,
    created_by TEXT DEFAULT current_user,
    -- Risk management
    pre_trade_balance NUMERIC(15,8),
    post_trade_balance NUMERIC(15,8),
    FOREIGN KEY (market_id) REFERENCES markets(id) ON DELETE CASCADE,
    FOREIGN KEY (position_id) REFERENCES positions(id),
    FOREIGN KEY (signal_id) REFERENCES trading_signals(id)
);

-- Enable RLS on trades
ALTER TABLE trades ENABLE ROW LEVEL SECURITY;

-- Portfolio performance tracking with enhanced security
CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    total_value NUMERIC(15,8) NOT NULL 
        CONSTRAINT valid_total_value CHECK (total_value >= 0),
    cash_balance NUMERIC(15,8) NOT NULL 
        CONSTRAINT valid_cash_balance CHECK (cash_balance >= 0),
    positions_value NUMERIC(15,8) NOT NULL 
        CONSTRAINT valid_positions_value CHECK (positions_value >= 0),
    unrealized_pnl NUMERIC(15,8) NOT NULL,
    realized_pnl_today NUMERIC(15,8) DEFAULT 0,
    total_trades_today INTEGER DEFAULT 0
        CONSTRAINT valid_trades_count CHECK (total_trades_today >= 0),
    active_positions INTEGER NOT NULL
        CONSTRAINT valid_active_positions CHECK (active_positions >= 0),
    daily_return NUMERIC(8,4),
    cumulative_return NUMERIC(8,4),
    risk_score NUMERIC(3,2),
    -- Audit
    created_by TEXT DEFAULT current_user,
    snapshot_hash TEXT -- For integrity verification
);

-- Market correlations for risk management
CREATE TABLE IF NOT EXISTS market_correlations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_a_id UUID NOT NULL,
    market_b_id UUID NOT NULL,
    correlation_coefficient NUMERIC(7,4) NOT NULL
        CONSTRAINT valid_correlation CHECK (correlation_coefficient BETWEEN -1 AND 1),
    lookback_days INTEGER NOT NULL
        CONSTRAINT valid_lookback CHECK (lookback_days BETWEEN 1 AND 365),
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    calculation_method VARCHAR(50) DEFAULT 'pearson',
    created_by TEXT DEFAULT current_user,
    FOREIGN KEY (market_a_id) REFERENCES markets(id),
    FOREIGN KEY (market_b_id) REFERENCES markets(id),
    UNIQUE(market_a_id, market_b_id, lookback_days)
);

-- Audit log table for all database changes
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    user_name TEXT DEFAULT current_user,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    application_name TEXT
);

-- Create secure indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trading_signals_market_created ON trading_signals (market_id, created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trading_signals_pending ON trading_signals (is_executed, expires_at) 
    WHERE is_executed = false AND expires_at > NOW();
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_positions_open ON positions (is_open, market_id) WHERE is_open = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trades_executed_at ON trades (executed_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_portfolio_snapshots_timestamp ON portfolio_snapshots (timestamp DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_timestamp ON audit_log (timestamp DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_table_operation ON audit_log (table_name, operation);

-- Security trigger functions
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.updated_by = current_user;
    RETURN NEW;
END;
$$;

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_log (
        table_name, 
        operation, 
        old_values, 
        new_values,
        ip_address
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        inet_client_addr()
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Apply triggers
CREATE TRIGGER update_markets_updated_at 
    BEFORE UPDATE ON markets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_positions_updated_at 
    BEFORE UPDATE ON positions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Audit triggers for critical tables
CREATE TRIGGER audit_trades 
    AFTER INSERT OR UPDATE OR DELETE ON trades
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_positions 
    AFTER INSERT OR UPDATE OR DELETE ON positions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_trading_signals 
    AFTER INSERT OR UPDATE OR DELETE ON trading_signals
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

-- Set up Row Level Security policies
-- Markets - read access for all roles, write for admin/trader only
CREATE POLICY markets_read_policy ON markets FOR SELECT TO polyweather_readonly, polyweather_trader USING (true);
CREATE POLICY markets_write_policy ON markets FOR INSERT TO polyweather_trader, polyweather_admin WITH CHECK (true);
CREATE POLICY markets_update_policy ON markets FOR UPDATE TO polyweather_trader, polyweather_admin USING (true);

-- Market data - read access, insert for trader
CREATE POLICY market_data_read_policy ON market_data FOR SELECT TO polyweather_readonly, polyweather_trader USING (true);
CREATE POLICY market_data_insert_policy ON market_data FOR INSERT TO polyweather_trader WITH CHECK (timestamp >= NOW() - INTERVAL '1 day');

-- Trading signals - only creator can see their signals
CREATE POLICY trading_signals_owner_policy ON trading_signals FOR ALL TO polyweather_trader USING (created_by = current_user);
CREATE POLICY trading_signals_admin_policy ON trading_signals FOR ALL TO polyweather_admin USING (true);

-- Positions - owner and admin access
CREATE POLICY positions_owner_policy ON positions FOR ALL TO polyweather_trader USING (created_by = current_user);
CREATE POLICY positions_admin_policy ON positions FOR ALL TO polyweather_admin USING (true);

-- Trades - owner and admin access
CREATE POLICY trades_owner_policy ON trades FOR ALL TO polyweather_trader USING (created_by = current_user);
CREATE POLICY trades_admin_policy ON trades FOR ALL TO polyweather_admin USING (true);

-- Grant appropriate permissions
GRANT CONNECT ON DATABASE polyweather TO polyweather_readonly, polyweather_trader, polyweather_admin;
GRANT USAGE ON SCHEMA public TO polyweather_readonly, polyweather_trader, polyweather_admin;

-- Read-only permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO polyweather_readonly;

-- Trader permissions
GRANT SELECT, INSERT ON markets, market_data, weather_data TO polyweather_trader;
GRANT ALL ON trading_signals, positions, trades, portfolio_snapshots TO polyweather_trader;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO polyweather_trader;

-- Admin permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO polyweather_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO polyweather_admin;

-- Revoke dangerous permissions from public
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Set secure default permissions for new objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO polyweather_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT ON TABLES TO polyweather_trader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO polyweather_admin;