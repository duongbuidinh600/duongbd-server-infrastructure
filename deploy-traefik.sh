#!/bin/bash

# Traefik + Cloudflared Deployment Script
# Usage: ./deploy-traefik.sh [--dry-run] [--force]

set -euo pipefail

# Configuration
CLOUDFLARED_CONFIG="tunnel-traefik.yml"
LEGACY_CONFIG="tunnel.yml"
DOCKER_COMPOSE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to backup existing configuration
backup_config() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    if [[ -f "$LEGACY_CONFIG" ]]; then
        cp "$LEGACY_CONFIG" "$backup_dir/"
        log_info "Backed up $LEGACY_CONFIG to $backup_dir/"
    fi

    if [[ -f "$DOCKER_COMPOSE" ]]; then
        cp "$DOCKER_COMPOSE" "$backup_dir/"
        log_info "Backed up $DOCKER_COMPOSE to $backup_dir/"
    fi

    echo "$backup_dir"
}

# Function to validate Docker network
validate_network() {
    log_info "Validating Docker network 'scangoo-network'..."

    if ! docker network ls | grep -q "scangoo-network"; then
        log_warning "Docker network 'scangoo-network' not found. Creating it..."
        docker network create scangoo-network --driver bridge
        log_success "Created Docker network 'scangoo-network'"
    else
        log_success "Docker network 'scangoo-network' exists"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command_exists docker; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    # Check Docker Compose
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check cloudflared
    if ! command_exists cloudflared; then
        log_error "cloudflared is not installed. Install it from https://github.com/cloudflare/cloudflared"
        exit 1
    fi

    # Check if cloudflared config exists
    if [[ ! -f "$CLOUDFLARED_CONFIG" ]]; then
        log_error "Cloudflared config file '$CLOUDFLARED_CONFIG' not found"
        exit 1
    fi

    # Check if Traefik config exists
    if [[ ! -f "traefik/traefik.yml" ]]; then
        log_error "Traefik configuration file 'traefik/traefik.yml' not found"
        exit 1
    fi

    log_success "All prerequisites passed"
}

# Function to test configuration
test_config() {
    log_info "Testing configuration files..."

    # Validate Docker Compose file
    if docker-compose -f "$DOCKER_COMPOSE" config >/dev/null 2>&1; then
        log_success "Docker Compose configuration is valid"
    else
        log_error "Docker Compose configuration has errors"
        exit 1
    fi

    # Validate cloudflared config
    if cloudflared tunnel ingress validate "$CLOUDFLARED_CONFIG" >/dev/null 2>&1; then
        log_success "Cloudflared configuration is valid"
    else
        log_error "Cloudflared configuration has errors"
        exit 1
    fi
}

# Function to deploy services
deploy_services() {
    local dry_run="${1:-false}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY RUN: Would deploy services with:"
        echo "  - Docker Compose: $DOCKER_COMPOSE"
        echo "  - Cloudflared Config: $CLOUDFLARED_CONFIG"
        return 0
    fi

    log_info "Deploying Traefik and services..."

    # Stop existing cloudflared tunnel
    log_info "Stopping existing cloudflared tunnel..."
    pkill -f "cloudflared tunnel" || true

    # Deploy Docker services
    log_info "Starting Docker services..."
    docker-compose down
    docker-compose up -d --force-recreate

    # Wait for Traefik to be ready
    log_info "Waiting for Traefik to start..."
    sleep 10

    # Check if Traefik is running
    if docker ps | grep -q "traefik"; then
        log_success "Traefik is running"
    else
        log_error "Traefik failed to start"
        docker-compose logs traefik
        exit 1
    fi

    # Start cloudflared tunnel
    log_info "Starting cloudflared tunnel..."
    nohup cloudflared tunnel --config "$CLOUDFLARED_CONFIG" run >/var/log/cloudflared.log 2>&1 &

    # Wait for cloudflared to start
    sleep 5

    # Check if cloudflared is running
    if pgrep -f "cloudflared tunnel" >/dev/null; then
        log_success "Cloudflared tunnel is running"
    else
        log_error "Cloudflared tunnel failed to start"
        tail /var/log/cloudflared.log
        exit 1
    fi
}

# Function to run health checks
health_check() {
    log_info "Running health checks..."

    # Check Traefik health
    if curl -f http://localhost:8082/ping >/dev/null 2>&1; then
        log_success "Traefik dashboard is accessible"
    else
        log_warning "Traefik dashboard is not accessible"
    fi

    # Check service routing (basic checks)
    local services=("kafka.duongbd.site" "redis.duongbd.site" "mysql.duongbd.site" "kibana.duongbd.site" "es.duongbd.site" "nexus.duongbd.site")

    for service in "${services[@]}"; do
        log_info "Testing $service..."
        if timeout 10 curl -f -s "https://$service" >/dev/null 2>&1; then
            log_success "$service is accessible"
        else
            log_warning "$service is not accessible (may still be starting)"
        fi
    done
}

# Function to show access information
show_access_info() {
    log_success "Deployment completed successfully!"
    echo
    echo "🎯 Access Information:"
    echo "  Traefik Dashboard (local): http://localhost:8082/dashboard/"
    echo "  Traefik Dashboard (remote): https://traefik.duongbd.site/dashboard/"
    echo
    echo "📊 Services:"
    echo "  Kafka UI:           https://kafka.duongbd.site (user: kafka, pass: password123)"
    echo "  Redis Commander:    https://redis.duongbd.site (user: redis, pass: password123)"
    echo "  MySQL Adminer:      https://mysql.duongbd.site (user: admin, pass: admin123)"
    echo "  Elasticsearch:      https://es.duongbd.site (user: elastic, pass: password123)"
    echo "  Kibana:             https://kibana.duongbd.site"
    echo "  Nexus Repository:   https://nexus.duongbd.site"
    echo
    echo "🔧 Management:"
    echo "  View logs: docker-compose logs -f [service-name]"
    echo "  Stop all: docker-compose down"
    echo "  Restart: docker-compose restart [service-name]"
    echo
}

# Main function
main() {
    local dry_run=false
    local force=false
    local backup_dir=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--dry-run] [--force] [--help]"
                echo "  --dry-run: Show what would be done without executing"
                echo "  --force:   Skip confirmation prompts"
                echo "  --help:    Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    log_info "Starting Traefik + Cloudflared deployment..."

    # Check prerequisites
    check_prerequisites

    # Validate Docker network
    validate_network

    # Test configuration
    test_config

    # Backup existing configuration
    if [[ "$force" != "true" ]]; then
        backup_dir=$(backup_config)
        log_info "Configuration backed up to: $backup_dir"
    fi

    # Deploy services
    deploy_services "$dry_run"

    if [[ "$dry_run" != "true" ]]; then
        # Run health checks
        health_check

        # Show access information
        show_access_info
    fi
}

# Run main function with all arguments
main "$@"