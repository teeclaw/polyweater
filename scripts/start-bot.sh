#!/bin/bash

# PolyWeather Trading Bot Startup Script
# Phase 1.2 - API Integrations

set -e  # Exit on any error

echo "🚀 Starting PolyWeather Trading Bot v1.2.0"
echo "=================================================="

# Check if running in Docker
if [ -f /.dockerenv ]; then
    echo "📦 Running in Docker container"
    LOG_DIR="/app/logs"
    DATA_DIR="/app/data"
    SCRIPT_DIR="/app/scripts"
else
    echo "💻 Running locally"
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    LOG_DIR="$BASE_DIR/logs"
    DATA_DIR="$BASE_DIR/data"
    SCRIPT_DIR="$BASE_DIR/scripts"
fi

# Create necessary directories
mkdir -p "$LOG_DIR" "$DATA_DIR"

# Function to check if a service is healthy
check_service() {
    local service_name=$1
    local check_cmd=$2
    local max_attempts=30
    local attempt=0

    echo "🔍 Checking $service_name..."
    
    while [ $attempt -lt $max_attempts ]; do
        if eval "$check_cmd" >/dev/null 2>&1; then
            echo "✅ $service_name is ready"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo "⏳ Waiting for $service_name... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    echo "❌ $service_name failed to start after $max_attempts attempts"
    return 1
}

# Check database connectivity
if [ -n "$DATABASE_URL" ]; then
    echo "🔍 Checking database connectivity..."
    check_service "PostgreSQL" "python -c \"
import asyncio
import asyncpg
import os
async def test_db():
    try:
        conn = await asyncpg.connect(os.environ['DATABASE_URL'])
        await conn.execute('SELECT 1')
        await conn.close()
        return True
    except:
        return False
asyncio.run(test_db())
\""
fi

# Check Redis connectivity  
if [ -n "$REDIS_URL" ]; then
    echo "🔍 Checking Redis connectivity..."
    check_service "Redis" "python -c \"
import redis
import os
try:
    r = redis.from_url(os.environ['REDIS_URL'])
    r.ping()
except:
    exit(1)
\""
fi

# Validate API keys (warn if missing)
echo "🔑 Validating API configuration..."

missing_keys=()
if [ -z "$POLYMARKET_API_KEY" ]; then missing_keys+=("POLYMARKET_API_KEY"); fi
if [ -z "$OPENWEATHER_API_KEY" ]; then missing_keys+=("OPENWEATHER_API_KEY"); fi
if [ -z "$POLYCLAW_PRIVATE_KEY" ]; then missing_keys+=("POLYCLAW_PRIVATE_KEY"); fi

if [ ${#missing_keys[@]} -gt 0 ]; then
    if [ "$ENVIRONMENT" = "production" ]; then
        echo "❌ Missing required API keys in production: ${missing_keys[*]}"
        exit 1
    else
        echo "⚠️  Missing API keys (development mode): ${missing_keys[*]}"
        echo "⚠️  Some features may be limited"
    fi
fi

# Check available balance/capital
if [ -n "$STARTING_CAPITAL" ]; then
    echo "💰 Starting capital: $STARTING_CAPITAL USD"
    echo "📊 Max position size: ${MAX_POSITION_SIZE:-10.0} USD"
    echo "📈 Daily trade limit: ${DAILY_TRADE_LIMIT:-3} trades"
fi

# Set Python path
export PYTHONPATH="${PYTHONPATH}:/app/src"

# Start the bot with proper logging
echo "🎯 Starting trading bot..."
echo "📊 Metrics server: http://localhost:${PROMETHEUS_PORT:-8000}/metrics"
echo "🔌 WebSocket server: ws://localhost:${WEBSOCKET_PORT:-8765}"
echo "📝 Logs: $LOG_DIR/polyweather.log"

# Run with output to both console and log file
python /app/src/polyweather/main.py 2>&1 | tee -a "$LOG_DIR/startup-$(date +%Y%m%d-%H%M%S).log"