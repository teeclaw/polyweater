# monitoring/ - Prometheus Metrics & Performance Monitoring

## PURPOSE
Prometheus-based monitoring system for real-time performance tracking, alerting, and system health analysis.

## CONFIGURATION
- `prometheus.yml` - Main Prometheus configuration with scrape targets and alert rules

## MONITORED METRICS
### Application Performance
- **Database Response Time**: Target <10ms, Alert >50ms
- **Dashboard Load Time**: Target <3s, Alert >10s  
- **Kill Switch Response**: Target <3s, Alert >5s
- **API Response Time**: Target <1s, Alert >5s

### Trading Metrics  
- **Active Positions**: Real-time position tracking
- **P&L Performance**: Daily/weekly profit tracking
- **Risk Exposure**: Position size vs available capital
- **Trade Success Rate**: Win/loss ratio monitoring

### System Health
- **CPU Usage**: Docker container resource utilization
- **Memory Usage**: Application memory consumption  
- **Disk Space**: Log files and data storage monitoring
- **Network I/O**: API calls and data transfer rates

## ALERT THRESHOLDS
```yaml
High Priority (Immediate):
- Database down or >100ms response
- Trading API failures  
- Security breach indicators

Medium Priority (15min delay):
- High CPU usage >80%
- Dashboard performance degradation
- API rate limit approaching

Low Priority (1hr delay):  
- Log file size warnings
- Non-critical service restarts
```

## RELATIONS
- **Scrapes from**: All application services on port 8000
- **Alerts to**: Dashboard notifications and team channels
- **Integrates with**: Grafana dashboards (optional)
- **Stores in**: Local Prometheus database with 30-day retention

**Performance monitoring ensures $50 capital protection and system reliability**