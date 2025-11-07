#!/bin/bash

# Nginx Management Script
# Easy management for local Nginx installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Show usage
show_usage() {
    echo "Nginx Manager - Local Nginx Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start Nginx service"
    echo "  stop        Stop Nginx service"
    echo "  restart     Restart Nginx service"
    echo "  reload      Reload Nginx configuration (graceful restart)"
    echo "  status      Show Nginx service status"
    echo "  config      Test Nginx configuration"
    echo "  logs        Show Nginx logs (last 50 lines)"
    echo "  logs-full   Show full Nginx logs"
    echo "  edit        Edit main Nginx configuration"
    echo "  edit-conf   Edit configuration files in conf.d"
    echo "  backup      Backup current configuration"
    echo "  restore     Restore configuration from backup"
    echo "  install     Install Nginx (runs install script)"
    echo "  setup       Setup configuration (runs setup script)"
    echo "  version     Show Nginx version"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start    # Start Nginx"
    echo "  $0 reload   # Reload configuration"
    echo "  $0 logs     # View recent logs"
}

# Check if running as root for operations that need it
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "This operation requires sudo privileges. Running with sudo..."
        exec sudo "$0" "$@"
    fi
}

# Start Nginx
nginx_start() {
    print_header "Starting Nginx"
    check_sudo "$@"
    sudo systemctl start nginx
    sleep 2
    if sudo systemctl is-active --quiet nginx; then
        print_status "✅ Nginx started successfully!"
        show_status
    else
        print_error "❌ Failed to start Nginx!"
        print_error "Check logs with: $0 logs"
        exit 1
    fi
}

# Stop Nginx
nginx_stop() {
    print_header "Stopping Nginx"
    check_sudo "$@"
    sudo systemctl stop nginx
    if ! sudo systemctl is-active --quiet nginx; then
        print_status "✅ Nginx stopped successfully!"
    else
        print_error "❌ Failed to stop Nginx!"
        exit 1
    fi
}

# Restart Nginx
nginx_restart() {
    print_header "Restarting Nginx"
    check_sudo "$@"
    sudo systemctl restart nginx
    sleep 2
    if sudo systemctl is-active --quiet nginx; then
        print_status "✅ Nginx restarted successfully!"
        show_status
    else
        print_error "❌ Failed to restart Nginx!"
        exit 1
    fi
}

# Reload Nginx configuration
nginx_reload() {
    print_header "Reloading Nginx Configuration"
    check_sudo "$@"

    # Test configuration first
    print_status "Testing configuration..."
    if sudo nginx -t; then
        sudo systemctl reload nginx
        print_status "✅ Nginx configuration reloaded successfully!"
    else
        print_error "❌ Configuration test failed! Reload aborted."
        exit 1
    fi
}

# Show Nginx status
show_status() {
    print_header "Nginx Status"
    echo "Service Status:"
    sudo systemctl status nginx --no-pager -l
    echo ""
    echo "Active Connections:"
    sudo ss -tnp state established '( dport = :http or sport = :http )' 2>/dev/null || echo "No active HTTP connections"
    echo ""
    echo "Nginx Version:"
    nginx -v 2>&1
}

# Test Nginx configuration
nginx_config_test() {
    print_header "Testing Nginx Configuration"
    sudo nginx -t
    if [ $? -eq 0 ]; then
        print_status "✅ Configuration is valid!"
    else
        print_error "❌ Configuration has errors!"
        exit 1
    fi
}

# Show Nginx logs
show_logs() {
    local lines=${1:-50}
    print_header "Nginx Logs (Last $lines lines)"
    echo "Access Log:"
    echo "-----------"
    sudo tail -n $lines /var/log/nginx/access.log 2>/dev/null || echo "No access log found"
    echo ""
    echo "Error Log:"
    echo "----------"
    sudo tail -n $lines /var/log/nginx/error.log 2>/dev/null || echo "No error log found"
}

# Show full logs
show_full_logs() {
    print_header "Nginx Full Logs"
    echo "Access Log:"
    echo "-----------"
    sudo cat /var/log/nginx/access.log 2>/dev/null || echo "No access log found"
    echo ""
    echo "Error Log:"
    echo "----------"
    sudo cat /var/log/nginx/error.log 2>/dev/null || echo "No error log found"
}

