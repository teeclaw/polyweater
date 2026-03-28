#!/bin/bash

# PolyWeather Trading Bot with Control API Startup Script
# Phase 2.2: Comprehensive Trading Controls

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PATH="$PROJECT_ROOT/venv"
LOG_DIR="$PROJECT_ROOT/logs"
PID_DIR="$PROJECT_ROOT/run"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create necessary directories
mkdir -p "$LOG_DIR" "$PID_DIR"

# Check if virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    error "Virtual environment not found at $VENV_PATH"
    exit 1
fi

# Activate virtual environment
log "Activating virtual environment..."
source "$VENV_PATH/bin/activate"

# Check if Redis is running (required for caching)
if ! pgrep redis-server > /dev/null; then
    warning "Redis server not running. Starting Redis..."
    if command -v redis-server > /dev/null; then
        redis-server --daemonize yes --logfile "$LOG_DIR/redis.log"
        sleep 2
        if pgrep redis-server > /dev/null; then
            success "Redis started successfully"
        else
            error "Failed to start Redis"
            exit 1
        fi
    else
        error "Redis server not installed. Please install Redis."
        exit 1
    fi
else
    log "Redis is already running"
fi

# Function to start Control API
start_control_api() {
    log "Starting Control API server..."
    cd "$PROJECT_ROOT"
    
    python -m src.polyweather.api.control_server > "$LOG_DIR/control_api.log" 2>&1 &
    CONTROL_API_PID=$!
    echo $CONTROL_API_PID > "$PID_DIR/control_api.pid"
    
    # Wait a moment and check if it started
    sleep 3
    if ps -p $CONTROL_API_PID > /dev/null; then
        success "Control API started successfully (PID: $CONTROL_API_PID)"
        log "API available at: http://localhost:8080"
        log "WebSocket endpoint: ws://localhost:8080/api/v1/ws"
    else
        error "Failed to start Control API"
        return 1
    fi
}

# Function to start WebSocket server
start_websocket_server() {
    log "Starting WebSocket server..."
    cd "$PROJECT_ROOT"
    
    python -c "
import asyncio
from src.polyweather.api.websocket_server import websocket_server

async def run():
    await websocket_server.start()
    await asyncio.Future()  # Run forever

if __name__ == '__main__':
    asyncio.run(run())
" > "$LOG_DIR/websocket_server.log" 2>&1 &
    
    WEBSOCKET_PID=$!
    echo $WEBSOCKET_PID > "$PID_DIR/websocket.pid"
    
    sleep 3
    if ps -p $WEBSOCKET_PID > /dev/null; then
        success "WebSocket server started successfully (PID: $WEBSOCKET_PID)"
        log "WebSocket available at: ws://localhost:8765"
    else
        error "Failed to start WebSocket server"
        return 1
    fi
}

# Function to start dashboard
start_dashboard() {
    log "Starting React dashboard..."
    cd "$PROJECT_ROOT/dashboard"
    
    if [ ! -d "node_modules" ]; then
        log "Installing dashboard dependencies..."
        npm install
    fi
    
    # Set environment variables for API integration
    export REACT_APP_API_URL="http://localhost:8080"
    export REACT_APP_WS_URL="ws://localhost:8765"
    
    npm start > "$LOG_DIR/dashboard.log" 2>&1 &
    DASHBOARD_PID=$!
    echo $DASHBOARD_PID > "$PID_DIR/dashboard.pid"
    
    sleep 5
    if ps -p $DASHBOARD_PID > /dev/null; then
        success "Dashboard started successfully (PID: $DASHBOARD_PID)"
        log "Dashboard available at: http://localhost:3000"
    else
        error "Failed to start dashboard"
        return 1
    fi
}

