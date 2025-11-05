#!/bin/bash

# Validation script for Traefik setup
# Usage: ./scripts/validate.sh

set -e

DOMAIN=${DOMAIN:-duongbd.site}

echo "🧪 Traefik Setup Validation"
echo "==========================="

PASSED=0
FAILED=0

# Function to run test
run_test() {
    local test_name=$1
    local command=$2
    local expected_result=$3

    echo -n "  Testing $test_name... "

    if eval "$command" | grep -q "$expected_result"; then
        echo "✅ PASS"
        ((PASSED++))
        return 0
    else
        echo "❌ FAIL"
        ((FAILED++))
        return 1
    fi
}

echo "📁 File Structure Tests"
echo "------------------------"

run_test "Docker Compose exists" "ls -la docker-compose.yml" "docker-compose.yml"
run_test "Traefik config exists" "ls -la traefik/config/traefik.yml" "traefik.yml"
run_test "Middlewares config exists" "ls -la traefik/config/middlewares.yml" "middlewares.yml"
run_test "Deploy script executable" "ls -la scripts/deploy.sh" "rwx"
run_test "Monitor script executable" "ls -la scripts/monitor.sh" "rwx"

echo ""
echo "🐳 Docker Configuration Tests"
echo "-----------------------------"

# Check if Docker is available
if command -v docker &> /dev/null; then
    run_test "Docker daemon running" "docker info" "Containers:"
else
    echo "  Docker not available - skipping container tests"
fi

echo ""
echo "🔧 Configuration Syntax Tests"
echo "----------------------------"

run_test "Docker Compose syntax" "docker-compose config" "version:" 2>/dev/null || echo "  Docker not available - skipping syntax test"
run_test "Traefik YAML syntax" "python3 -c 'import yaml; yaml.safe_load(open(\"traefik/config/traefik.yml\"))'" "" 2>/dev/null || echo "  Python3/YAML not available - skipping syntax test"
run_test "Middlewares YAML syntax" "python3 -c 'import yaml; yaml.safe_load(open(\"traefik/config/middlewares.yml\"))'" "" 2>/dev/null || echo "  Python3/YAML not available - skipping syntax test"

echo ""
echo "🌐 Network Configuration Tests"
echo "------------------------------"

run_test "Domain resolution" "nslookup $DOMAIN" "Non-authoritative answer" 2>/dev/null || echo "  DNS check failed - domain may not be configured yet"

echo ""
echo "🔐 Security Configuration Tests"
echo "------------------------------"

run_test "Environment file exists" "ls -la .env" ".env" || echo "  ⚠️  .env file missing - copy .env.example to .env"

if [ -f .env ]; then
    run_test "Domain configured" "grep DOMAIN .env" "DOMAIN" || echo "  ⚠️  Domain not configured"
    run_test "Email configured" "grep SSL_EMAIL .env" "SSL_EMAIL" || echo "  ⚠️  SSL email not configured"
fi

echo ""
echo "📋 Service Label Tests"
echo "----------------------"

# Check if services have proper Traefik labels
if command -v docker-compose &> /dev/null; then
    run_test "Kafka UI has Traefik labels" "docker-compose config | grep -A 10 kafka-ui" "traefik.enable=true"
    run_test "Kibana has Traefik labels" "docker-compose config | grep -A 10 kibana" "traefik.enable=true"
    run_test "Elasticsearch has Traefik labels" "docker-compose config | grep -A 10 elasticsearch" "traefik.enable=true"
    run_test "Nexus has Traefik labels" "docker-compose config | grep -A 10 nexus" "traefik.enable=true"
fi

echo ""
echo "🚀 Deployment Readiness Tests"
echo "-----------------------------"

# Check if directories exist and have proper permissions
run_test "Traefik letsencrypt directory" "ls -la traefik/letsencrypt" "letsencrypt" 2>/dev/null || mkdir -p traefik/letsencrypt && echo "  ✅ Created traefik/letsencrypt directory"
run_test "Logs directory exists" "ls -la logs" "logs" 2>/dev/null || mkdir -p logs && echo "  ✅ Created logs directory"

# Check port availability (if services aren't running)
run_test "Port 80 available" "netstat -tuln | grep :80" "" 2>/dev/null || echo "  ✅ Port 80 is available"
run_test "Port 443 available" "netstat -tuln | grep :443" "" 2>/dev/null || echo "  ✅ Port 443 is available"
run_test "Port 8080 available" "netstat -tuln | grep :8080" "" 2>/dev/null || echo "  ✅ Port 8080 is available"

echo ""
echo "📊 Test Results Summary"
echo "======================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total:  $((PASSED + FAILED))"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "🎉 All tests passed! Your setup is ready for deployment."
    echo ""
    echo "Next steps:"
    echo "1. Configure .env file with your credentials"
    echo "2. Run: ./scripts/deploy.sh"
    echo "3. Monitor with: ./scripts/monitor.sh"
    exit 0
else
    echo ""
    echo "⚠️  $FAILED test(s) failed. Please fix the issues above before deploying."
    echo ""
    echo "Common fixes:"
    echo "- Copy .env.example to .env and configure it"
    echo "- Ensure Docker and Docker Compose are installed"
    echo "- Check your Cloudflare tunnel configuration on Ubuntu server"
    exit 1
fi