# Edit configuration
edit_config() {
    print_header "Editing Nginx Configuration"
    check_sudo "$@"

    echo "Select configuration to edit:"
    echo "1) Main configuration (/etc/nginx/nginx.conf)"
    echo "2) Configuration files in conf.d/"
    echo "3) Choose specific file in conf.d/"

    read -p "Enter choice (1-3): " choice

    case $choice in
        1)
            sudo ${EDITOR:-nano} /etc/nginx/nginx.conf
            ;;
        2)
            sudo ${EDITOR:-nano} /etc/nginx/conf.d/
            ;;
        3)
            echo "Available files in conf.d/:"
            ls -la /etc/nginx/conf.d/
            read -p "Enter filename: " filename
            sudo ${EDITOR:-nano} "/etc/nginx/conf.d/$filename"
            ;;
        *)
            print_error "Invalid choice!"
            exit 1
            ;;
    esac

    print_status "Configuration edited. Test with: $0 config"
    print_status "Reload with: $0 reload"
}

# Backup configuration
backup_config() {
    print_header "Backing Up Nginx Configuration"
    check_sudo "$@"

    local backup_dir="/etc/nginx/backup.$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$backup_dir"

    print_status "Creating backup in $backup_dir..."

    # Backup main config
    sudo cp /etc/nginx/nginx.conf "$backup_dir/" 2>/dev/null || true

    # Backup conf.d files
    sudo cp -r /etc/nginx/conf.d "$backup_dir/" 2>/dev/null || true

    # Backup SSL files
    sudo cp -r /etc/nginx/ssl "$backup_dir/" 2>/dev/null || true

    print_status "✅ Configuration backed up to $backup_dir"
}

# Restore configuration
restore_config() {
    print_header "Restoring Nginx Configuration"
    check_sudo "$@"

    echo "Available backups:"
    sudo ls -la /etc/nginx/backup.* 2>/dev/null || echo "No backups found"

    read -p "Enter backup directory name (e.g., backup.20231107_123000): " backup_name

    if [ -d "/etc/nginx/$backup_name" ]; then
        print_status "Restoring from /etc/nginx/$backup_name..."

        # Restore main config
        sudo cp "/etc/nginx/$backup_name/nginx.conf" /etc/nginx/ 2>/dev/null || true

        # Restore conf.d files
        sudo cp -r "/etc/nginx/$backup_name/conf.d/"* /etc/nginx/conf.d/ 2>/dev/null || true

        # Restore SSL files
        sudo cp -r "/etc/nginx/$backup_name/ssl/"* /etc/nginx/ssl/ 2>/dev/null || true

        print_status "✅ Configuration restored!"
        print_status "Test with: $0 config"
        print_status "Reload with: $0 reload"
    else
        print_error "Backup directory not found: /etc/nginx/$backup_name"
        exit 1
    fi
}

# Show Nginx version
show_version() {
    print_header "Nginx Version"
    nginx -v 2>&1
    echo ""
    echo "Configuration:"
    nginx -V 2>&1 | grep -E "(configure arguments:|with-)" || echo "No special configuration options"
}

# Install Nginx
install_nginx() {
    print_header "Installing Nginx"
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

    if [ -f "$SCRIPT_DIR/install-nginx-ubuntu.sh" ]; then
        "$SCRIPT_DIR/install-nginx-ubuntu.sh"
    else
        print_error "Installation script not found!"
        print_error "Please ensure install-nginx-ubuntu.sh is in the same directory."
        exit 1
    fi
}

# Setup configuration
setup_config() {
    print_header "Setting Up Configuration"
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

    if [ -f "$SCRIPT_DIR/setup-nginx-config.sh" ]; then
        "$SCRIPT_DIR/setup-nginx-config.sh"
    else
        print_error "Setup script not found!"
        print_error "Please ensure setup-nginx-config.sh is in the same directory."
        exit 1
    fi
}

# Main script logic
case "${1:-help}" in
    start)
        nginx_start "$@"
        ;;
    stop)
        nginx_stop "$@"
        ;;
    restart)
        nginx_restart "$@"
        ;;
    reload)
        nginx_reload "$@"
        ;;
    status)
        show_status
        ;;
    config)
        nginx_config_test
        ;;
    logs)
        show_logs "${2:-50}"
        ;;
    logs-full)
        show_full_logs
        ;;
    edit)
        edit_config
        ;;
    backup)
        backup_config
        ;;
    restore)
        restore_config
        ;;
    install)
        install_nginx
        ;;
    setup)
        setup_config
        ;;
    version)
        show_version
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac