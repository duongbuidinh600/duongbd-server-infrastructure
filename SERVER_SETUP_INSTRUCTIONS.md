# Server Setup Instructions

## Overview

This guide provides step-by-step instructions to deploy a complete infrastructure stack with Kafka, Redis, MySQL, Elasticsearch, Kibana, and Nginx with SSL/TLS encryption on Ubuntu Server.

## Prerequisites

### Hardware Requirements
- **CPU**: Intel i5 8850H (6 cores / 12 threads) or equivalent
- **RAM**: 16GB minimum (8GB for basic usage, 32GB+ for production)
- **Storage**: 50GB+ free disk space
- **OS**: Ubuntu Server 20.04+ or similar

### Domain Requirements
- Domain name (e.g., `your-domain.com`)
- Ability to create DNS A records
- Domain pointing to your server's public IP address

## Installation Steps

### 1. Server Setup

#### 1.1 Update System
```bash
sudo apt update && sudo apt upgrade -y
```

#### 1.2 Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Apply group membership changes
newgrp docker
```

#### 1.3 Install Docker Compose
```bash
sudo apt-get update
sudo apt-get install docker-compose-plugin -y
```

#### 1.4 Configure System Limits for Elasticsearch
```bash
# Increase virtual memory limit
sudo sysctl -w vm.max_map_count=262144

# Make it permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

#### 1.5 Configure Firewall
```bash
# Allow essential ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (for Let's Encrypt)
sudo ufw allow 443/tcp   # HTTPS

# Allow application ports
sudo ufw allow 9092/tcp  # Kafka
sudo ufw allow 3306/tcp  # MySQL
sudo ufw allow 6379/tcp  # Redis

# Enable firewall
sudo ufw --force enable
```

### 2. Domain Configuration

#### 2.1 Create DNS Records
Create the following A records pointing to your server's public IP:

| Subdomain | Purpose |
|-----------|---------|
| `kafka.your-domain.com` | Kafka UI web interface |
| `kibana.your-domain.com` | Kibana web interface |
| `es.your-domain.com` | Elasticsearch API |
| `your-domain.com` | Base domain (optional) |

#### 2.2 Verify DNS Propagation
```bash
# Test DNS resolution
nslookup kafka.your-domain.com
nslookup kibana.your-domain.com
nslookup es.your-domain.com

# Or use dig for more detailed info
dig +short kafka.your-domain.com
```

**Wait for DNS propagation** (typically 5-30 minutes, can take up to 24 hours).

### 3. Project Deployment

#### 3.1 Clone or Download Project Files
```bash
# Option A: If using Git
git clone <your-repo-url> your-infrastructure
cd your-infrastructure

# Option B: If downloading files
# Create project directory and upload all files including:
# - docker-compose.yml
# - nginx/ directory and its contents
# - setup-ssl.sh
# - .env.example
```

#### 3.2 Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

**Update the following values in `.env`:**
```bash
DOMAIN=your-domain.com
KAFKA_UI_SUBDOMAIN=kafka.your-domain.com
KIBANA_SUBDOMAIN=kibana.your-domain.com
ELASTICSEARCH_SUBDOMAIN=es.your-domain.com
LETSENCRYPT_EMAIL=your-email@example.com
SERVER_IP=YOUR_SERVER_PUBLIC_IP
```

#### 3.3 Configure IP Whitelist
```bash
# Edit IP whitelist configuration
nano nginx/allowed-ips.conf
```

**Add your IP addresses:**
```nginx
# Local access
allow 127.0.0.1;

# Your current IP (find it with: curl ifconfig.me)
allow YOUR_IP_ADDRESS;

# Your office network (optional)
allow 192.168.1.0/24;

# Additional IPs as needed
# allow 203.0.113.42;
```

**Find your current IP:**
```bash
curl ifconfig.me
```

### 4. Service Deployment

#### 4.1 Phase 1: Start Core Services
```bash
# Start services without Nginx first
docker-compose up -d zookeeper kafka kafka-ui redis mysql elasticsearch kibana
```

#### 4.2 Verify Core Services
```bash
# Check container status
docker-compose ps

# View logs if needed
docker-compose logs -f
```

Wait 2-3 minutes for services to fully initialize.

