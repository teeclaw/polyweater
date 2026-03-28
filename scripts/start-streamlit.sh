#!/bin/bash

# PolyWeather Streamlit Dashboard Startup Script
# Starts the Streamlit dashboard with headless configuration

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting PolyWeather Streamlit Dashboard...${NC}"

# Navigate to the correct directory
cd /app

# Disable Streamlit email prompt and telemetry for headless operation
export STREAMLIT_SERVER_HEADLESS=true
export STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
export STREAMLIT_GLOBAL_DEVELOPMENT_MODE=false

echo -e "${BLUE}⚙️  Configuration:${NC}"
echo -e "  Port: 3000"
echo -e "  Headless: true"
echo -e "  Host: 0.0.0.0"

echo -e "${GREEN}✅ Starting Streamlit server...${NC}"

# Start Streamlit with proper configuration
# Use echo to provide blank email when prompted
echo "" | python -m streamlit run streamlit_dashboard.py \
    --server.port=3000 \
    --server.address=0.0.0.0 \
    --server.headless=true \
    --browser.gatherUsageStats=false \
    --global.developmentMode=false