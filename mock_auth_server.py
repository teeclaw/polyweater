#!/usr/bin/env python3
"""
Mock Authentication Server for PolyWeather Dashboard
Provides minimal endpoints to allow frontend to load and authenticate
"""

import json
import time
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="PolyWeather Mock Auth API", version="1.0.0")

# CORS configuration for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Mock user data
MOCK_USER = {
    "id": "mock_user_1",
    "username": "trader",
    "email": "trader@polyweather.local",
    "role": "trader",
    "permissions": ["dashboard", "portfolio", "markets", "weather", "trading"],
    "preferences": {
        "theme": "light",
        "notifications": True,
        "autoRefresh": True,
        "refreshInterval": 30
    }
}

class LoginRequest(BaseModel):
    username: str
    password: str
    totp_token: str = None

class AuthResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
    user: dict

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.post("/auth/login", response_model=AuthResponse)
async def login(request: LoginRequest):
    """Mock login endpoint - accepts any valid credentials"""
    
    # For demo purposes, accept any username/password
    if not request.username or not request.password:
        raise HTTPException(status_code=400, detail="Username and password required")
    
    # Generate mock JWT token (just a timestamp for this demo)
    mock_token = f"mock_jwt_token_{int(time.time())}"
    
    return AuthResponse(
        access_token=mock_token,
        token_type="bearer",
        expires_in=3600,  # 1 hour
        user=MOCK_USER
    )

@app.get("/api/auth/verify")
async def verify_token():
    """Mock token verification endpoint"""
    return {
        "valid": True,
        "user": MOCK_USER
    }

@app.post("/auth/logout")
async def logout():
    """Mock logout endpoint"""
    return {"status": "logged_out", "timestamp": datetime.now().isoformat()}

@app.post("/auth/refresh")
async def refresh_token():
    """Mock token refresh endpoint"""
    mock_token = f"mock_jwt_token_{int(time.time())}"
    
    return AuthResponse(
        access_token=mock_token,
        token_type="bearer",
        expires_in=3600,
        user=MOCK_USER
    )

@app.post("/auth/emergency")
async def emergency_auth():
    """Mock emergency authentication"""
    return {"status": "emergency_auth_success", "timestamp": datetime.now().isoformat()}

@app.get("/user/preferences")
async def get_user_preferences():
    """Get user preferences"""
    return MOCK_USER["preferences"]

@app.patch("/user/preferences")
async def update_user_preferences(preferences: dict):
    """Update user preferences"""
    MOCK_USER["preferences"].update(preferences)
    return MOCK_USER

@app.get("/api/v1/bot/status")
async def get_bot_status():
    """Mock bot status endpoint"""
    return {
        "running": False,
        "uptime_seconds": 0,
        "trades_today": 0,
        "current_capital": 50.0,
        "total_pnl": 0.0,
        "active_positions": 0,
        "last_update": datetime.now().isoformat()
    }

@app.get("/api/v1/trading/parameters")
async def get_trading_parameters():
    """Mock trading parameters"""
    return {
        "max_trades_per_day": 3,
        "max_position_size": 10.0,
        "min_confidence": 0.65,
        "daily_loss_limit": 5.0,
        "risk_multiplier": 1.0,
        "enable_stop_loss": False,
        "stop_loss_percent": 0.1,
        "emergency_pause": False,
        "risk_overrides": {},
        "last_updated": datetime.now().isoformat()
    }

if __name__ == "__main__":
    print("🚀 Starting Mock Authentication Server...")
    print("📍 API will be available at: http://localhost:8080")
    print("🔓 Use any username/password to login")
    
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")