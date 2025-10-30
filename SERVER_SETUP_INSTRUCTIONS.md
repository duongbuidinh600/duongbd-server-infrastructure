# Server Setup Instructions

## Overview

This guide provides step-by-step instructions to deploy a complete infrastructure stack with Kafka, Redis, MySQL, Elasticsearch, Kibana, and Nginx reverse proxy with Cloudflare tunnel for secure external access on Ubuntu Server.

## Prerequisites

### Hardware Requirements
- **CPU**: Intel i5 8850H (6 cores / 12 threads) or equivalent
- **RAM**: 16GB minimum (8GB for basic usage, 32GB+ for production)
- **Storage**: 50GB+ free disk space
- **OS**: Ubuntu Server 20.04+ or similar

### Domain Requirements
- Domain name (e.g., `your-domain.com`)
- Cloudflare account with domain added
- Cloudflare Tunnel configured for your domain
- No need for public IP address or DNS A records

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
sudo ufw allow 80/tcp    # HTTP (internal Nginx only)

# Enable firewall
sudo ufw --force enable
```

**Note**: Since we're using Cloudflare tunnel, you don't need to expose application ports (9092, 3306, 6379) to the internet. Nginx only needs port 80 for internal communication.

### 2. Cloudflare Tunnel Configuration

#### 2.1 Set up Cloudflare Tunnel
1. **Add your domain to Cloudflare** if not already done
2. **Install Cloudflare tunnel daemon (cloudflared)**:
   ```bash
   wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared-linux-amd64.deb
   ```
3. **Authenticate Cloudflared**:
   ```bash
   cloudflared tunnel login
   ```
4. **Create a tunnel**:
   ```bash
   cloudflared tunnel create kafka-infrastructure
   ```
5. **Configure tunnel origins** - create a config file at `~/.cloudflared/config.yml`:
   ```yaml
   tunnel: kafka-infrastructure
   credentials-file: ~/.cloudflared/[TUNNEL_ID].json

   ingress:
     - hostname: kafka.your-domain.com
       service: http://localhost:80
     - hostname: kibana.your-domain.com
       service: http://localhost:80
     - hostname: es.your-domain.com
       service: http://localhost:80
     - service: http_status:404
   ```

#### 2.2 Configure DNS Records
```bash
# Map tunnel to your domain names
cloudflared tunnel route dns kafka-infrastructure kafka.your-domain.com
cloudflared tunnel route dns kafka-infrastructure kibana.your-domain.com
cloudflared tunnel route dns kafka-infrastructure es.your-domain.com
```

#### 2.3 Start Cloudflare Tunnel
```bash
# Test the tunnel
cloudflared tunnel run kafka-infrastructure

# Or run as a service
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

**Benefits of Cloudflare Tunnel**:
- No public IP required
- Automatic SSL/TLS termination
- DDoS protection
- No need to open ports 443/80 in firewall
- Built-in CDN and caching

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
```

#### 3.3 Configure IP Whitelist
```bash
# Edit IP whitelist configuration
nano nginx/allowed-ips.conf
```

**Add your IP addresses:**
```nginx
# Allow all IP addresses (open access)
allow all;

# Or restrict to specific IPs
# allow 127.0.0.1;
# allow YOUR_IP_ADDRESS;
# allow 192.168.1.0/24;  # Office network
```

**Note**: With Cloudflare tunnel, you can use `allow all;` for convenience, or restrict to specific IPs for additional security.

### 4. Service Deployment

#### 4.1 Phase 1: Start All Services
```bash
# Start all services at once (no SSL setup needed)
docker-compose up -d
```

#### 4.2 Verify Services
```bash
# Check container status
docker-compose ps

# View logs if needed
docker-compose logs -f
```

Wait 2-3 minutes for services to fully initialize.

#### 4.3 Verify Cloudflare Tunnel
```bash
# Check if tunnel is running
sudo systemctl status cloudflared

# Check tunnel logs
sudo journalctl -u cloudflared -f
```

### 5. Verification and Testing

#### 5.1 Check Service Status
```bash
# Verify all containers are running
docker-compose ps

# Check health status
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

#### 5.2 Test Cloudflare Tunnel Access
```bash
# Test web interfaces through Cloudflare tunnel
curl -I https://kafka.your-domain.com
curl -I https://kibana.your-domain.com
curl https://es.your-domain.com/_cluster/health?pretty
```

#### 5.3 Test Internal Service Connections
```bash
# Test Kafka (internal access only)
docker exec -it kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# Test MySQL (internal access only)
docker exec -it mysql mysql -u root -prootpassword -e "SELECT VERSION();"

# Test Redis (internal access only)
docker exec -it redis redis-cli ping
```

#### 5.4 Web Interface Access
Open in your browser:
- **Kafka UI**: `https://kafka.your-domain.com`
- **Kibana**: `https://kibana.your-domain.com`
- **Elasticsearch**: `https://es.your-domain.com`

**Note**: All access is through HTTPS provided by Cloudflare tunnel, while Nginx communicates with services over HTTP internally.

## Service Configuration Details

### Kafka Configuration
- **External Access**: Through Cloudflare tunnel: `https://kafka.your-domain.com`
- **Internal Access**: `kafka:29092` (within Docker network)
- **Auto-create Topics**: Enabled
- **Replication Factor**: 1 (single broker)
- **Memory**: 3GB allocated (2GB heap)

