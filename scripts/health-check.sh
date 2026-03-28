#!/bin/bash
# Health check script for PolyWeather trading bot infrastructure

set -e

echo "🏥 PolyWeather Infrastructure Health Check"
echo "========================================"

# Check PostgreSQL
echo "📊 Checking PostgreSQL..."
if docker exec polyweather-postgres pg_isready -U polyweather_user -d polyweather > /dev/null 2>&1; then
    echo "✅ PostgreSQL is healthy"
    
    # Check database performance
    CONNECTIONS=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | xargs)
    echo "   Active connections: $CONNECTIONS"
    
    # Check recent data
    RECENT_DATA=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT COUNT(*) FROM market_data WHERE timestamp >= NOW() - INTERVAL '1 hour';" 2>/dev/null | xargs)
    echo "   Recent market data points: $RECENT_DATA"
    
else
    echo "❌ PostgreSQL is not responding"
    exit 1
fi

# Check Redis
echo ""
echo "🔄 Checking Redis..."
if docker exec polyweather-redis redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis is healthy"
    
    # Check Redis memory usage
    REDIS_MEMORY=$(docker exec polyweather-redis redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r\n')
    echo "   Memory usage: $REDIS_MEMORY"
    
    # Check Redis connected clients
    REDIS_CLIENTS=$(docker exec polyweather-redis redis-cli info clients | grep connected_clients | cut -d: -f2 | tr -d '\r\n')
    echo "   Connected clients: $REDIS_CLIENTS"
    
else
    echo "❌ Redis is not responding"
    exit 1
fi

# Check Prometheus
echo ""
echo "📈 Checking Prometheus..."
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "✅ Prometheus is healthy"
    
    # Check number of targets
    TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length' 2>/dev/null || echo "unknown")
    echo "   Active targets: $TARGETS"
    
else
    echo "❌ Prometheus is not responding"
fi

# Check exporters
echo ""
echo "📡 Checking Exporters..."

# PostgreSQL exporter
if curl -s http://localhost:9187/metrics | grep -q "pg_up 1" 2>/dev/null; then
    echo "✅ PostgreSQL exporter is working"
else
    echo "⚠️  PostgreSQL exporter may have issues"
fi

# Redis exporter
if curl -s http://localhost:9121/metrics | grep -q "redis_up 1" 2>/dev/null; then
    echo "✅ Redis exporter is working"
else
    echo "⚠️  Redis exporter may have issues"
fi

# Check disk space
echo ""
echo "💾 Checking Disk Space..."
DISK_USAGE=$(df -h /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "✅ Disk usage is healthy ($DISK_USAGE%)"
else
    echo "⚠️  Disk usage is high ($DISK_USAGE%)"
fi

# Performance summary
echo ""
echo "⚡ Performance Summary"
echo "===================="

# Database query performance check
AVG_QUERY_TIME=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT ROUND(AVG(mean_exec_time)::numeric, 2) FROM pg_stat_statements WHERE calls > 10;" 2>/dev/null | xargs || echo "N/A")
echo "📊 Average query time: ${AVG_QUERY_TIME}ms"

# Check for slow queries
SLOW_QUERIES=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT COUNT(*) FROM pg_stat_statements WHERE mean_exec_time > 100;" 2>/dev/null | xargs || echo "N/A")
echo "🐌 Slow queries (>100ms): $SLOW_QUERIES"

echo ""
echo "🎯 Health check completed!"