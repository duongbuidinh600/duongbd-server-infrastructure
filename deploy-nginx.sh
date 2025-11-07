#!/bin/bash

# Nginx Deployment Script (for existing cloudflared setup)
# Usage: ./deploy-nginx.sh [--dry-run] [--force] [--help]

set -euo pipefail

# Configuration
CLOUDFLARED_CONFIG="tunnel.yml"
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
    if ! command_exists docker compose && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check if Nginx config exists
    if [[ ! -f "nginx/nginx.conf" ]]; then
        log_error "Nginx configuration file 'nginx/nginx.conf' not found"
        exit 1
    fi

    # Check if cloudflared config exists (for validation only)
    if [[ ! -f "$CLOUDFLARED_CONFIG" ]]; then
        log_error "Cloudflared config file '$CLOUDFLARED_CONFIG' not found"
        exit 1
    fi

    log_success "All prerequisites passed"
    log_info "Note: Assuming cloudflared is already installed and running on this server"
}

# Function to test configuration
test_config() {
    log_info "Testing configuration files..."

    # Validate Docker Compose file
    if docker compose -f "$DOCKER_COMPOSE" config >/dev/null 2>&1; then
        log_success "Docker Compose configuration is valid"
    else
        log_error "Docker Compose configuration has errors"
        exit 1
    fi

    # Validate cloudflared config (optional, for validation only)
    if command_exists cloudflared; then
        if cloudflared tunnel ingress validate "$CLOUDFLARED_CONFIG" >/dev/null 2>&1; then
            log_success "Cloudflared configuration is valid"
        else
            log_warning "Cloudflared configuration has validation warnings (may still work)"
        fi
    else
        log_info "Skipping cloudflared validation (cloudflared not found locally)"
    fi
}

# Function to deploy services
deploy_services() {
    local dry_run="${1:-false}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY RUN: Would deploy Docker services with:"
        echo "  - Docker Compose: $DOCKER_COMPOSE"
        echo "  - Cloudflared Config: $CLOUDFLARED_CONFIG (for manual update)"
        echo
        echo "Manual steps required:"
        echo "1. Update cloudflared tunnel config: sudo cp $CLOUDFLARED_CONFIG /path/to/tunnel.yml"
        echo "2. Restart cloudflared: sudo systemctl restart cloudflared"
        return 0
    fi

    log_info "Deploying Nginx and services..."

    # Deploy Docker services
    log_info "Starting Docker services..."
    docker compose down
    docker compose up -d --force-recreate

    # Wait for Nginx to be ready
    log_info "Waiting for Nginx to start..."
    sleep 10

    # Check if Nginx is running
    if docker ps | grep -q "nginx"; then
        log_success "Nginx is running"
    else
        log_error "Nginx failed to start"
        docker compose logs nginx
        exit 1
    fi

    log_warning "Note: cloudflared tunnel management is handled separately"
    log_info "Update your cloudflared config and restart the service manually"
}

# Function to run health checks
health_check() {
    log_info "Running health checks..."

    # Check Nginx health
    if curl -f http://localhost/nginx-health >/dev/null 2>&1; then
        log_success "Nginx is healthy"
    else
        log_warning "Nginx health check failed"
    fi

    # Check Nginx dashboard
    if curl -f http://localhost/nginx-status >/dev/null 2>&1; then
        log_success "Nginx dashboard is accessible"
    else
        log_warning "Nginx dashboard is not accessible"
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
    log_success "Docker deployment completed successfully!"
    echo
    echo "🎯 Next Steps Required:"
    echo "1. Update cloudflared tunnel configuration:"
    echo "   sudo cp $CLOUDFLARED_CONFIG /path/to/your/tunnel.yml"
    echo "   sudo systemctl restart cloudflared"
    echo
    echo "2. Access Information:"
    echo "   Nginx Dashboard (local): http://localhost/nginx-status"
    echo "   Nginx Dashboard (remote): https://nginx.duongbd.site"
    echo "   Nginx Health: http://localhost/nginx-health"
    echo
    echo "📊 Services (after cloudflared update):"
    echo "   Kafka UI:           https://kafka.duongbd.site (user: kafka, pass: password123)"
    echo "   Redis Commander:    https://redis.duongbd.site (user: redis, pass: password123)"
    echo "   MySQL Adminer:      https://mysql.duongbd.site (user: admin, pass: admin123)"
    echo "   Elasticsearch:      https://es.duongbd.site (user: elastic, pass: password123)"
    echo "   Kibana:             https://kibana.duongbd.site"
    echo "   Nexus Repository:   https://nexus.duongbd.site"
    echo
    echo "🔧 Docker Management:"
    echo "   View logs: docker compose logs -f [service-name]"
    echo "   Stop all: docker compose down"
    echo "   Restart: docker compose restart [service-name]"
    echo "   Test Nginx config: docker exec nginx nginx -t"
    echo "   Reload Nginx: docker exec nginx nginx -s reload"
    echo
    echo "🔧 Cloudflared Management:"
    echo "   Status: sudo systemctl status cloudflared"
    echo "   Logs: sudo journalctl -u cloudflared -f"
    echo "   Restart: sudo systemctl restart cloudflared"
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
                echo "Nginx Deployment Script (for existing cloudflared setup)"
                echo "Usage: $0 [--dry-run] [--force] [--help]"
                echo
                echo "Options:"
                echo "  --dry-run: Show what would be done without executing"
                echo "  --force:   Skip confirmation prompts and backups"
                echo "  --help:    Show this help message"
                echo
                echo "This script deploys Nginx and Docker services only."
                echo "Cloudflared tunnel management must be done manually."
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    log_info "Starting Nginx deployment (for existing cloudflared setup)..."

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