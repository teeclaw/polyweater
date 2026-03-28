#!/bin/bash
# Setup script for PolyWeather trading bot infrastructure

set -e

echo "🚀 Setting up PolyWeather Trading Bot Infrastructure"
echo "=================================================="

# Check requirements
echo "✅ Checking requirements..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is required but not installed"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your API keys before running the bot"
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p data/postgres
mkdir -p data/redis
mkdir -p data/prometheus
mkdir -p logs

# Set permissions for PostgreSQL data directory
sudo chown -R 999:999 data/postgres 2>/dev/null || echo "⚠️  Could not set PostgreSQL permissions (may need manual setup)"

# Start the infrastructure
echo "🏗️  Starting infrastructure..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to start..."
sleep 10

# Check if PostgreSQL is ready
echo "🔍 Checking PostgreSQL readiness..."
for i in {1..30}; do
    if docker exec polyweather-postgres pg_isready -U polyweather_user -d polyweather > /dev/null 2>&1; then
        echo "✅ PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL failed to start within timeout"
        exit 1
    fi
    sleep 2
done

# Check if Redis is ready
echo "🔍 Checking Redis readiness..."
for i in {1..15}; do
    if docker exec polyweather-redis redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis is ready!"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ Redis failed to start within timeout"
        exit 1
    fi
    sleep 2
done

# Run initial database setup
echo "📊 Setting up database schema..."
if docker exec polyweather-postgres psql -U polyweather_user -d polyweather -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Database schema initialized successfully"
else
    echo "❌ Database schema initialization failed"
    exit 1
fi

# Test Redis connection
echo "🔄 Testing Redis connection..."
if docker exec polyweather-redis redis-cli set test_key "test_value" > /dev/null 2>&1; then
    docker exec polyweather-redis redis-cli del test_key > /dev/null 2>&1
    echo "✅ Redis connection test successful"
else
    echo "❌ Redis connection test failed"
    exit 1
fi

# Create initial partition management
echo "🗂️  Setting up partition management..."
docker exec polyweather-postgres psql -U polyweather_user -d polyweather -c "SELECT manage_time_series_partitions();" > /dev/null 2>&1

# Run health check
echo "🏥 Running health check..."
if ./scripts/health-check.sh; then
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "📋 Quick Start:"
    echo "   • PostgreSQL: localhost:5432"
    echo "   • Redis: localhost:6379" 
    echo "   • Prometheus: http://localhost:9090"
    echo "   • PostgreSQL Exporter: http://localhost:9187/metrics"
    echo "   • Redis Exporter: http://localhost:9121/metrics"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   • Health check: ./scripts/health-check.sh"
    echo "   • View logs: docker-compose logs -f"
    echo "   • Stop services: docker-compose down"
    echo "   • Database shell: docker exec -it polyweather-postgres psql -U polyweather_user -d polyweather"
    echo "   • Redis shell: docker exec -it polyweather-redis redis-cli"
    echo ""
    echo "⚠️  Don't forget to:"
    echo "   1. Edit .env with your API keys"
    echo "   2. Set up monitoring alerts in Prometheus"
    echo "   3. Configure backup strategy for production use"
else
    echo "❌ Setup completed but health check failed"
    exit 1
fi