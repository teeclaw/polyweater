# fail2ban/ - Intrusion Prevention & Security

## PURPOSE
Fail2ban configuration for automated intrusion prevention, rate limiting, and security monitoring.

## STRUCTURE
```
fail2ban/
├── filter.d/
│   ├── polyweather-api.conf  # API endpoint protection rules
│   └── polyweather-auth.conf # Authentication failure detection
└── jail.local                # Jail configuration and ban policies
```

## PROTECTION RULES
- **API Rate Limiting**: Max 100 requests/minute per IP
- **Authentication Brute Force**: 5 failed attempts = 10-minute ban
- **Suspicious Patterns**: Automated blocking of malicious requests
- **Geographic Filtering**: Optional country-based restrictions

## MONITORED ENDPOINTS
- `/login` - Authentication attempts
- `/api/trade` - Trading API calls
- `/api/market-data` - Market data requests
- Dashboard access patterns

## BAN POLICIES
```
Authentication failures: 5 attempts → 10 min ban → 1 hour → 24 hours
API rate limit: 100/min → 5 min ban → 30 min → 6 hours  
Suspicious activity: Immediate 1 hour ban
```

## RELATIONS
- **Protects**: Backend API services and Streamlit dashboard
- **Monitors**: Nginx access logs and application logs
- **Integrates with**: System firewall and iptables rules
- **Alerts to**: Monitoring system for security events

## LOG ANALYSIS
- Real-time monitoring via `/var/log/fail2ban.log`
- Integration with Prometheus metrics
- Dashboard alerts for security incidents

**Security hardening implemented by Eve (Operations Security)**