# Function to check health endpoints
check_health() {
    log "Performing health checks..."
    
    # Check Control API
    for i in {1..10}; do
        if curl -s http://localhost:8080/health > /dev/null; then
            success "Control API health check passed"
            break
        else
            if [ $i -eq 10 ]; then
                warning "Control API health check failed"
            else
                log "Waiting for Control API... (attempt $i/10)"
                sleep 2
            fi
        fi
    done
    
    # Check WebSocket
    if netstat -ln | grep -q ":8765"; then
        success "WebSocket server is listening on port 8765"
    else
        warning "WebSocket server may not be running properly"
    fi
    
    # Check Dashboard
    for i in {1..10}; do
        if curl -s http://localhost:3000 > /dev/null; then
            success "Dashboard health check passed"
            break
        else
            if [ $i -eq 10 ]; then
                warning "Dashboard health check failed"
            else
                log "Waiting for dashboard... (attempt $i/10)"
                sleep 3
            fi
        fi
    done
}

# Function to stop all services
stop_services() {
    log "Stopping all services..."
    
    # Stop processes by PID files
    for service in control_api websocket dashboard; do
        pid_file="$PID_DIR/${service}.pid"
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null; then
                log "Stopping $service (PID: $pid)"
                kill "$pid"
                rm -f "$pid_file"
            fi
        fi
    done
    
    # Wait for processes to stop
    sleep 3
    
    # Force kill if necessary
    pkill -f "control_server" || true
    pkill -f "websocket_server" || true
    pkill -f "npm.*start" || true
    
    success "All services stopped"
}

# Function to show status
show_status() {
    log "Service Status:"
    
    for service in control_api websocket dashboard; do
        pid_file="$PID_DIR/${service}.pid"
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null; then
                echo -e "  ${GREEN}✓${NC} $service (PID: $pid)"
            else
                echo -e "  ${RED}✗${NC} $service (PID file exists but process not running)"
            fi
        else
            echo -e "  ${RED}✗${NC} $service (not started)"
        fi
    done
    
    echo
    log "Endpoints:"
    echo "  Control API:  http://localhost:8080"
    echo "  WebSocket:    ws://localhost:8765"
    echo "  Dashboard:    http://localhost:3000"
    echo "  Bot Controls: http://localhost:3000/controls"
}

# Function to show logs
show_logs() {
    service=$1
    if [ -z "$service" ]; then
        log "Available log files:"
        ls -la "$LOG_DIR/"
        return
    fi
    
    log_file="$LOG_DIR/${service}.log"
    if [ -f "$log_file" ]; then
        log "Showing logs for $service:"
        tail -f "$log_file"
    else
        error "Log file not found: $log_file"
    fi
}

# Main execution
case "${1:-start}" in
    "start")
        log "Starting PolyWeather Trading Bot with Control API..."
        
        # Check if services are already running
        if [ -f "$PID_DIR/control_api.pid" ] || [ -f "$PID_DIR/websocket.pid" ] || [ -f "$PID_DIR/dashboard.pid" ]; then
            warning "Some services may already be running. Use 'stop' first or 'restart'."
        fi
        
        # Start services
        start_control_api
        start_websocket_server
        start_dashboard
        
        # Health checks
        check_health
        
        echo
        success "All services started successfully!"
        show_status
        
        echo
        log "To view real-time logs: $0 logs <service>"
        log "To stop all services: $0 stop"
        log "To check status: $0 status"
        ;;
        
    "stop")
        stop_services
        ;;
        
    "restart")
        stop_services
        sleep 2
        exec "$0" start
        ;;
        
    "status")
        show_status
        ;;
        
    "logs")
        show_logs "$2"
        ;;
        
    "health")
        check_health
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [service]|health}"
        echo
        echo "Commands:"
        echo "  start     - Start all services (Control API, WebSocket, Dashboard)"
        echo "  stop      - Stop all services"
        echo "  restart   - Stop and start all services"
        echo "  status    - Show service status and endpoints"
        echo "  logs      - Show available logs or tail specific service log"
        echo "  health    - Check health of all services"
        echo
        echo "Services: control_api, websocket, dashboard"
        exit 1
        ;;
esac