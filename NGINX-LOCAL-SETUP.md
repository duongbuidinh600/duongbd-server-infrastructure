# Nginx Local Setup Guide

This guide helps you set up Nginx locally on Ubuntu instead of running it in a Docker container.

## Overview

This setup replaces the Docker Nginx container with a local Nginx installation while maintaining all the reverse proxy functionality for your services.

## Prerequisites

- Ubuntu 18.04 or later
- Sudo privileges
- Existing Docker Nginx configuration (in `./nginx/` directory)
- Docker containers that Nginx proxies to (kafka-ui, redis-commander, etc.)

## Quick Start

### 1. Install Nginx

```bash
./install-nginx-ubuntu.sh
```

### 2. Setup Configuration

```bash
./setup-nginx-config.sh
```

### 3. Manage Docker Ports

```bash
./manage-docker-ports.sh
```

### 4. Start Nginx

```bash
./nginx-manager.sh start
```

## Detailed Instructions

### Step 1: Installation

The `install-nginx-ubuntu.sh` script will:

- Update package lists
- Install Nginx and required tools
- Create necessary directories
- Set up systemd service overrides
- Create backup of any existing configuration

Run it:
```bash
./install-nginx-ubuntu.sh
```

### Step 2: Configuration Setup

The `setup-nginx-config.sh` script will:

- Backup current Nginx configuration
- Copy your custom configuration from `./nginx/`
- Test the configuration
- Create Docker port management script

Run it:
```bash
./setup-nginx-config.sh
```

### Step 3: Handle Docker Port Conflicts

Since your Docker containers expose ports that local Nginx will use, you need to manage conflicts:

**Option A: Stop Docker Nginx container**
```bash
docker stop nginx
```

**Option B: Use the port management script**
```bash
./manage-docker-ports.sh
```

**Option C: Modify docker-compose.yml**
Comment out or remove the Nginx service and port mappings for services that will be proxied.

### Step 4: Start Local Nginx

```bash
# Test configuration
sudo nginx -t

# Start Nginx
sudo systemctl start nginx

# Enable auto-start
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

## Nginx Manager Script

The `nginx-manager.sh` script provides easy management commands:

```bash
# Service management
./nginx-manager.sh start        # Start Nginx
./nginx-manager.sh stop         # Stop Nginx
./nginx-manager.sh restart      # Restart Nginx
./nginx-manager.sh reload       # Reload configuration
./nginx-manager.sh status       # Show status

# Configuration
./nginx-manager.sh config       # Test configuration
./nginx-manager.sh edit         # Edit configuration
./nginx-manager.sh backup       # Backup configuration
./nginx-manager.sh restore      # Restore configuration

# Logs
./nginx-manager.sh logs         # Show recent logs
./nginx-manager.sh logs-full    # Show full logs

