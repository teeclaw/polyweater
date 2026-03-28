#!/bin/bash
# Maintenance script for PolyWeather trading bot database

set -e

echo "🔧 PolyWeather Database Maintenance"
echo "=================================="

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="./backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if database is accessible
if ! docker exec polyweather-postgres pg_isready -U polyweather_user -d polyweather > /dev/null 2>&1; then
    log "❌ Database is not accessible"
    exit 1
fi

log "✅ Database is accessible"

# 1. Create backup
log "📦 Creating database backup..."
docker exec polyweather-postgres pg_dump -U polyweather_user -d polyweather --verbose \
    --format=custom --no-owner --no-privileges > "$BACKUP_DIR/polyweather_${TIMESTAMP}.backup"

if [ $? -eq 0 ]; then
    log "✅ Backup created: polyweather_${TIMESTAMP}.backup"
    # Keep only last 7 days of backups
    find "$BACKUP_DIR" -name "polyweather_*.backup" -mtime +7 -delete
    log "🧹 Cleaned up old backups (>7 days)"
else
    log "❌ Backup failed"
    exit 1
fi

# 2. Run partition management
log "🗂️  Managing partitions..."
PARTITION_RESULT=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT manage_time_series_partitions();" | sed '/^$/d')
if [ ! -z "$PARTITION_RESULT" ]; then
    log "📊 Partition management results:"
    echo "$PARTITION_RESULT" | while read line; do
        log "   $line"
    done
else
    log "ℹ️  No partition changes needed"
fi

# 3. Run general maintenance
log "🛠️  Running database maintenance..."
MAINTENANCE_RESULT=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT perform_maintenance();" | sed '/^$/d')
if [ ! -z "$MAINTENANCE_RESULT" ]; then
    log "🔧 Maintenance results:"
    echo "$MAINTENANCE_RESULT" | while read line; do
        log "   $line"
    done
fi

# 4. Refresh materialized views
log "🔄 Refreshing materialized views..."
docker exec polyweather-postgres psql -U polyweather_user -d polyweather -c "SELECT refresh_market_summary();" > /dev/null 2>&1
log "✅ Market summary view refreshed"

# 5. Generate performance report
log "📊 Generating performance report..."
PERF_REPORT=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "SELECT metric_name || ': ' || metric_value || ' ' || unit FROM get_performance_metrics();" | sed '/^$/d')

echo ""
echo "📈 Performance Metrics:"
echo "====================="
echo "$PERF_REPORT" | while read line; do
    echo "   $line"
done

# 6. Check table sizes
log "💾 Checking table sizes..."
TABLE_SIZES=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "
SELECT 
    schemaname||'.'||tablename as table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;" | sed '/^$/d')

echo ""
echo "📊 Top 10 Largest Tables:"
echo "========================"
echo "$TABLE_SIZES" | while read line; do
    echo "   $line"
done

# 7. Check for long-running queries
LONG_QUERIES=$(docker exec polyweather-postgres psql -U polyweather_user -d polyweather -t -c "
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
  AND state = 'active';" | sed '/^$/d')

if [ ! -z "$LONG_QUERIES" ]; then
    echo ""
    echo "⚠️  Long-running queries detected:"
    echo "================================="
    echo "$LONG_QUERIES"
fi

# 8. Redis maintenance
log "🔄 Redis maintenance..."
REDIS_INFO=$(docker exec polyweather-redis redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r\n')
log "   Redis memory usage: $REDIS_INFO"

# Force Redis to save data
docker exec polyweather-redis redis-cli bgsave > /dev/null 2>&1
log "   Background save initiated"

# Clean up expired keys
EXPIRED_KEYS=$(docker exec polyweather-redis redis-cli eval "return #redis.call('keys', 'temp:*')" 0 2>/dev/null || echo "0")
log "   Temporary keys: $EXPIRED_KEYS"

echo ""
log "🎯 Maintenance completed successfully!"
log "   Backup location: $BACKUP_DIR/polyweather_${TIMESTAMP}.backup"

# Optional: Send maintenance report (placeholder for future notification system)
# send_maintenance_report "$BACKUP_DIR/polyweather_${TIMESTAMP}.backup" "$PERF_REPORT"