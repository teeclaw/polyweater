# PolyWeather Trading Bot - Agent Context Guide

## 🎯 PROJECT OVERVIEW

**PolyWeather** is a production-ready automated trading bot for Polymarket prediction markets with **$50 starting capital**. The bot uses weather data and market analysis to make profitable trades on weather-related prediction markets.

### Key Statistics
- **Capital Management**: $50 starting capital with strict risk controls
- **Performance**: 7.4ms database response time, <3s dashboard load, 2-3s kill switch
- **Status**: Production-ready (Phase 1-2 complete, Phase 3 ready)
- **Team**: Kenzo (Backend), Maxim (Database), Marco (Frontend), Eve (Operations)

### Technology Stack
- **Backend**: Python FastAPI with PostgreSQL + Redis
- **Frontend**: Streamlit dashboard (bulletproof Python, no JavaScript corruption)
- **Trading**: PolyClaw CLI integration for Polymarket execution
- **Infrastructure**: Docker deployment with GCP hosting
- **Security**: SSL, authentication, fail2ban, rate limiting

## 📁 PROJECT STRUCTURE

```
polyweather-bot/
├── CLAUDE.md                      # This file - Agent context guide
├── README.md                      # Project documentation
├── streamlit_dashboard.py          # Main dashboard (trader/polyweather2024)
├── mock_auth_server.py            # Authentication mock for testing
├── validate_security.py           # Security validation tools
├── 
├── 📊 CONFIGURATION FILES
├── .env.example                   # Environment variables template
├── .gitignore                     # Git ignore rules
├── requirements.txt               # Python dependencies
├── requirements-secure.txt        # Security-focused dependencies
├── Dockerfile                     # Container build instructions
├── docker-compose.yml             # Standard deployment
├── docker-compose-streamlit.yml   # Streamlit-specific deployment
├── docker-compose-secure.yml      # Production security deployment
├── 
├── 🗂️ LEVEL 1 DIRECTORIES (see individual CONTEXT.md files)
├── .streamlit/                    # Streamlit configuration
├── dashboard/                     # Legacy React dashboard (deprecated)
├── data/                          # Trading data and cache
├── database/                      # PostgreSQL schemas and config
├── docs/                          # API documentation
├── fail2ban/                      # Intrusion prevention
├── frontend/                      # Legacy frontend files (deprecated)
├── logs/                          # Application logs
├── monitoring/                    # Prometheus metrics
├── nginx/                         # Reverse proxy configuration
├── redis/                         # Redis cache configuration
├── scripts/                       # Automation and deployment scripts
├── secrets/                       # API keys and certificates
├── src/                           # Core bot logic (legacy)
├── ssl/                           # SSL certificates and security
└── venv/                          # Python virtual environment
```

## 🚀 QUICK START COMMANDS

### Local Development
```bash
# Clone and setup
git clone https://github.com/teeclaw/polyweater.git
cd polyweater

# Install dependencies
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Run Streamlit dashboard
streamlit run streamlit_dashboard.py
# Access: http://localhost:3000
# Login: trader / polyweather2024
```

### Production Deployment
```bash
# Standard deployment
docker-compose up -d

# Streamlit-specific deployment (recommended)
docker-compose -f docker-compose-streamlit.yml up -d

# Security-hardened deployment
docker-compose -f docker-compose-secure.yml up -d
```

## 🔧 CRITICAL CONFIGURATION

### Port Standardization
- **Port 3000**: Dashboard (Streamlit, NOT React)
- **Port 8080**: Backend API
- **Port 8765**: WebSocket real-time data
- **Port 5433**: PostgreSQL database
- **Port 6380**: Redis cache

### Authentication
- **Dashboard Login**: Set via `DASHBOARD_USER` / `DASHBOARD_PASSWORD` in `.env.local`
- **Database**: Set via `POSTGRES_USER` / `POSTGRES_PASSWORD` in `.env.local`
- **API Keys**: Stored in `.env.local` file (NEVER commit to git!)
- **⚠️  SECURITY**: All credentials are in `.env.local` which is gitignored. Never hardcode passwords.

### Key Environment Variables
```bash
STARTING_CAPITAL=50.00
MAX_POSITION_SIZE=5.00
PAPER_TRADING=true
DEVELOPMENT_MODE=false
```

## 🏗️ ARCHITECTURE FLOW

```
Weather APIs → Bot Logic → PolyClaw → Polymarket
     ↓              ↓          ↓
Database ←→ Backend API ←→ Dashboard
     ↓              ↓          ↓
 PostgreSQL     FastAPI   Streamlit
```

## 📋 DEPLOYMENT PHASES

### Phase 1 ✅ COMPLETE
- Database optimization (7.4ms response)
- Core bot logic implementation
- Basic dashboard functionality

### Phase 2 ✅ COMPLETE  
- Streamlit dashboard (bulletproof Python)
- Emergency kill switch (2-3s response)
- Trading controls and risk management

### Phase 3 🎯 READY
- Live trading activation
- Advanced analytics
- Performance optimization

## 🚨 KNOWN ISSUES & SOLUTIONS

### Dashboard Spinning Issue ✅ FIXED
**Problem**: Streamlit hanging on GCP due to email prompt
**Solution**: `echo "" | streamlit run` automatically provides blank email

### Port Confusion ✅ STANDARDIZED
**Problem**: Ports kept changing (3000 → 8501 → 3000)  
**Solution**: Locked to Port 3000 consistently

### JavaScript Corruption ✅ ELIMINATED
**Problem**: React dashboard corrupted by malicious JavaScript injection
**Solution**: Complete migration to Python Streamlit (no JavaScript)

## 🔐 SECURITY FEATURES

- SSL/TLS encryption with self-signed certificates
- JWT authentication with secure tokens
- Fail2ban intrusion prevention
- Rate limiting and DDoS protection  
- Secure secrets management
- Database connection encryption

## 📊 MONITORING & METRICS

- **Health Checks**: `/health` endpoints for all services
- **Prometheus**: Metrics collection on port 8000
- **Logging**: Structured logs in `/logs` directory
- **Performance**: Sub-second response times across all components

## 🤝 TEAM COLLABORATION

Each folder has a `CONTEXT.md` file explaining its purpose and relationships. The project follows a modular architecture where:

- **Database team** (Maxim) owns `/database` and `/redis`
- **Backend team** (Kenzo) owns `/scripts` and API logic
- **Frontend team** (Marco) owns dashboard components  
- **Security team** (Eve) owns `/ssl`, `/fail2ban`, `/nginx`

## 📚 NEXT STEPS FOR AGENTS

1. **Read folder CONTEXT.md files** for detailed understanding
2. **Check deployment status** with health check scripts
3. **Review security validation** in `/scripts/validate-*` files
4. **Test locally first** before GCP deployment
5. **Use standardized ports** (3000 for dashboard, always!)

---
*This context guide ensures seamless agent handoff and consistent project understanding across the development team.*