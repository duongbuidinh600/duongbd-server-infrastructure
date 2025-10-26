# Server Infrastructure Setup

Docker Compose configuration for running a complete development/production infrastructure stack on Ubuntu Server with domain-based access and SSL/TLS encryption.

## Hardware Requirements

This configuration is optimized for:
- **CPU**: Intel i5 8850H (6 cores / 12 threads)
- **RAM**: 16GB
- **OS**: Ubuntu Server
- **Domain**: duongbd.site (with DNS configured)

## Services Included

| Service | Access URL / Port | Memory | Description |
|---------|------------------|--------|-------------|
| Zookeeper | Internal: 2181 | 512MB | Kafka coordination service |
| Kafka | duongbd.site:9092 | 3GB | Message broker |
| Kafka UI | https://kafka.duongbd.site | 512MB | Web interface for Kafka management |
| Redis | duongbd.site:6379 | 1GB | In-memory data store |
| MySQL | duongbd.site:3306 | 3GB | Relational database |
| Elasticsearch | https://es.duongbd.site | 3GB | Search and analytics engine |
| Kibana | https://kibana.duongbd.site | 1GB | Elasticsearch web interface |
| Nginx | Ports 80, 443 | 256MB | Reverse proxy with SSL/TLS |
| Certbot | Background | Minimal | SSL certificate management |

**Total Memory Usage**: ~13.5GB (leaving ~2.5GB for OS and other processes)

### Access Methods

**HTTPS Services** (via subdomains with SSL and IP whitelist):
- Kafka UI: https://kafka.duongbd.site
- Kibana: https://kibana.duongbd.site
- Elasticsearch API: https://es.duongbd.site

**TCP Services** (direct port access):
- Kafka Broker: duongbd.site:9092
- MySQL: duongbd.site:3306
- Redis: duongbd.site:6379

## Prerequisites

1. **Docker**: Install Docker Engine
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

2. **Docker Compose**: Install Docker Compose
```bash
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

3. **System Configuration** (for Elasticsearch):
```bash
# Increase vm.max_map_count for Elasticsearch
sudo sysctl -w vm.max_map_count=262144

# Make it permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

4. **Firewall Configuration**:
```bash
# Allow HTTP (for Let's Encrypt validation)
sudo ufw allow 80/tcp

# Allow HTTPS (for web services)
sudo ufw allow 443/tcp

# Allow Kafka
sudo ufw allow 9092/tcp

# Allow MySQL
sudo ufw allow 3306/tcp

# Allow Redis
sudo ufw allow 6379/tcp

# Enable firewall
sudo ufw enable
```

5. **DNS Configuration**:

You need to create DNS A records pointing to your server's public IP address:

| Record Type | Name | Value |
|-------------|------|-------|
| A | kafka.duongbd.site | YOUR_SERVER_IP |
| A | kibana.duongbd.site | YOUR_SERVER_IP |
| A | es.duongbd.site | YOUR_SERVER_IP |
| A | duongbd.site | YOUR_SERVER_IP |

**Verification**:
```bash
# Test DNS resolution
nslookup kafka.duongbd.site
nslookup kibana.duongbd.site
nslookup es.duongbd.site

# Should return your server's IP address
```

Wait for DNS propagation (can take up to 24 hours, but usually 5-30 minutes).

## Quick Start

### Step 1: Configure IP Whitelist

Edit [nginx/allowed-ips.conf](nginx/allowed-ips.conf) to add your allowed IP addresses:

```bash
# Edit the file
nano nginx/allowed-ips.conf

# Add your IP addresses (one per line)
allow YOUR_IP_ADDRESS;
allow YOUR_OFFICE_IP_RANGE;
```

Example:
```nginx
allow 127.0.0.1;
allow 203.0.113.42;        # Single IP
allow 192.168.1.0/24;      # Entire subnet
```

**Find your IP address**:
```bash
curl ifconfig.me
```

### Step 2: Start Services (Without SSL First)

```bash
# Start all services except Nginx initially
docker-compose up -d zookeeper kafka kafka-ui redis mysql elasticsearch kibana
```

### Step 3: Generate SSL Certificates

Run the SSL setup script to obtain Let's Encrypt certificates:

```bash
./setup-ssl.sh
```

The script will:
1. Prompt for your email address
2. Verify prerequisites
3. Start Nginx temporarily
4. Request SSL certificates for all subdomains
5. Configure automatic renewal

**Important**: Make sure DNS records are configured and propagated before running this script!

### Step 4: Start All Services with HTTPS

