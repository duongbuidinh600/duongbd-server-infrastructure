#!/bin/bash

# SSL Certificate Setup Script for duongbd.site
# This script helps you obtain Let's Encrypt SSL certificates for your domains

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSL Certificate Setup for duongbd.site${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed${NC}"
    exit 1
fi

# Domain configuration
DOMAINS=(
    "kafka.duongbd.site"
    "kibana.duongbd.site"
    "es.duongbd.site"
)

EMAIL=""

# Prompt for email
echo -e "${YELLOW}Enter your email address for Let's Encrypt notifications:${NC}"
read -p "Email: " EMAIL

if [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: Email is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}The following domains will be configured:${NC}"
for domain in "${DOMAINS[@]}"; do
    echo "  - $domain"
done
echo ""

echo -e "${YELLOW}Prerequisites checklist:${NC}"
echo "  1. DNS A records are configured and pointing to this server's IP"
echo "  2. Ports 80 and 443 are open in your firewall"
echo "  3. No other services are using ports 80/443"
echo ""

read -p "Have you completed the prerequisites? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Aborting. Please complete the prerequisites first.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Starting certificate generation...${NC}"
echo ""

# Create necessary directories
mkdir -p ./certbot/conf
mkdir -p ./certbot/www

# Start nginx temporarily for certificate validation
echo -e "${YELLOW}Starting Nginx for certificate validation...${NC}"

# Create temporary nginx config for HTTP only
cat > ./nginx/conf.d/temp-certbot.conf << 'EOF'
server {
    listen 80;
    server_name kafka.duongbd.site kibana.duongbd.site es.duongbd.site;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Start nginx
docker-compose up -d nginx

echo -e "${YELLOW}Waiting for Nginx to start...${NC}"
sleep 5

# Request certificates for each domain
for domain in "${DOMAINS[@]}"; do
    echo ""
    echo -e "${GREEN}Requesting certificate for $domain...${NC}"

    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d $domain

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Certificate obtained for $domain${NC}"
    else
        echo -e "${RED}✗ Failed to obtain certificate for $domain${NC}"
        echo -e "${RED}Please check:${NC}"
        echo -e "${RED}  - DNS records are correctly configured${NC}"
        echo -e "${RED}  - Firewall allows incoming connections on port 80${NC}"
        echo -e "${RED}  - Domain is accessible from the internet${NC}"
        exit 1
    fi
done

# Remove temporary config
rm -f ./nginx/conf.d/temp-certbot.conf

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSL certificates successfully obtained!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Update nginx/allowed-ips.conf with your allowed IP addresses"
echo "  2. Restart all services: docker-compose down && docker-compose up -d"
echo "  3. Verify HTTPS access to your domains:"
echo "     - https://kafka.duongbd.site"
echo "     - https://kibana.duongbd.site"
echo "     - https://es.duongbd.site"
echo ""
echo -e "${YELLOW}Certificate auto-renewal:${NC}"
echo "  Certificates will be automatically renewed by the certbot container."
echo "  It checks for renewal twice daily."
echo ""
echo -e "${GREEN}Setup complete!${NC}"