### MySQL Configuration
- **Internal Access**: `mysql:3306` (within Docker network)
- **Root Password**: `rootpassword` (change in production)
- **Database**: `mydb`
- **User**: `dbuser` / `dbpassword`
- **Memory**: 3GB allocated
- **Connection Pool**: 200 max connections
- **External Access**: Via application connections only (not exposed directly)

### Redis Configuration
- **Internal Access**: `redis:6379` (within Docker network)
- **Max Memory**: 1GB with LRU eviction
- **Persistence**: AOF enabled
- **Memory**: 1GB allocated
- **External Access**: Via application connections only (not exposed directly)

### Elasticsearch Configuration
- **Web Interface**: `https://es.your-domain.com` (via Cloudflare tunnel)
- **Internal API**: `http://elasticsearch:9200` (within Docker network)
- **Cluster Name**: `es-cluster`
- **Heap Size**: 2GB
- **Security**: IP whitelist enforced via Nginx

### Kibana Configuration
- **Web Interface**: `https://kibana.your-domain.com` (via Cloudflare tunnel)
- **Internal Access**: `http://kibana:5601` (within Docker network)
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

### Cloudflare Tunnel Security
- **SSL/TLS Termination**: Handled by Cloudflare at the edge
- **TLS Version**: TLS 1.3 enforced by Cloudflare
- **DDoS Protection**: Automatic by Cloudflare
- **Zero Trust**: Can be configured with Cloudflare Access

### IP Whitelist Management
```bash
# Add new IP to whitelist
nano nginx/allowed-ips.conf
# Add: allow NEW_IP_ADDRESS;

# Reload Nginx configuration
docker compose restart nginx
```

### Password Security
```bash
# Generate strong passwords
openssl rand -base64 32

# Update passwords in docker-compose.yml
# Restart affected services
docker compose up -d mysql redis
```

### Network Security
- **Internal Services**: MySQL, Redis, Kafka are not exposed to internet
- **HTTP-only Backend**: Nginx communicates with services over HTTP internally
- **External Access**: Only through Cloudflare tunnel with HTTPS
- **Firewall**: Only SSH and internal HTTP port 80 open

## Troubleshooting

### Common Issues

#### Cloudflare Tunnel Issues
```bash
# Check tunnel status
sudo systemctl status cloudflared

# Check tunnel logs
sudo journalctl -u cloudflared -f

# Restart tunnel
sudo systemctl restart cloudflared

# Test tunnel configuration
cloudflared tunnel ingress validate
```

#### Service Access Issues
```bash
# Check if IP is whitelisted
curl -I https://kafka.your-domain.com

# Add your IP to whitelist if needed
nano nginx/allowed-ips.conf
docker compose restart nginx

# Check Nginx configuration
docker compose exec nginx nginx -t
```

#### Cloudflare DNS Issues
```bash
# Check DNS records
nslookup kafka.your-domain.com

# Verify tunnel routing
cloudflared tunnel route dns list

# Check if tunnel is properly configured
cloudflared tunnel info kafka-infrastructure
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
# Check what's using port 80 (Nginx)
sudo lsof -i :80
sudo netstat -tulpn | grep 80

# Check Docker port bindings
docker compose ps
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

### Cloudflare Tunnel Maintenance
```bash
# Check tunnel status
sudo systemctl status cloudflared

# Update cloudflared
sudo apt update && sudo apt install cloudflared

# Recreate tunnel if needed
cloudflared tunnel delete kafka-infrastructure
cloudflared tunnel create kafka-infrastructure
# Re-configure routing as in section 2.2
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
- **HTTPS Services**: Via Cloudflare tunnel to Nginx reverse proxy
- **Internal TCP**: Kafka, MySQL, Redis only accessible within Docker network
- **Security**: IP whitelist enforced on web interfaces, DDoS protection by Cloudflare

## Data Persistence

Data is stored in Docker volumes:
- `zookeeper-data`, `zookeeper-logs`: Kafka coordination
- `kafka-data`: Kafka messages and topics
- `redis-data`: Redis persistent data
- `mysql-data`, `mysql-config`: MySQL databases
- `elasticsearch-data`: Elasticsearch indices
- `nginx-logs`: Nginx logs

## Emergency Procedures

### Complete System Reset
```bash
# Stop and remove everything
docker compose down -v

# Remove Cloudflare tunnel (optional)
cloudflared tunnel delete kafka-infrastructure

# Start fresh
docker compose up -d
# Re-create tunnel following section 2.1
```

### Service Recovery
```bash
# Restart failed service
docker compose restart service-name

# View detailed logs
docker compose logs --tail=100 service-name

# Recreate service container
docker compose up -d --force-recreate service-name
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
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/)

### Useful Tools
- [Cloudflare Dashboard](https://dash.cloudflare.com/) - Tunnel management
- [DNS Checker](https://dnschecker.org/) - DNS propagation checking
- [Docker Hub](https://hub.docker.com/) - Container images

## Support

For technical issues:
1. Review the troubleshooting section above
2. Check service logs: `docker compose logs [service-name]`
3. Check Cloudflare tunnel status and logs
4. Verify network connectivity and DNS configuration
5. Refer to official documentation links provided

---

**Note**: This infrastructure setup is production-ready but should be customized based on your specific security requirements, performance needs, and compliance standards.