```bash
# Stop all services
docker-compose down

# Start everything including Nginx with SSL
docker-compose up -d
```

### Step 5: Verify Access

Test HTTPS access to your services:

```bash
# Test Kafka UI
curl -I https://kafka.duongbd.site

# Test Kibana
curl -I https://kibana.duongbd.site

# Test Elasticsearch
curl https://es.duongbd.site/_cluster/health?pretty

# Test Kafka broker
kafka-console-producer --bootstrap-server duongbd.site:9092 --topic test

# Test MySQL
mysql -h duongbd.site -P 3306 -u dbuser -pdbpassword

# Test Redis
redis-cli -h duongbd.site -p 6379 ping
```

### Check Service Status
```bash
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f kafka
docker-compose logs -f nginx
docker-compose logs -f mysql
```

### Stop All Services
```bash
docker-compose down
```

### Stop and Remove All Data
```bash
docker-compose down -v
```

## Service Details

### Kafka
- **Bootstrap Server**: `duongbd.site:9092`
- **Internal Communication**: `kafka:29092`
- **Auto-create topics**: Enabled
- **Log Retention**: 7 days or 10GB per topic
- **Replication Factor**: 1 (single broker)

**Connection Example**:
```bash
# From external clients
kafka-console-producer --bootstrap-server duongbd.site:9092 --topic test-topic

# From another Docker container on the same network
kafka-console-producer --bootstrap-server kafka:29092 --topic test-topic

# Using Python client
from kafka import KafkaProducer
producer = KafkaProducer(bootstrap_servers='duongbd.site:9092')
```

### Kafka UI
- **URL**: https://kafka.duongbd.site
- **Security**: HTTPS with IP whitelist
- Manage topics, consumers, and browse messages
- View cluster metrics and health

### Redis
- **Host**: `duongbd.site:6379`
- **Max Memory**: 1GB with LRU eviction
- **Persistence**: AOF (Append Only File) enabled

**Connection Example**:
```bash
# Connect from external client
redis-cli -h duongbd.site -p 6379 ping

# From Docker container
docker exec -it redis redis-cli

# Using Python
import redis
r = redis.Redis(host='duongbd.site', port=6379)
r.ping()
```

### MySQL
- **Host**: `duongbd.site:3306`
- **Root Password**: `rootpassword`
- **Database**: `mydb`
- **User**: `dbuser` / **Password**: `dbpassword`
- **Character Set**: UTF8MB4
- **Max Connections**: 200

**Connection Example**:
```bash
# Connect from external client
mysql -h duongbd.site -P 3306 -u root -prootpassword

# Connect as regular user
mysql -h duongbd.site -P 3306 -u dbuser -pdbpassword mydb

# From another Docker container on the same network
mysql -h mysql -P 3306 -u dbuser -pdbpassword mydb

# Connection string for applications
mysql://dbuser:dbpassword@duongbd.site:3306/mydb
```

**IMPORTANT**: Change default passwords before using in production!

### Elasticsearch
- **URL**: https://es.duongbd.site
- **Security**: HTTPS with IP whitelist
- **Cluster Name**: `es-cluster`
- **Node Name**: `es-node-1`
- **Heap Size**: 2GB

**Connection Example**:
```bash
# Check cluster health
curl https://es.duongbd.site/_cluster/health?pretty

# Create an index
curl -X PUT https://es.duongbd.site/my-index

# Index a document
curl -X POST https://es.duongbd.site/my-index/_doc \
  -H 'Content-Type: application/json' \
  -d '{"message": "Hello Elasticsearch"}'

# Using Python
from elasticsearch import Elasticsearch
es = Elasticsearch(['https://es.duongbd.site'])
print(es.cluster.health())
```

### Kibana
- **URL**: https://kibana.duongbd.site
- **Security**: HTTPS with IP whitelist
- Access Elasticsearch data through web interface
- Create visualizations and dashboards

## Management Commands

### Start Specific Services
```bash
# Start only Kafka stack
docker-compose up -d zookeeper kafka kafka-ui

# Start only databases
docker-compose up -d mysql redis

# Start only Elasticsearch stack
docker-compose up -d elasticsearch kibana

# Start Nginx reverse proxy
docker-compose up -d nginx
```

### Restart a Service
```bash
docker-compose restart kafka

# Restart Nginx (after config changes)
docker-compose restart nginx
```

### Update IP Whitelist
```bash
# Edit allowed IPs
nano nginx/allowed-ips.conf

# Add your IP
allow YOUR_NEW_IP;

# Reload Nginx
docker-compose restart nginx
```

