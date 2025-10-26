# Server Infrastructure Setup

Docker Compose configuration for running a complete development/production infrastructure stack on Ubuntu Server.

## Hardware Requirements

This configuration is optimized for:
- **CPU**: Intel i5 8850H (6 cores / 12 threads)
- **RAM**: 16GB
- **OS**: Ubuntu Server

## Services Included

| Service | Port(s) | Memory Allocation | Description |
|---------|---------|-------------------|-------------|
| Zookeeper | 2181 | 512MB | Kafka coordination service |
| Kafka | 9092, 9093 | 3GB | Message broker |
| Kafka UI | 8080 | 512MB | Web interface for Kafka management |
| Redis | 6379 | 1GB | In-memory data store |
| MySQL | 3306 | 3GB | Relational database |
| Elasticsearch | 9200, 9300 | 3GB | Search and analytics engine |
| Kibana | 5601 | 1GB | Elasticsearch web interface |

**Total Memory Usage**: ~13GB (leaving ~3GB for OS and other processes)

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

## Quick Start

### Start All Services
```bash
docker-compose -f kafka-dockercompose.yml up -d
```

### Check Service Status
```bash
docker-compose -f kafka-dockercompose.yml ps
```

### View Logs
```bash
# All services
docker-compose -f kafka-dockercompose.yml logs -f

# Specific service
docker-compose -f kafka-dockercompose.yml logs -f kafka
docker-compose -f kafka-dockercompose.yml logs -f mysql
```

### Stop All Services
```bash
docker-compose -f kafka-dockercompose.yml down
```

### Stop and Remove All Data
```bash
docker-compose -f kafka-dockercompose.yml down -v
```

## Service Details

### Kafka
- **Bootstrap Server**: `localhost:9092`
- **Internal Communication**: `kafka:29092`
- **Auto-create topics**: Enabled
- **Log Retention**: 7 days or 10GB per topic
- **Replication Factor**: 1 (single broker)

**Connection Example**:
```bash
# From host machine
kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic

# From another Docker container
kafka-console-producer --bootstrap-server kafka:29092 --topic test-topic
```

### Kafka UI
- **URL**: http://localhost:8080
- Manage topics, consumers, and browse messages
- View cluster metrics and health

### Redis
- **Host**: `localhost:6379`
- **Max Memory**: 1GB with LRU eviction
- **Persistence**: AOF (Append Only File) enabled

**Connection Example**:
```bash
# Connect using redis-cli
docker exec -it redis redis-cli

# Test connection
redis-cli -h localhost -p 6379 ping
```

### MySQL
- **Host**: `localhost:3306`
- **Root Password**: `rootpassword`
- **Database**: `mydb`
- **User**: `dbuser` / **Password**: `dbpassword`
- **Character Set**: UTF8MB4
- **Max Connections**: 200

**Connection Example**:
```bash
# Connect using mysql client
mysql -h localhost -P 3306 -u root -prootpassword

# Connect as regular user
mysql -h localhost -P 3306 -u dbuser -pdbpassword mydb

# From another Docker container
mysql -h mysql -P 3306 -u dbuser -pdbpassword mydb
```

**IMPORTANT**: Change default passwords before using in production!

### Elasticsearch
- **URL**: http://localhost:9200
- **Cluster Name**: `es-cluster`
- **Node Name**: `es-node-1`
- **Security**: Disabled (for local development)
- **Heap Size**: 2GB

**Connection Example**:
```bash
# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# Create an index
curl -X PUT http://localhost:9200/my-index

# Index a document
curl -X POST http://localhost:9200/my-index/_doc -H 'Content-Type: application/json' -d '{
  "message": "Hello Elasticsearch"
}'
```

### Kibana
- **URL**: http://localhost:5601
- Access Elasticsearch data through web interface
- Create visualizations and dashboards

## Management Commands

### Start Specific Services
```bash
# Start only Kafka stack
docker-compose -f kafka-dockercompose.yml up -d zookeeper kafka kafka-ui

# Start only databases
docker-compose -f kafka-dockercompose.yml up -d mysql redis

# Start only Elasticsearch stack
docker-compose -f kafka-dockercompose.yml up -d elasticsearch kibana
```

### Restart a Service
```bash
docker-compose -f kafka-dockercompose.yml restart kafka
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

- `zookeeper:2181`
- `kafka:29092` (internal) or `localhost:9092` (external)
- `redis:6379`
- `mysql:3306`
- `elasticsearch:9200`

## Data Persistence

All data is stored in Docker volumes:
- `zookeeper-data`, `zookeeper-logs`
- `kafka-data`
- `redis-data`
- `mysql-data`, `mysql-config`
- `elasticsearch-data`

Data persists across container restarts unless volumes are explicitly removed with `docker-compose down -v`.

## Troubleshooting

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

# Reduce service memory limits in kafka-dockercompose.yml if needed
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
docker-compose -f kafka-dockercompose.yml ps

# Inspect specific container
docker inspect kafka --format='{{.State.Health.Status}}'
```

### Reset Everything
```bash
# Stop and remove all containers, networks, and volumes
docker-compose -f kafka-dockercompose.yml down -v

# Remove dangling images
docker system prune -a
```

## Performance Tuning

### For Lower Memory Systems (8GB RAM)
Reduce memory allocations in [kafka-dockercompose.yml](kafka-dockercompose.yml):
- Kafka: 2GB (heap: 1GB)
- MySQL: 2GB (buffer pool: 1GB)
- Elasticsearch: 2GB (heap: 1GB)

### For Higher Memory Systems (32GB+ RAM)
Increase memory allocations:
- Kafka: 4-6GB
- MySQL: 4-8GB
- Elasticsearch: 4-8GB

## Security Considerations

**WARNING**: This configuration is optimized for development/testing environments.

For production use:
1. Change all default passwords
2. Enable authentication for all services
3. Use environment variables or secrets management
4. Enable SSL/TLS for service communication
5. Configure proper firewall rules
6. Enable Elasticsearch security features
7. Use strong MySQL authentication plugins

## License

This configuration is provided as-is for infrastructure setup purposes.

## Support

For issues or questions, please refer to official documentation:
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Redis](https://redis.io/documentation)
- [MySQL](https://dev.mysql.com/doc/)
- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
