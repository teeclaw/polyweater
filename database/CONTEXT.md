# database/ - PostgreSQL Configuration & Schema

## PURPOSE
Database configuration, schema definitions, and initialization scripts for the PolyWeather PostgreSQL instance.

## STRUCTURE
```
database/
├── init/                       # Database initialization
│   ├── 01_schema.sql          # Core tables and indexes
│   ├── 01_schema_secure.sql   # Security-hardened schema
│   ├── 02_views_functions.sql # Views and stored procedures
│   └── 03_performance_tuning.sql # Optimization queries
├── config/                     # PostgreSQL configuration
│   ├── postgresql.conf        # Standard configuration
│   └── postgresql-secure.conf # Production security config
└── ssl/                        # Database SSL certificates
    ├── ca.key                 # Certificate authority key
    ├── server.crt             # Server certificate
    └── server.key             # Server private key
```

## KEY PERFORMANCE METRICS
- **Response Time**: 7.4ms average query response
- **Connection Pool**: 20 max connections
- **Cache Hit Ratio**: >95% for trading queries

## SCHEMA HIGHLIGHTS
- `trades` table with BTREE indexes on timestamp and market_id
- `market_data` with real-time price tracking
- `weather_forecasts` with spatial indexing
- `user_sessions` for dashboard authentication

## RELATIONS
- **Connects to**: Backend API services on port 8080
- **SSL secured**: Using certificates in `ssl/` subdirectory
- **Monitored by**: Prometheus metrics collection
- **Backed up by**: Scripts in `/scripts/` directory

## SECURITY FEATURES
- SSL/TLS encryption for all connections
- Role-based access control (RBAC)
- Query timeout limits and resource constraints
- Audit logging for sensitive operations

**Performance optimized by Maxim (Database Specialist)**