# Setup
./nginx-manager.sh install      # Install Nginx
./nginx-manager.sh setup        # Setup configuration
./nginx-manager.sh version      # Show version
```

## Configuration Files

### Main Configuration

The main Nginx configuration is copied from `./nginx/nginx.conf` to `/etc/nginx/nginx.conf`.

Key features:
- Worker processes set to auto
- Gzip compression enabled
- Security headers configured
- Rate limiting zones defined
- Includes conf.d files

### Virtual Hosts

Configuration files in `./nginx/conf.d/` are copied to `/etc/nginx/conf.d/`.

Common configurations:
- `kafka-ui.conf` - Kafka UI proxy
- `redis-commander.conf` - Redis Commander proxy
- `adminer.conf` - Adminer proxy
- `elasticsearch.conf` - Elasticsearch proxy
- `kibana.conf` - Kibana proxy
- `nexus.conf` - Nexus proxy
- `default.conf` - Default catch-all

### SSL Certificates

SSL certificates in `./nginx/ssl/` are copied to `/etc/nginx/ssl/`.

## Service Integration

### Docker Network

Your local Nginx needs to communicate with Docker containers. Since your containers use the `scangoo-network` bridge network, Nginx can reach them by their container names.

### Example Configuration

For a service like Kafka UI:
```nginx
server {
    listen 80;
    server_name kafka.duongbd.site;

    location / {
        proxy_pass http://kafka-ui:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

### Important Notes

1. **Container Names**: Use Docker container names (e.g., `kafka-ui`, not `localhost:8080`)
2. **Network**: Ensure Docker containers are running and accessible
3. **Ports**: Remove port conflicts in docker-compose.yml if needed
4. **DNS**: Local DNS or `/etc/hosts` entries for domain names

## Troubleshooting

### Common Issues

**1. Port Already in Use**
```bash
# Check what's using port 80
sudo ss -tlnp | grep :80

# Stop conflicting service
sudo systemctl stop apache2  # or other service
```

**2. Configuration Errors**
```bash
# Test configuration
sudo nginx -t

# Check logs
./nginx-manager.sh logs
```

**3. Container Not Reachable**
```bash
# Check if container is running
docker ps

# Check network connectivity
docker exec nginx ping kafka-ui
```

**4. Permission Issues**
```bash
# Fix ownership
sudo chown -R www-data:www-data /var/log/nginx

# Fix permissions
sudo chmod 755 /etc/nginx/conf.d
```

### Useful Commands

```bash
# Check Nginx status
sudo systemctl status nginx

# View configuration
sudo nginx -T

# Check active connections
sudo ss -tnp | grep nginx

# Monitor logs in real-time
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Test endpoint
curl -I http://localhost
```

## Migration from Docker

### Before Migration

1. **Backup Current Setup**
   ```bash
   docker-compose down
   cp -r nginx nginx-backup
   ```

2. **Document Current Configuration**
   - Note all domains and their proxy targets
   - Document any custom SSL certificates
   - List all active proxy configurations

### Migration Process

1. **Install Local Nginx**
   ```bash
   ./install-nginx-ubuntu.sh
   ```

2. **Setup Configuration**
   ```bash
   ./setup-nginx-config.sh
   ```

3. **Update Docker Configuration**
   - Remove or comment Nginx service from docker-compose.yml
   - Remove port 80 mapping from other services if proxied
   - Keep internal container networking intact

4. **Start Services**
   ```bash
   docker-compose up -d  # Start containers without Nginx
   ./nginx-manager.sh start  # Start local Nginx
   ```

### After Migration

1. **Verify All Services**
   - Test each proxy endpoint
   - Check SSL certificates
   - Verify authentication (if configured)

2. **Monitor Performance**
   - Check response times
   - Monitor error logs
   - Verify resource usage

3. **Update Monitoring**
   - Update monitoring tools to check local Nginx
   - Configure log rotation
   - Set up health checks

## Security Considerations

1. **File Permissions**
   - SSL private keys: 600
   - Configuration files: 644
   - Log files: www-data ownership

2. **Access Control**
   - Keep basic authentication files secure
   - Regularly update SSL certificates
   - Monitor access logs

3. **Firewall**
   ```bash
   sudo ufw allow 'Nginx Full'
   sudo ufw reload
   ```

## Performance Tuning

### Basic Optimizations

Already configured in `nginx.conf`:
- Worker processes: auto
- Worker connections: 1024
- Gzip compression: enabled
- Client max body size: 100M

### Advanced Tuning

Edit `/etc/nginx/nginx.conf`:
```nginx
# For high traffic sites
worker_processes auto;
worker_connections 2048;

# Caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m max_size=1g inactive=60m;

# Buffer sizes
client_body_buffer_size 128k;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;
```

## Maintenance

### Regular Tasks

1. **Log Rotation** (usually automatic with logrotate)
2. **SSL Certificate Renewal**
3. **Configuration Backups**
4. **Security Updates**

### Automated Backups

Add to cron:
```bash
# Weekly backup
0 2 * * 0 /path/to/nginx-manager.sh backup
```

## Support

### Getting Help

1. Check logs: `./nginx-manager.sh logs`
2. Test configuration: `./nginx-manager.sh config`
3. Verify Docker containers: `docker ps`
4. Check network connectivity

### Resources

- [Nginx Official Documentation](https://nginx.org/en/docs/)
- [Ubuntu Nginx Guide](https://ubuntu.com/server/docs/nginx)
- [Docker Networking](https://docs.docker.com/network/)

## Scripts Summary

| Script | Purpose |
|--------|---------|
| `install-nginx-ubuntu.sh` | Install Nginx and dependencies |
| `setup-nginx-config.sh` | Copy and setup configuration files |
| `nginx-manager.sh` | Manage Nginx service and configuration |
| `manage-docker-ports.sh` | Handle Docker port conflicts |

All scripts are executable and designed to be run from the project directory.