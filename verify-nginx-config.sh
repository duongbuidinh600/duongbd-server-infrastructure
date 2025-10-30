#!/bin/bash

echo "🔍 Nginx Configuration Verification Script"
echo "======================================="

# Check if we can access Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

echo "✅ Docker found"

# Check if containers are running
echo ""
echo "📦 Checking running containers..."
if docker compose ps | grep -q "nginx.*Up"; then
    echo "✅ Nginx container is running"
else
    echo "❌ Nginx container is not running properly"
    docker compose ps
    exit 1
fi

# Test Nginx configuration syntax
echo ""
echo "⚙️ Testing Nginx configuration syntax..."
if docker compose exec -T nginx nginx -t; then
    echo "✅ Nginx configuration syntax is valid"
else
    echo "❌ Nginx configuration has syntax errors"
    exit 1
fi

# Test health endpoint
echo ""
echo "🏥 Testing health endpoint..."
if curl -s http://localhost/health | grep -q "healthy"; then
    echo "✅ Health endpoint is working"
else
    echo "❌ Health endpoint is not responding correctly"
    curl -v http://localhost/health
fi

# Check for server name conflicts in logs
echo ""
echo "🔍 Checking for server name conflicts in logs..."
if docker compose logs nginx 2>&1 | grep -q "conflicting server name"; then
    echo "⚠️  Server name conflicts still exist in logs"
    echo "Showing recent conflicts:"
    docker compose logs nginx 2>&1 | grep "conflicting server name" | tail -5
else
    echo "✅ No server name conflicts found in logs"
fi

echo ""
echo "🎯 Testing domain-specific endpoints..."

# Test Kafka UI
if curl -s -H "Host: kafka.duongbd.site" http://localhost/ | grep -q -i "kafka\|ui"; then
    echo "✅ Kafka UI proxy is working"
else
    echo "❌ Kafka UI proxy is not responding correctly"
fi

# Test Kibana
if curl -s -H "Host: kibana.duongbd.site" http://localhost/ | grep -q -i "kibana\|elastic"; then
    echo "✅ Kibana proxy is working"
else
    echo "❌ Kibana proxy is not responding correctly"
fi

# Test Elasticsearch
if curl -s -H "Host: es.duongbd.site" http://localhost/ | grep -q -i "elasticsearch\|cluster_name"; then
    echo "✅ Elasticsearch proxy is working"
else
    echo "❌ Elasticsearch proxy is not responding correctly"
fi

echo ""
echo "📋 Configuration Summary:"
echo "========================"
echo "• Health check: http://localhost/health"
echo "• Kafka UI: http://kafka.duongbd.site (via Cloudflare tunnel)"
echo "• Kibana: http://kibana.duongbd.site (via Cloudflare tunnel)"
echo "• Elasticsearch: http://es.duongbd.site (via Cloudflare tunnel)"

echo ""
echo "🚀 Configuration verification complete!"