#!/bin/bash

# Nginx Configuration Setup Script
# This script copies and adapts the Docker Nginx configuration for local Nginx

set -e

echo "🔧 Setting up Nginx configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    print_error "Nginx is not installed. Please run install-nginx-ubuntu.sh first."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
NGINX_DIR="$SCRIPT_DIR/nginx"

# Check if nginx directory exists
if [ ! -d "$NGINX_DIR" ]; then
    print_error "Nginx configuration directory not found: $NGINX_DIR"
    exit 1
fi

# Backup current configuration
print_status "Backing up current Nginx configuration..."
sudo mkdir -p /etc/nginx/backup.$(date +%Y%m%d_%H%M%S)
if [ -f /etc/nginx/nginx.conf ]; then
    sudo cp /etc/nginx/nginx.conf /etc/nginx/backup.$(date +%Y%m%d_%H%M%S)/nginx.conf
fi
if [ -d /etc/nginx/conf.d ]; then
    sudo cp -r /etc/nginx/conf.d/* /etc/nginx/backup.$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
fi

# Copy main configuration
print_status "Copying main Nginx configuration..."
sudo cp "$NGINX_DIR/nginx.conf" /etc/nginx/nginx.conf

# Copy conf.d files
print_status "Copying configuration files..."
sudo cp -r "$NGINX_DIR/conf.d/"* /etc/nginx/conf.d/

# Copy SSL certificates if they exist
if [ -d "$NGINX_DIR/ssl" ]; then
    print_status "Copying SSL certificates..."
    sudo cp -r "$NGINX_DIR/ssl/"* /etc/nginx/ssl/
    sudo chmod 600 /etc/nginx/ssl/*.key 2>/dev/null || true
    sudo chmod 644 /etc/nginx/ssl/*.crt 2>/dev/null || true
fi

# Create log directories
print_status "Setting up log directories..."
sudo mkdir -p /var/log/nginx
sudo chown www-data:www-data /var/log/nginx

# Create htpasswd files directory
sudo mkdir -p /etc/nginx

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if sudo nginx -t; then
    print_status "✅ Nginx configuration test passed!"
else
    print_error "❌ Nginx configuration test failed!"
    print_error "Please check the configuration files and fix any errors."
    exit 1
fi

# Create a script to update Docker containers to avoid port conflicts
print_status "Creating Docker port management script..."
cat << 'EOF' > "$SCRIPT_DIR/manage-docker-ports.sh"
#!/bin/bash

# Docker Port Management Script
# This script helps manage Docker containers to avoid port conflicts with local Nginx

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🐳 Docker Port Management for Local Nginx Setup"
echo "==============================================="

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    exit 1
fi

print_status "Current Docker containers:"
docker ps --format "table {{.Names}}\t{{.Ports}}"

echo ""
print_warning "To avoid port conflicts with local Nginx, consider the following:"
echo "1. Stop the Nginx container: docker stop nginx"
echo "2. Or update docker-compose.yml to remove port 80 mapping"
echo "3. Or change Nginx to use a different port (e.g., 8080)"

echo ""
print_status "Commands to manage Docker containers:"
echo "Stop Nginx container:     docker stop nginx || true"
echo "Stop all containers:      docker-compose down"
echo "Start without Nginx:      docker-compose up -d --scale nginx=0"

echo ""
read -p "Do you want to stop the Nginx container now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker stop nginx || true
    print_status "Nginx container stopped."
fi
EOF

chmod +x "$SCRIPT_DIR/manage-docker-ports.sh"

print_status "Configuration setup completed!"
echo ""
print_status "Next steps:"
echo "1. Test configuration: sudo nginx -t"
echo "2. Start Nginx: sudo systemctl start nginx"
echo "3. Enable Nginx: sudo systemctl enable nginx"
echo "4. Check status: sudo systemctl status nginx"
echo "5. Manage Docker ports: ./manage-docker-ports.sh"
echo ""
print_warning "Remember to handle Docker port conflicts before starting Nginx!"