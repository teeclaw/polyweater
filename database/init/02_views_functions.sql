-- PolyWeather Trading Bot - Views and Functions
-- Optimized queries for high-frequency trading operations

-- Latest market prices view (heavily cached)
CREATE VIEW latest_market_prices AS
WITH latest_data AS (
    SELECT DISTINCT ON (market_id) 
        market_id,
        timestamp,
        yes_price,
        no_price,
        spread,
        yes_volume,
        no_volume
    FROM market_data 
    WHERE timestamp >= NOW() - INTERVAL '1 hour'
    ORDER BY market_id, timestamp DESC
)
SELECT 
    m.polymarket_id,
    m.title,
    l.timestamp as last_updated,
    l.yes_price,
    l.no_price,
    l.spread,
    l.yes_volume + l.no_volume as total_volume,
    CASE 
        WHEN l.yes_price > 0.5 THEN 'YES_FAVORED'
        WHEN l.no_price > 0.5 THEN 'NO_FAVORED'
        ELSE 'BALANCED'
    END as market_sentiment
FROM markets m
JOIN latest_data l ON m.id = l.market_id
WHERE m.is_active = true;

-- Active positions with current P&L
CREATE VIEW active_positions_summary AS
SELECT 
    p.id,
    m.polymarket_id,
    m.title,
    p.position_type,
    p.shares,
    p.entry_price,
    lmp.yes_price,
    lmp.no_price,
    CASE 
        WHEN p.position_type = 'YES' THEN lmp.yes_price
        ELSE lmp.no_price
    END as current_price,
    CASE 
        WHEN p.position_type = 'YES' THEN p.shares * (lmp.yes_price - p.entry_price)
        ELSE p.shares * (p.entry_price - lmp.no_price)
    END as unrealized_pnl,
    CASE 
        WHEN p.position_type = 'YES' THEN (lmp.yes_price - p.entry_price) / p.entry_price
        ELSE (p.entry_price - lmp.no_price) / p.entry_price
    END as return_pct,
    p.opened_at,
    EXTRACT(EPOCH FROM (NOW() - p.opened_at))/3600 as hours_held
FROM positions p
JOIN markets m ON p.market_id = m.id
JOIN latest_market_prices lmp ON m.polymarket_id = lmp.polymarket_id
WHERE p.is_open = true;

-- Trading signals with market context
CREATE VIEW enriched_trading_signals AS
SELECT 
    ts.id,
    m.polymarket_id,
    m.title,
    ts.signal_type,
    ts.confidence,
    ts.expected_probability,
    ts.market_probability,
    ts.edge,
    lmp.yes_price as current_yes_price,
    lmp.no_price as current_no_price,
    ts.weather_factors,
    ts.market_factors,
    ts.created_at,
    ts.expires_at,
    EXTRACT(EPOCH FROM (ts.expires_at - NOW()))/60 as minutes_remaining
FROM trading_signals ts
JOIN markets m ON ts.market_id = m.id
JOIN latest_market_prices lmp ON m.polymarket_id = lmp.polymarket_id
WHERE ts.is_executed = false 
  AND ts.expires_at > NOW()
  AND ts.edge > 0.02  -- Only signals with >2% edge
ORDER BY ts.edge DESC, ts.confidence DESC;

-- Portfolio performance summary
CREATE VIEW portfolio_performance AS
WITH daily_stats AS (
    SELECT 
        DATE(executed_at) as trade_date,
        COUNT(*) as trades_count,
        SUM(CASE WHEN trade_type = 'BUY' THEN total_cost + fee ELSE -(total_cost - fee) END) as net_cash_flow,
        AVG(price) as avg_trade_price
    FROM trades
    WHERE executed_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(executed_at)
),
position_stats AS (
    SELECT 
        COUNT(*) as active_positions,
        SUM(unrealized_pnl) as total_unrealized_pnl,
        AVG(return_pct) as avg_position_return
    FROM active_positions_summary
)
SELECT 
    ps.active_positions,
    ps.total_unrealized_pnl,
    ps.avg_position_return,
    COUNT(ds.trades_count) as trading_days_last_30,
    COALESCE(SUM(ds.trades_count), 0) as total_trades_last_30,
    COALESCE(AVG(ds.trades_count), 0) as avg_trades_per_day,
    COALESCE(SUM(ds.net_cash_flow), 0) as net_cash_flow_last_30
FROM position_stats ps
CROSS JOIN daily_stats ds;

-- Function to get market price history for technical analysis
CREATE OR REPLACE FUNCTION get_market_price_history(
    p_polymarket_id VARCHAR,
    p_hours_back INTEGER DEFAULT 24
)
RETURNS TABLE (
    timestamp TIMESTAMPTZ,
    yes_price DECIMAL,
    no_price DECIMAL,
    spread DECIMAL,
    volume DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        md.timestamp,
        md.yes_price,
        md.no_price,
        md.spread,
        (md.yes_volume + md.no_volume) as volume
    FROM market_data md
    JOIN markets m ON md.market_id = m.id
    WHERE m.polymarket_id = p_polymarket_id
      AND md.timestamp >= NOW() - (p_hours_back || ' hours')::INTERVAL
    ORDER BY md.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate position sizing based on Kelly criterion
CREATE OR REPLACE FUNCTION calculate_kelly_position_size(
    p_edge DECIMAL,
    p_confidence DECIMAL,
    p_current_balance DECIMAL,
    p_max_risk_pct DECIMAL DEFAULT 0.02
)
RETURNS DECIMAL AS $$
DECLARE
    kelly_fraction DECIMAL;
    position_size DECIMAL;
    max_risk_amount DECIMAL;
BEGIN
    -- Kelly fraction = (edge * confidence) / (1 - confidence)
    -- But cap at max_risk_pct of balance for safety
    
    IF p_confidence <= 0 OR p_confidence >= 1 OR p_edge <= 0 THEN
        RETURN 0;
    END IF;
    
    kelly_fraction := (p_edge * p_confidence) / (1 - p_confidence);
    max_risk_amount := p_current_balance * p_max_risk_pct;
    
    position_size := LEAST(p_current_balance * kelly_fraction, max_risk_amount);
    
    -- Ensure position size is positive and reasonable
    position_size := GREATEST(position_size, 0);
    position_size := LEAST(position_size, p_current_balance * 0.1); -- Never more than 10%
    
    RETURN position_size;
END;
$$ LANGUAGE plpgsql;

-- Function to get correlated markets for risk management
CREATE OR REPLACE FUNCTION get_correlated_markets(
    p_market_id UUID,
    p_min_correlation DECIMAL DEFAULT 0.5
)
RETURNS TABLE (
    correlated_market_id UUID,
    polymarket_id VARCHAR,
    title TEXT,
    correlation_coefficient DECIMAL,
    active_position_exists BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mc.market_b_id as correlated_market_id,
        m.polymarket_id,
        m.title,
        mc.correlation_coefficient,
        EXISTS(
            SELECT 1 FROM positions p 
            WHERE p.market_id = mc.market_b_id 
              AND p.is_open = true
        ) as active_position_exists
    FROM market_correlations mc
    JOIN markets m ON mc.market_b_id = m.id
    WHERE mc.market_a_id = p_market_id
      AND ABS(mc.correlation_coefficient) >= p_min_correlation
      AND mc.calculated_at >= NOW() - INTERVAL '7 days'
    
    UNION ALL
    
    SELECT 
        mc.market_a_id as correlated_market_id,
        m.polymarket_id,
        m.title,
        mc.correlation_coefficient,
        EXISTS(
            SELECT 1 FROM positions p 
            WHERE p.market_id = mc.market_a_id 
              AND p.is_open = true
        ) as active_position_exists
    FROM market_correlations mc
    JOIN markets m ON mc.market_a_id = m.id
    WHERE mc.market_b_id = p_market_id
      AND ABS(mc.correlation_coefficient) >= p_min_correlation
      AND mc.calculated_at >= NOW() - INTERVAL '7 days'
    
    ORDER BY ABS(correlation_coefficient) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function for portfolio risk metrics
CREATE OR REPLACE FUNCTION calculate_portfolio_risk()
RETURNS TABLE (
    total_exposure DECIMAL,
    max_single_position DECIMAL,
    position_concentration_risk DECIMAL,
    correlated_positions_count INTEGER,
    diversification_score DECIMAL
) AS $$
DECLARE
    total_port_value DECIMAL;
    max_position DECIMAL;
BEGIN
    -- Calculate basic portfolio metrics
    SELECT 
        SUM(ABS(unrealized_pnl)) as total_exp,
        MAX(ABS(unrealized_pnl)) as max_pos
    INTO total_port_value, max_position
    FROM active_positions_summary;
    
    RETURN QUERY
    SELECT 
        COALESCE(total_port_value, 0) as total_exposure,
        COALESCE(max_position, 0) as max_single_position,
        CASE 
            WHEN total_port_value > 0 THEN max_position / total_port_value
            ELSE 0
        END as position_concentration_risk,
        (SELECT COUNT(*)::INTEGER 
         FROM active_positions_summary aps1
         WHERE EXISTS (
             SELECT 1 FROM get_correlated_markets(
                 (SELECT id FROM markets WHERE polymarket_id = aps1.polymarket_id), 
                 0.5
             ) gcm
             WHERE gcm.active_position_exists = true
         )) as correlated_positions_count,
        CASE 
            WHEN total_port_value > 0 THEN 
                1.0 - (max_position / total_port_value)
            ELSE 1.0
        END as diversification_score;
END;
$$ LANGUAGE plpgsql;