### View Resource Usage
```bash
docker stats
```

### Execute Commands in Containers
```bash
# Kafka
docker exec -it kafka bash

# MySQL
docker exec -it mysql mysql -u root -prootpassword

# Redis
docker exec -it redis redis-cli

# Elasticsearch
docker exec -it elasticsearch bash
```

### Backup Data

#### MySQL Backup
```bash
docker exec mysql mysqldump -u root -prootpassword mydb > backup.sql
```

#### MySQL Restore
```bash
docker exec -i mysql mysql -u root -prootpassword mydb < backup.sql
```

#### Redis Backup
```bash
docker exec redis redis-cli SAVE
docker cp redis:/data/dump.rdb ./redis-backup.rdb
```

## Network Architecture

All services are connected via the `kafka-network` bridge network. Services can communicate with each other using their container names as hostnames:

**Internal Communication** (between containers):
- `zookeeper:2181`
- `kafka:29092`
- `redis:6379`
- `mysql:3306`
- `elasticsearch:9200`
- `kibana:5601`
- `kafka-ui:8080`

**External Access** (from internet):
- HTTPS services via Nginx reverse proxy:
  - `https://kafka.duongbd.site` → `kafka-ui:8080`
  - `https://kibana.duongbd.site` → `kibana:5601`
  - `https://es.duongbd.site` → `elasticsearch:9200`
- Direct TCP access:
  - `duongbd.site:9092` → Kafka broker
  - `duongbd.site:3306` → MySQL
  - `duongbd.site:6379` → Redis

## Data Persistence

All data is stored in Docker volumes:
- `zookeeper-data`, `zookeeper-logs` - Kafka coordination data
- `kafka-data` - Kafka messages and topics
- `redis-data` - Redis persistent data
- `mysql-data`, `mysql-config` - MySQL databases and configuration
- `elasticsearch-data` - Elasticsearch indices
- `nginx-logs` - Nginx access and error logs
- `certbot/conf` - SSL certificates (stored on host)
- `certbot/www` - Let's Encrypt validation files (stored on host)

Data persists across container restarts unless volumes are explicitly removed with `docker-compose down -v`.

**Note**: SSL certificates are stored in `./certbot/conf` directory and will be automatically renewed by the Certbot container.

## Troubleshooting

### DNS Not Resolving
```bash
# Check DNS records
nslookup kafka.duongbd.site
nslookup kibana.duongbd.site
nslookup es.duongbd.site

# Wait for DNS propagation (5-30 minutes usually)
# Check from multiple locations: https://dnschecker.org
```

### SSL Certificate Issues
```bash
# Check if certificates exist
ls -la ./certbot/conf/live/kafka.duongbd.site/

# Re-run SSL setup
./setup-ssl.sh

# Check Nginx logs for SSL errors
docker-compose logs nginx | grep -i ssl
docker-compose logs nginx | grep -i error
```

### 403 Forbidden (IP Not Whitelisted)
```bash
# Find your current IP
curl ifconfig.me

# Add your IP to whitelist
nano nginx/allowed-ips.conf
# Add: allow YOUR_IP_ADDRESS;

# Restart Nginx
docker-compose restart nginx

# Test access
curl -I https://kafka.duongbd.site
```

### Cannot Access HTTPS Services
```bash
# Check if Nginx is running
docker-compose ps nginx

# Check Nginx logs
docker-compose logs nginx

# Verify ports are open
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443

# Check firewall
sudo ufw status
```

### Elasticsearch fails to start
```bash
# Check vm.max_map_count
sysctl vm.max_map_count

# Should be at least 262144
sudo sysctl -w vm.max_map_count=262144
```

### Out of Memory Issues
```bash
# Check current memory usage
docker stats

# Reduce service memory limits in docker-compose.yml if needed
```

### Port Already in Use
```bash
# Check what's using the port
sudo lsof -i :9092
sudo netstat -tulpn | grep 9092

# Kill the process or change the port mapping in docker-compose file
```

### View Service Health
```bash
# Check health status
docker-compose ps

# Inspect specific container
docker inspect kafka --format='{{.State.Health.Status}}'

# Check all container logs
docker-compose logs --tail=100
```

### SSL Certificate Renewal Failed
```bash
# Check certbot logs
docker-compose logs certbot

# Manually renew certificates
docker-compose run --rm certbot renew

# Check certificate expiration
docker-compose run --rm certbot certificates
```

