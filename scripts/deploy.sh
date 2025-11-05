#!/bin/bash

# Traefik + Cloudflared Deployment Script
# Usage: ./scripts/deploy.sh

set -e

echo "🚀 Starting Traefik + Cloudflared deployment..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Copy .env.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

echo "📋 Configuration loaded:"
echo "  - Domain: $DOMAIN"
echo "  - SSL Email: $SSL_EMAIL"
echo "  - Cloudflare Tunnel: Configured"

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p traefik/letsencrypt
mkdir -p traefik/config
mkdir -p logs/traefik

# Set proper permissions
echo "🔒 Setting permissions..."
chmod 600 traefik/letsencrypt/* 2>/dev/null || true
chmod 644 traefik/config/*.yml

# Create traefik-network if it doesn't exist
echo "🌐 Creating Docker networks..."
docker network create traefik-network 2>/dev/null || true

# Check if scangoo-network exists
if ! docker network ls | grep -q scangoo-network; then
    echo "⚠️  scangoo-network not found. Creating it..."
    docker network create scangoo-network
fi

# Stop existing services
echo "🛑 Stopping existing services..."
docker-compose down --remove-orphans || true

# Start main services first
echo "🔄 Starting main services..."
docker-compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service health
echo "🔍 Checking service health..."
for service in zookeeper kafka elasticsearch mysql redis; do
    if docker-compose ps | grep -q "$service.*Up"; then
        echo "✅ $service is running"
    else
        echo "❌ $service failed to start"
        docker-compose logs $service
    fi
done

# Start Traefik
echo "🚦 Starting Traefik..."
cd traefik
docker-compose up -d
cd ..

echo "⏳ Waiting for Traefik to be ready..."
sleep 15

# Check Traefik
if curl -s http://localhost:8080/ping > /dev/null; then
    echo "✅ Traefik is running"
else
    echo "❌ Traefik failed to start"
    docker-compose -f traefik/docker-compose.yml logs traefik
fi

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 Access your services:"
echo "  Traefik Dashboard: https://traefik.$DOMAIN"
echo "  Kafka UI:          https://kafka.$DOMAIN"
echo "  Kibana:            https://kibana.$DOMAIN"
echo "  Elasticsearch:     https://es.$DOMAIN"
echo "  Nexus:             https://nexus.$DOMAIN"
echo "  MySQL Admin:       https://mysql.$DOMAIN"
echo "  Redis Commander:   https://redis.$DOMAIN"
echo ""
echo "🔐 Default credentials:"
echo "  Traefik: admin / admin123 (change in .env)"
echo "  Redis:   admin / $REDIS_PASSWORD"
echo "  MySQL:   scangoo / Duong02vodoi"
echo ""
echo "📝 To check logs:"
echo "  docker-compose logs -f [service-name]"
echo ""
echo "🛑 To stop:"
echo "  docker-compose down && docker-compose -f traefik/docker-compose.yml down"