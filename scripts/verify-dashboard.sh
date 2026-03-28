#!/bin/bash

# PolyWeather Dashboard Verification Script
# Verifies the dashboard setup and dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 PolyWeather Dashboard Verification${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if we're in the right directory
if [[ ! -d "dashboard" ]]; then
    echo -e "${RED}❌ Dashboard directory not found. Please run from polyweather-bot root.${NC}"
    exit 1
fi

cd dashboard

echo -e "${BLUE}📋 Checking dashboard setup...${NC}"

# Check Node.js version
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✅ Node.js: $NODE_VERSION${NC}"
else
    echo -e "${RED}❌ Node.js not found. Please install Node.js 16+${NC}"
    exit 1
fi

# Check npm version
if command -v npm >/dev/null 2>&1; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✅ npm: $NPM_VERSION${NC}"
else
    echo -e "${RED}❌ npm not found${NC}"
    exit 1
fi

# Check package.json
if [[ -f "package.json" ]]; then
    echo -e "${GREEN}✅ package.json found${NC}"
else
    echo -e "${RED}❌ package.json not found${NC}"
    exit 1
fi

# Check key dependencies
echo -e "${BLUE}📦 Checking dependencies...${NC}"
if [[ -f "package.json" ]]; then
    if grep -q "@mui/material" package.json; then
        echo -e "${GREEN}✅ Material-UI configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Material-UI not found in package.json${NC}"
    fi
    
    if grep -q "react-router-dom" package.json; then
        echo -e "${GREEN}✅ React Router configured${NC}"
    else
        echo -e "${YELLOW}⚠️  React Router not found${NC}"
    fi
    
    if grep -q "recharts" package.json; then
        echo -e "${GREEN}✅ Recharts configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Recharts not found${NC}"
    fi
fi

# Check source files
echo -e "${BLUE}📁 Checking source structure...${NC}"

required_files=(
    "src/App.tsx"
    "src/contexts/AuthContext.tsx"
    "src/contexts/WebSocketContext.tsx"
    "src/components/Layout.tsx"
    "src/pages/Dashboard.tsx"
    "src/pages/Login.tsx"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file missing${NC}"
    fi
done

# Check configuration files
echo -e "${BLUE}⚙️  Checking configuration...${NC}"

if [[ -f ".env.example" ]]; then
    echo -e "${GREEN}✅ Environment template found${NC}"
else
    echo -e "${YELLOW}⚠️  .env.example not found${NC}"
fi

if [[ -f "Dockerfile" ]]; then
    echo -e "${GREEN}✅ Dockerfile found${NC}"
else
    echo -e "${YELLOW}⚠️  Dockerfile not found${NC}"
fi

# Check if node_modules exists
if [[ -d "node_modules" ]]; then
    echo -e "${GREEN}✅ Dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Dependencies not installed. Run: npm install${NC}"
fi

# Performance checks
echo -e "${BLUE}🚀 Performance configuration...${NC}"

if [[ -f "public/sw.js" ]]; then
    echo -e "${GREEN}✅ Service Worker configured${NC}"
else
    echo -e "${YELLOW}⚠️  Service Worker not found${NC}"
fi

if [[ -f "nginx.conf" ]]; then
    echo -e "${GREEN}✅ Nginx configuration found${NC}"
else
    echo -e "${YELLOW}⚠️  Nginx configuration not found${NC}"
fi

# Check environment variables
echo -e "${BLUE}🔧 Environment check...${NC}"

if [[ -f ".env" ]]; then
    echo -e "${GREEN}✅ .env file configured${NC}"
    
    if grep -q "REACT_APP_API_URL" .env; then
        API_URL=$(grep "REACT_APP_API_URL" .env | cut -d '=' -f2)
        echo -e "${GREEN}  API URL: $API_URL${NC}"
    fi
    
    if grep -q "REACT_APP_WS_URL" .env; then
        WS_URL=$(grep "REACT_APP_WS_URL" .env | cut -d '=' -f2)
        echo -e "${GREEN}  WebSocket URL: $WS_URL${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  .env file not found. Copy from .env.example${NC}"
fi

echo -e "${BLUE}🎯 Quick start commands:${NC}"
echo -e "${GREEN}  Development: npm start${NC}"
echo -e "${GREEN}  Production:  npm run build${NC}"
echo -e "${GREEN}  Docker:      docker-compose up dashboard${NC}"
echo -e "${GREEN}  Script:      ../scripts/start-dashboard.sh${NC}"

echo -e "\n${BLUE}📊 Expected performance targets:${NC}"
echo -e "${GREEN}  ⚡ Load time: <3 seconds${NC}"
echo -e "${GREEN}  🔗 WebSocket latency: <100ms${NC}"
echo -e "${GREEN}  📱 Responsive design: Mobile-first${NC}"
echo -e "${GREEN}  🔒 Security: JWT authentication${NC}"
echo -e "${GREEN}  🎨 UI: Material-UI dark theme${NC}"

echo -e "\n${GREEN}✅ Dashboard verification complete!${NC}"