### Nginx Configuration Test
```bash
# Test Nginx configuration syntax
docker-compose exec nginx nginx -t

# Reload Nginx without restart
docker-compose exec nginx nginx -s reload
```

### Reset Everything
```bash
# Stop and remove all containers, networks, and volumes
docker-compose down -v

# Remove SSL certificates (if needed)
sudo rm -rf ./certbot/conf
sudo rm -rf ./certbot/www

# Remove dangling images
docker system prune -a

# Start fresh
./setup-ssl.sh
docker-compose up -d
```

## Performance Tuning

### For Lower Memory Systems (8GB RAM)
Reduce memory allocations in [docker-compose.yml](docker-compose.yml):
- Kafka: 2GB (heap: 1GB)
- MySQL: 2GB (buffer pool: 1GB)
- Elasticsearch: 2GB (heap: 1GB)

### For Higher Memory Systems (32GB+ RAM)
Increase memory allocations:
- Kafka: 4-6GB
- MySQL: 4-8GB
- Elasticsearch: 4-8GB

## Security Best Practices

### IP Whitelist Management

1. **Use specific IPs when possible**:
```nginx
# Good - specific IPs
allow 203.0.113.42;
allow 198.51.100.10;

# Acceptable - office subnet
allow 192.168.1.0/24;

# Avoid - too broad
# allow 0.0.0.0/0;  # Never do this!
```

2. **Regular IP audit**:
```bash
# Review Nginx access logs
docker-compose logs nginx | grep "403"

# Check allowed IPs
cat nginx/allowed-ips.conf
```

### SSL/TLS Security

- Certificates auto-renew every 12 hours (certbot checks)
- TLS 1.2+ only (configured in nginx.conf)
- HSTS enabled (forces HTTPS)
- Certificates valid for 90 days

### Database Security

**Change default passwords immediately**:

```bash
# Generate strong passwords
openssl rand -base64 32

# Update docker-compose.yml with new passwords
# Restart affected services
docker-compose up -d mysql redis
```

### Firewall Rules

Only expose necessary ports:
```bash
# Check current rules
sudo ufw status numbered

# Remove unused rules if needed
sudo ufw delete [rule-number]
```

## Monitoring and Logs

### Access Logs

**Nginx Access Logs**:
```bash
# View access logs
docker-compose exec nginx tail -f /var/log/nginx/access.log

# View specific service logs
docker-compose exec nginx tail -f /var/log/nginx/kafka-ui-access.log
docker-compose exec nginx tail -f /var/log/nginx/kibana-access.log
docker-compose exec nginx tail -f /var/log/nginx/elasticsearch-access.log
```

**Error Logs**:
```bash
# View Nginx errors
docker-compose exec nginx tail -f /var/log/nginx/error.log

# Service-specific errors
docker-compose logs --tail=50 kafka
docker-compose logs --tail=50 elasticsearch
docker-compose logs --tail=50 mysql
```

### Health Checks

All services have health checks configured. Check status:
```bash
# View health status
docker-compose ps

# Detailed health info
docker inspect kafka --format='{{json .State.Health}}' | jq
docker inspect elasticsearch --format='{{json .State.Health}}' | jq
```

## File Structure

```
duongbd-server-setup/
├── docker-compose.yml          # Main orchestration file
├── .env.example                # Environment variables template
├── setup-ssl.sh               # SSL certificate setup script
├── README.md                  # This file
├── nginx/
│   ├── nginx.conf            # Main Nginx configuration
│   ├── allowed-ips.conf      # IP whitelist
│   └── conf.d/
│       ├── kafka-ui.conf     # Kafka UI reverse proxy
│       ├── kibana.conf       # Kibana reverse proxy
│       └── elasticsearch.conf # Elasticsearch reverse proxy
└── certbot/
    ├── conf/                 # SSL certificates (auto-generated)
    └── www/                  # Let's Encrypt challenges
```

## Additional Resources

### Official Documentation
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Redis](https://redis.io/documentation)
- [MySQL](https://dev.mysql.com/doc/)
- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Nginx](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/docs/)

### Useful Tools
- [Kafka UI](https://github.com/provectus/kafka-ui) - Web interface for Kafka
- [Kibana](https://www.elastic.co/kibana) - Elasticsearch visualization
- [SSL Labs](https://www.ssllabs.com/ssltest/) - Test SSL configuration
- [DNS Checker](https://dnschecker.org/) - Check DNS propagation

## License

This configuration is provided as-is for infrastructure setup purposes.

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review service logs: `docker-compose logs [service-name]`
3. Refer to official documentation linked above
