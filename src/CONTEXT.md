# src/ - Core Bot Logic (Legacy)

## PURPOSE
**⚠️ LEGACY**: Original Python trading bot implementation - partially superseded by distributed service architecture.

## STATUS
- **PARTIALLY DEPRECATED**: Core logic migrated to service-based architecture
- **STILL CONTAINS**: Some reusable trading algorithms and market analysis logic
- **MIGRATION STATUS**: Key components moved to backend API services

## ORIGINAL CONTENTS
- Trading strategy implementations
- Market data analysis algorithms  
- Weather correlation models
- Risk management calculations
- Portfolio optimization logic

## MIGRATION PATH
```
src/ (legacy monolith) → Distributed Services
├── Trading Logic → Backend API services (port 8080)
├── Data Processing → Database stored procedures
├── Market Analysis → Streamlit dashboard analytics
└── Risk Management → Trading controls in dashboard
```

## WHAT'S STILL USEFUL
- **Algorithm References**: Trading strategy implementations
- **Analysis Models**: Weather-market correlation algorithms
- **Calculation Libraries**: Risk and portfolio optimization functions
- **Test Data**: Historical analysis and backtesting datasets

## RELATIONS
- **Superseded by**: Backend API services and Streamlit dashboard
- **Referenced by**: New service implementations for algorithm porting
- **Contains**: Reusable mathematical models and trading logic
- **Replaced by**: Service-oriented architecture with clear separation

## FUTURE PLANS
- **Archive**: Historical algorithm implementations
- **Extract**: Reusable components into shared libraries
- **Deprecate**: Monolithic structure in favor of microservices
- **Maintain**: Only for reference and algorithm validation

**Legacy code maintained for algorithm reference and gradual service migration**