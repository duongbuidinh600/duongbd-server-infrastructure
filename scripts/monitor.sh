#!/bin/bash

# Health monitoring script for Traefik + services
# Usage: ./scripts/monitor.sh

set -e

DOMAIN=${DOMAIN:-duongbd.site}

echo "🔍 Service Health Monitor"
echo "========================"

# Function to check URL
check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}

    echo -n "  $name: "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
        echo "✅ UP"
        return 0
    else
        echo "❌ DOWN"
        return 1
    fi
}

# Function to check Docker container
check_container() {
    local name=$1
    echo -n "  Container $name: "
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$name.*Up"; then
        echo "✅ RUNNING"
        return 0
    else
        echo "❌ STOPPED"
        return 1
    fi
}

echo "🐳 Docker Containers:"
check_container "traefik"
check_container "cloudflared"
check_container "kafka-ui"
check_container "kibana"
check_container "elasticsearch"
check_container "redis-commander"
check_container "adminer"
check_container "nexus"

echo ""
echo "🌐 Service Endpoints:"

# Check main services (HTTP)
check_service "Traefik Dashboard" "https://traefik.$DOMAIN/dashboard/" 401
check_service "Kafka UI" "https://kafka.$DOMAIN"
check_service "Kibana" "https://kibana.$DOMAIN/api/status" 200
check_service "Elasticsearch" "https://es.$DOMAIN/_cluster/health" 200
check_service "Nexus" "https://nexus.$DOMAIN" 200
check_service "MySQL Admin" "https://mysql.$DOMAIN" 200
check_service "Redis Commander" "https://redis.$DOMAIN" 200

echo ""
echo "📊 Resource Usage:"
echo "CPU%   MEM%   MEM USAGE    CONTAINER"
docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.Name}}" | grep -E "(traefik|cloudflared|kafka|elasticsearch|mysql|redis|kibana|nexus)"

echo ""
echo "📝 Recent Logs (last 5 lines each):"
for service in traefik cloudflared kafka-ui kibana elasticsearch; do
    echo "--- $service ---"
    docker logs --tail 5 "$service" 2>/dev/null | tail -n 1 || echo "No logs available"
done

echo ""
echo "🔧 Quick Actions:"
echo "  View logs:     docker-compose logs -f [service]"
echo "  Restart:       docker-compose restart [service]"
echo "  Full status:   docker-compose ps"
echo "  Resource use:  docker stats"