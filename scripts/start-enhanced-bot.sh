#!/bin/bash

"""
Enhanced startup script for PolyWeather Trading Bot
Starts all services including Redis, monitoring, and the trading bot
"""

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🚀 Starting Enhanced PolyWeather Trading Bot"
echo "================================================"

# Check if running in virtual environment
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "⚠️  Activating virtual environment..."
    source venv/bin/activate
fi

# Function to check if service is running
check_service() {
    local service=$1
    local port=$2
    if nc -z localhost $port 2>/dev/null; then
        echo "✅ $service is running on port $port"
        return 0
    else
        echo "❌ $service is not running on port $port"
        return 1
    fi
}

# Function to start Redis if not running
start_redis() {
    echo "🔧 Checking Redis service..."
    if check_service "Redis" 6379; then
        echo "✅ Redis already running"
    else
        echo "🚀 Starting Redis server..."
        
        # Create Redis data directory
        mkdir -p "$PROJECT_DIR/redis/data"
        
        # Start Redis in background with custom config
        if command -v redis-server >/dev/null 2>&1; then
            redis-server "$PROJECT_DIR/redis/config/redis.conf" --daemonize yes
            sleep 2
            if check_service "Redis" 6379; then
                echo "✅ Redis started successfully"
            else
                echo "❌ Failed to start Redis"
                exit 1
            fi
        else
            echo "❌ Redis not installed. Installing..."
            sudo apt-get update && sudo apt-get install -y redis-server
            redis-server "$PROJECT_DIR/redis/config/redis.conf" --daemonize yes
            sleep 2
        fi
    fi
}

# Function to start monitoring
start_monitoring() {
    echo "📊 Starting Prometheus metrics server..."
    python -c "
import asyncio
from src.polyweather.utils.metrics import start_metrics_server
async def main():
    await start_metrics_server(port=8000)
    print('✅ Metrics server started on port 8000')
asyncio.run(main())
" &
    METRICS_PID=$!
    sleep 2
    if check_service "Metrics" 8000; then
        echo "✅ Metrics server running (PID: $METRICS_PID)"
    fi
}

# Function to test enhanced APIs
test_apis() {
    echo "🧪 Running enhanced API tests..."
    python scripts/test-enhanced-apis.py
    if [ $? -eq 0 ]; then
        echo "✅ All API tests passed"
        return 0
    else
        echo "⚠️  Some API tests failed (continuing anyway)"
        return 1
    fi
}

# Function to start WebSocket server
start_websocket() {
    echo "🔌 Starting WebSocket server..."
    python -c "
import asyncio
from src.polyweather.api.websocket_server import websocket_server
async def main():
    await websocket_server.start()
    print('✅ WebSocket server started on port 8765')
    try:
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        await websocket_server.stop()
asyncio.run(main())
" &
    WEBSOCKET_PID=$!
    sleep 2
    if check_service "WebSocket" 8765; then
        echo "✅ WebSocket server running (PID: $WEBSOCKET_PID)"
    fi
}

# Function to start the main bot
start_bot() {
    echo "🤖 Starting PolyWeather Trading Bot..."
    python -c "
import asyncio
import logging
from src.polyweather.main import main

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

async def run_bot():
    try:
        await main()
    except KeyboardInterrupt:
        print('Bot stopped by user')
    except Exception as e:
        print(f'Bot error: {e}')

asyncio.run(run_bot())
" &
    BOT_PID=$!
    echo "✅ Trading bot started (PID: $BOT_PID)"
}

# Function to show status
show_status() {
    echo ""
    echo "📊 Service Status:"
    echo "=================="
    check_service "Redis" 6379 || echo "⚠️  Redis may not be accessible"
    check_service "Metrics" 8000 || echo "⚠️  Metrics server may not be running"
    check_service "WebSocket" 8765 || echo "⚠️  WebSocket server may not be running"
    
    echo ""
    echo "🔗 Access URLs:"
    echo "==============="
    echo "📊 Metrics:    http://localhost:8000/metrics"
    echo "🔌 WebSocket:  ws://localhost:8765"
    echo "💾 Redis:      redis://localhost:6379"
    echo ""
}

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down services..."
    
    # Kill background processes
    [ ! -z "$BOT_PID" ] && kill $BOT_PID 2>/dev/null && echo "✅ Stopped trading bot"
    [ ! -z "$WEBSOCKET_PID" ] && kill $WEBSOCKET_PID 2>/dev/null && echo "✅ Stopped WebSocket server" 
    [ ! -z "$METRICS_PID" ] && kill $METRICS_PID 2>/dev/null && echo "✅ Stopped metrics server"
    
    echo "🧹 Cleanup complete"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    # Check dependencies
    echo "🔍 Checking dependencies..."
    python -c "
import sys
required = ['aiohttp', 'asyncpg', 'redis', 'psutil', 'prometheus_client']
missing = []
for pkg in required:
    try:
        __import__(pkg.replace('-', '_'))
    except ImportError:
        missing.append(pkg)

if missing:
    print(f'❌ Missing packages: {missing}')
    print('Run: pip install -r requirements.txt')
    sys.exit(1)
else:
    print('✅ All dependencies available')
"
    
    # Start services
    start_redis
    start_monitoring
    
    # Test APIs
    if test_apis; then
        echo "✅ API tests passed - starting full system"
    else
        echo "⚠️  API tests had issues - check configuration"
    fi
    
    # Start servers
    start_websocket
    start_bot
    
    # Show status
    show_status
    
    # Wait for user input to stop
    echo "🎯 PolyWeather Bot is running! Press Ctrl+C to stop."
    echo "📝 Logs will appear below..."
    echo ""
    
    # Follow bot logs
    wait $BOT_PID
}

# Check for command line arguments
case "${1:-}" in
    test)
        echo "🧪 Running tests only..."
        start_redis
        test_apis
        ;;
    monitor)
        echo "📊 Starting monitoring only..."
        start_redis
        start_monitoring
        show_status
        echo "Press Ctrl+C to stop monitoring..."
        wait $METRICS_PID
        ;;
    *)
        main
        ;;
esac