#!/bin/bash

# Nginx Local Setup Script for Ubuntu
# This script installs and configures Nginx locally to replace Docker container

set -e

echo "🚀 Starting Nginx local setup for Ubuntu..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons."
   print_error "Please run as a regular user with sudo privileges."
   exit 1
fi

# Update package list
print_status "Updating package list..."
sudo apt update

# Install Nginx
print_status "Installing Nginx..."
sudo apt install -y nginx

# Install additional tools
print_status "Installing additional tools..."
sudo apt install -y apache2-utils curl htop

# Create necessary directories
print_status "Creating Nginx directories..."
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/log/nginx
sudo mkdir -p /etc/nginx/ssl

# Set proper permissions
sudo chown -R www-data:www-data /var/log/nginx
sudo chmod 755 /etc/nginx/conf.d

# Backup original Nginx configuration
print_status "Backing up original Nginx configuration..."
if [ -f /etc/nginx/nginx.conf ]; then
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Stop Nginx service if running
print_status "Stopping Nginx service..."
sudo systemctl stop nginx || true
sudo systemctl disable nginx || true

# Create systemd service override for custom configuration
print_status "Creating systemd service override..."
sudo mkdir -p /etc/systemd/system/nginx.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/nginx.service.d/override.conf
[Service]
Restart=always
RestartSec=5
LimitNOFILE=65536
EOF

# Reload systemd
sudo systemctl daemon-reload

print_status "Nginx installation completed successfully!"
print_status "Next steps:"
echo "  1. Copy your custom nginx.conf to /etc/nginx/nginx.conf"
echo "  2. Copy your conf.d files to /etc/nginx/conf.d/"
echo "  3. Test configuration: sudo nginx -t"
echo "  4. Start Nginx: sudo systemctl start nginx"
echo "  5. Enable Nginx: sudo systemctl enable nginx"

print_warning "Make sure to update your Docker containers to not expose the same ports"
print_warning "or stop the Docker Nginx container before starting the local Nginx service."