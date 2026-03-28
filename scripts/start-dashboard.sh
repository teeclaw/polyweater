#!/bin/bash

# PolyWeather Dashboard Startup Script
# Starts the React dashboard with optimized performance settings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DASHBOARD_DIR="./dashboard"
PORT=${DASHBOARD_PORT:-3000}
NODE_ENV=${NODE_ENV:-development}

echo -e "${BLUE}🚀 Starting PolyWeather Dashboard...${NC}"

# Check if we're in the right directory
if [[ ! -d "$DASHBOARD_DIR" ]]; then
    echo -e "${RED}❌ Dashboard directory not found. Please run from polyweather-bot root.${NC}"
    exit 1
fi

cd "$DASHBOARD_DIR"

# Check if node_modules exists
if [[ ! -d "node_modules" ]]; then
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    npm install
fi

# Check if backend is running
echo -e "${BLUE}🔍 Checking backend services...${NC}"
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Backend API not detected on port 8080${NC}"
    echo -e "${YELLOW}   The dashboard will run in demo mode${NC}"
else
    echo -e "${GREEN}✅ Backend API is running${NC}"
fi

# Check WebSocket server
if ! nc -z localhost 8765 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  WebSocket server not detected on port 8765${NC}"
    echo -e "${YELLOW}   Real-time features will be limited${NC}"
else
    echo -e "${GREEN}✅ WebSocket server is running${NC}"
fi

# Performance optimizations for development
export FAST_REFRESH=true
export GENERATE_SOURCEMAP=false
export BROWSER=none

# Set environment variables
export REACT_APP_API_URL=${REACT_APP_API_URL:-http://localhost:8080}
export REACT_APP_WS_URL=${REACT_APP_WS_URL:-ws://localhost:8765}

echo -e "${BLUE}⚙️  Configuration:${NC}"
echo -e "  Port: ${PORT}"
echo -e "  API URL: ${REACT_APP_API_URL}"
echo -e "  WebSocket URL: ${REACT_APP_WS_URL}"
echo -e "  Environment: ${NODE_ENV}"

# Start based on environment
if [[ "$NODE_ENV" == "production" ]]; then
    echo -e "${BLUE}🏭 Starting in production mode...${NC}"
    
    # Build if build directory doesn't exist
    if [[ ! -d "build" ]]; then
        echo -e "${YELLOW}🔨 Building application...${NC}"
        npm run build:prod
    fi
    
    # Start production server
    echo -e "${GREEN}✅ Starting production server on port ${PORT}${NC}"
    npx serve -s build -l ${PORT}
    
else
    echo -e "${BLUE}🔧 Starting in development mode...${NC}"
    echo -e "${GREEN}✅ Dashboard will be available at http://localhost:${PORT}${NC}"
    echo -e "${BLUE}📱 Mobile-responsive design optimized for trading${NC}"
    echo -e "${BLUE}🔄 Hot reload enabled for development${NC}"
    
    # Start development server
    PORT=${PORT} npm start
fi