#### 4.3 Phase 2: SSL Certificate Setup
```bash
# Make SSL setup script executable
chmod +x setup-ssl.sh

# Run SSL setup
./setup-ssl.sh
```

**The SSL script will:**
1. Prompt for your email address
2. Verify prerequisites
3. Start Nginx temporarily
4. Request SSL certificates for all subdomains
5. Configure automatic renewal

**Important:** Ensure DNS records are configured and propagated before running this script.

#### 4.4 Phase 3: Start All Services
```bash
# Stop all services
docker-compose down

# Start complete stack including Nginx with SSL
docker-compose up -d
```

### 5. Verification and Testing

#### 5.1 Check Service Status
```bash
# Verify all containers are running
docker-compose ps

# Check health status
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

#### 5.2 Test HTTPS Access
```bash
# Test web interfaces
curl -I https://kafka.your-domain.com
curl -I https://kibana.your-domain.com
curl https://es.your-domain.com/_cluster/health?pretty
```

#### 5.3 Test Direct Service Connections
```bash
# Test Kafka
telnet your-domain.com 9092

# Test MySQL
mysql -h your-domain.com -P 3306 -u root -prootpassword -e "SELECT VERSION();"

# Test Redis
redis-cli -h your-domain.com -p 6379 ping
```

#### 5.4 Web Interface Access
Open in your browser:
- **Kafka UI**: `https://kafka.your-domain.com`
- **Kibana**: `https://kibana.your-domain.com`
- **Elasticsearch**: `https://es.your-domain.com`

## Service Configuration Details

### Kafka Configuration
- **Bootstrap Server**: `your-domain.com:9092`
- **Internal Access**: `kafka:29092` (within Docker network)
- **Auto-create Topics**: Enabled
- **Replication Factor**: 1 (single broker)
- **Memory**: 3GB allocated (2GB heap)

### MySQL Configuration
- **Host**: `your-domain.com:3306`
- **Root Password**: `rootpassword` (change in production)
- **Database**: `mydb`
- **User**: `dbuser` / `dbpassword`
- **Memory**: 3GB allocated
- **Connection Pool**: 200 max connections

### Redis Configuration
- **Host**: `your-domain.com:6379`
- **Max Memory**: 1GB with LRU eviction
- **Persistence**: AOF enabled
- **Memory**: 1GB allocated

### Elasticsearch Configuration
- **URL**: `https://es.your-domain.com`
- **Cluster Name**: `es-cluster`
- **Heap Size**: 2GB
- **Security**: IP whitelist enforced via Nginx

### Kibana Configuration
- **URL**: `https://kibana.your-domain.com`
- **Elasticsearch Host**: `http://elasticsearch:9200`
- **Security**: IP whitelist enforced via Nginx

## Management Commands

### Service Operations
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart kafka
docker-compose restart nginx

# View logs
docker-compose logs -f
docker-compose logs -f kafka
```

### Resource Monitoring
```bash
# View resource usage
docker stats

# View disk usage
docker system df

# Clean up unused resources
docker system prune -a
```

### Backup Operations
```bash
# MySQL backup
docker exec mysql mysqldump -u root -prootpassword mydb > backup_$(date +%Y%m%d).sql

# Redis backup
docker exec redis redis-cli SAVE
docker cp redis:/data/dump.rdb ./redis_backup_$(date +%Y%m%d).rdb
```

## Security Configuration

### SSL/TLS Management
- **Certificates**: Automatically renewed by Certbot
- **TLS Version**: TLS 1.2+ enforced
- **HSTS**: Enabled for secure connections
- **Certificate Validity**: 90 days (auto-renewed)

### IP Whitelist Management
```bash
# Add new IP to whitelist
nano nginx/allowed-ips.conf
# Add: allow NEW_IP_ADDRESS;

# Reload Nginx configuration
docker-compose restart nginx
```

### Password Security
```bash
# Generate strong passwords
openssl rand -base64 32

# Update passwords in docker-compose.yml
# Restart affected services
docker-compose up -d mysql redis
```

## Troubleshooting

### Common Issues

#### DNS Resolution Problems
```bash
# Check DNS records
nslookup kafka.your-domain.com

# Check from multiple locations
# Visit: https://dnschecker.org

# Wait for propagation if needed
```

#### SSL Certificate Issues
```bash
# Check certificate status
docker-compose run --rm certbot certificates

# Manually renew certificates
docker-compose run --rm certbot renew

# Check Nginx configuration
docker-compose exec nginx nginx -t
```

#### Service Access Issues
```bash
# Check if IP is whitelisted
curl -I https://kafka.your-domain.com

# Add your IP to whitelist if needed
nano nginx/allowed-ips.conf
docker-compose restart nginx
```

#### Memory Issues
```bash
# Check memory usage
docker stats

# Reduce memory limits in docker-compose.yml if needed
# Restart affected services
```

#### Port Conflicts
```bash
# Check what's using a port
sudo lsof -i :9092
sudo netstat -tulpn | grep 9092

# Kill conflicting process or change port mapping
```

### Health Checks
```bash
# Check all service health
docker-compose ps

# Check specific service health
docker inspect kafka --format='{{.State.Health.Status}}'

# View recent logs
docker-compose logs --tail=50 kafka
```

## Performance Optimization

### For 8GB RAM Systems
Reduce memory allocations in `docker-compose.yml`:
- Kafka: 2GB total (1GB heap)
- MySQL: 2GB total (1GB buffer pool)
- Elasticsearch: 2GB total (1GB heap)

### For 32GB+ RAM Systems
Increase memory allocations:
- Kafka: 4-6GB
- MySQL: 4-8GB
- Elasticsearch: 4-8GB

### Storage Optimization
```bash
# Monitor disk usage
df -h
docker system df

# Clean up unused containers and images
docker system prune -a --volumes
```

## Monitoring and Maintenance

### Log Management
```bash
# View Nginx access logs
docker-compose exec nginx tail -f /var/log/nginx/access.log

# View error logs
docker-compose exec nginx tail -f /var/log/nginx/error.log

# Rotate logs if needed
docker-compose exec nginx logrotate -f /etc/logrotate.d/nginx
```

### Service Updates
```bash
# Pull latest images
docker-compose pull

# Recreate services with new images
docker-compose up -d
```

### Certificate Renewal Check
```bash
# Check renewal status
docker-compose logs certbot

# Test renewal process
docker-compose run --rm certbot renew --dry-run
```

## Network Architecture

### Internal Communication
Services communicate using container names on the `kafka-network`:
- `zookeeper:2181`
- `kafka:29092`
- `redis:6379`
- `mysql:3306`
- `elasticsearch:9200`
- `kibana:5601`
- `kafka-ui:8080`

### External Access
- **HTTPS Services**: Via Nginx reverse proxy with SSL termination
- **Direct TCP**: Direct port access to Kafka, MySQL, Redis
- **Security**: IP whitelist enforced on web interfaces

## Data Persistence

Data is stored in Docker volumes:
- `zookeeper-data`, `zookeeper-logs`: Kafka coordination
- `kafka-data`: Kafka messages and topics
- `redis-data`: Redis persistent data
- `mysql-data`, `mysql-config`: MySQL databases
- `elasticsearch-data`: Elasticsearch indices
- `nginx-logs`: Nginx logs
- `certbot/`: SSL certificates (host-mounted)

## Emergency Procedures

### Complete System Reset
```bash
# Stop and remove everything
docker-compose down -v

# Remove SSL certificates
sudo rm -rf ./certbot/conf
sudo rm -rf ./certbot/www

# Start fresh
./setup-ssl.sh
docker-compose up -d
```

### Service Recovery
```bash
# Restart failed service
docker-compose restart service-name

# View detailed logs
docker-compose logs --tail=100 service-name

# Recreate service container
docker-compose up -d --force-recreate service-name
```

## Additional Resources

### Official Documentation
- [Docker](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Redis](https://redis.io/documentation)
- [MySQL](https://dev.mysql.com/doc/)
- [Elasticsearch](https://www.elastic.co/guide/)
- [Nginx](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/docs/)

### Useful Tools
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - SSL configuration testing
- [DNS Checker](https://dnschecker.org/) - DNS propagation checking
- [Docker Hub](https://hub.docker.com/) - Container images

## Support

For technical issues:
1. Review the troubleshooting section above
2. Check service logs: `docker-compose logs [service-name]`
3. Verify network connectivity and DNS configuration
4. Refer to official documentation links provided

---

**Note**: This infrastructure setup is production-ready but should be customized based on your specific security requirements, performance needs, and compliance standards.