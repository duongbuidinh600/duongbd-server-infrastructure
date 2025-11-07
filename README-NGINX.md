# Nginx + Cloudflared Setup Guide

## Overview

This setup replaces Traefik with Nginx as a reverse proxy, working with your existing Cloudflare tunnel to provide secure, scalable access to your Docker services.

## Architecture

```
Internet → Cloudflare → cloudflared → Nginx → Docker Services
```

**Benefits:**
- 🔧 Traditional and reliable reverse proxy
- 🛡️ SSL termination at Nginx layer
- 📊 Detailed access and error logging
- 🔍 Basic authentication per service
- 🚀 High performance with minimal overhead
- 🔐 Security headers and rate limiting
- 📈 Status monitoring with stub_status

## Files Created

### Configuration Files
- `nginx/nginx.conf` - Main Nginx configuration
- `nginx/conf.d/*.conf` - Individual service configurations
- `nginx/ssl/` - Self-signed SSL certificates
- `nginx/.htpasswd-*` - Basic authentication password files

### Updated Files
- `docker-compose.yml` - Replaced Traefik with Nginx service
- `tunnel.yml` - Updated to route to Nginx (port 443)
- `deploy-nginx.sh` - Automated deployment script

### Services & Access

| Service | URL | Credentials |
|---------|-----|-------------|
| **Nginx Dashboard** | https://nginx.duongbd.site | admin:admin123 |
| **Kafka UI** | https://kafka.duongbd.site | kafka:password123 |
| **Redis Commander** | https://redis.duongbd.site | redis:password123 |
| **MySQL Adminer** | https://mysql.duongbd.site | admin:admin123 |
| **Elasticsearch** | https://es.duongbd.site | elastic:password123 |
| **Kibana** | https://kibana.duongbd.site | (no auth) |
| **Nexus Repository** | https://nexus.duongbd.site | (no auth) |

## Quick Deployment

### 1. Deploy Docker Services
```bash
./deploy-nginx.sh
```

### 2. Update Cloudflare Tunnel
```bash
# Copy updated tunnel config
sudo cp tunnel.yml /path/to/your/active/tunnel.yml

# Restart cloudflared
sudo systemctl restart cloudflared
```

### 3. Verify Setup
```bash
# Check Nginx status
docker compose ps nginx

# Test Nginx health
curl http://localhost/nginx-health

# Test services
curl -I https://kafka.duongbd.site
```

## Nginx Configuration Details

### Main Features
- **SSL/TLS**: Self-signed certificates for local HTTPS
- **Security Headers**: HSTS, XSS protection, content type sniffing
- **Compression**: Gzip compression for better performance
- **Rate Limiting**: 30 req/s general, 10 req/s for API endpoints
- **Basic Authentication**: Per-service authentication
- **Health Checks**: Built-in health endpoints
- **Logging**: Detailed access and error logs

### Service Configurations

#### Kafka UI (`nginx/conf.d/kafka-ui.conf`)
- Routes: `https://kafka.duongbd.site` → `kafka-ui:8080`
- Auth: Basic auth (kafka:password123)
- Features: WebSocket support, health checks

#### Redis Commander (`nginx/conf.d/redis-commander.conf`)
- Routes: `https://redis.duongbd.site` → `redis-commander:8081`
- Auth: Basic auth (redis:password123)
- Features: WebSocket support, health checks

#### MySQL Adminer (`nginx/conf.d/mysql-adminer.conf`)
- Routes: `https://mysql.duongbd.site` → `adminer:8080`
- Auth: Basic auth (admin:admin123)
- Features: Health checks

#### Elasticsearch (`nginx/conf.d/elasticsearch.conf`)
- Routes: `https://es.duongbd.site` → `elasticsearch:9200`
- Auth: Basic auth (elastic:password123)
- Features: CORS headers, API rate limiting, large request support

#### Kibana (`nginx/conf.d/kibana.conf`)
- Routes: `https://kibana.duongbd.site` → `kibana:5601`
- Auth: None (handled by Kibana itself)
- Features: WebSocket support, health checks

#### Nexus (`nginx/conf.d/nexus.conf`)
- Routes: `https://nexus.duongbd.site` → `nexus:8081`
- Auth: None (handled by Nexus itself)
- Features: Large file upload support (1GB), extended timeouts

#### Nginx Dashboard (`nginx/conf.d/nginx-dashboard.conf`)
- Routes: `https://nginx.duongbd.site` → dashboard
- Auth: Basic auth (admin:admin123)
- Features: Status page, health checks, service links

## Management

### Docker Commands
```bash
# View all services
docker compose ps

# View Nginx logs
docker compose logs -f nginx

# View specific service logs
docker compose logs -f kafka-ui

# Restart Nginx
docker compose restart nginx

# Test Nginx configuration
docker exec nginx nginx -t

# Reload Nginx (no downtime)
docker exec nginx nginx -s reload

# Stop all services
docker compose down
```

### Cloudflared Commands
```bash
# Check cloudflared status
sudo systemctl status cloudflared

# View cloudflared logs
sudo journalctl -u cloudflared -f

# Restart cloudflared
sudo systemctl restart cloudflared
```

### Monitoring & Health Checks
```bash
# Nginx health check
curl http://localhost/nginx-health

# Nginx status page
curl http://localhost/nginx-status

# Test individual services
curl -k -u "kafka:password123" https://kafka.duongbd.site
curl -k -u "redis:password123" https://redis.duongbd.site
```

## Troubleshooting

### Common Issues

**Port Conflicts**
- Ensure ports 80 and 443 are available
- Check: `netstat -tulpn | grep -E ':(80|443)'`

**SSL Certificate Issues**
- Regenerate certificates: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/ssl/nginx.key -out nginx/ssl/nginx.crt -subj "/CN=*.duongbd.site"`
- Verify certificate: `openssl x509 -in nginx/ssl/nginx.crt -text -noout`

**Authentication Issues**
- Reset password: `echo "user:$(openssl passwd -apr1 newpassword)" > nginx/.htpasswd-service`
- Test basic auth: `curl -k -u "user:password" https://service.duongbd.site`

**Service Not Accessible**
1. Check Nginx status: `docker compose ps nginx`
2. Check Nginx logs: `docker compose logs nginx`
3. Test local routing: `curl -H "Host: service.duongbd.site" http://localhost`
4. Verify cloudflared config: `cloudflared tunnel ingress validate tunnel.yml`

**Performance Issues**
- Check Nginx status: `curl http://localhost/nginx-status`
- Monitor logs: `docker compose logs -f nginx`
- Adjust worker processes in `nginx/nginx.conf`

### Configuration Validation

```bash
# Validate Nginx configuration
docker exec nginx nginx -t

# Validate Docker Compose
docker compose config

# Validate cloudflared tunnel (optional)
cloudflared tunnel ingress validate tunnel.yml
```

## Security Considerations

### Current Security Measures
- **Basic Authentication**: All sensitive services have basic auth
- **SSL/TLS**: HTTPS enforced with modern TLS protocols
- **Security Headers**: HSTS, XSS protection, content type sniffing
- **Rate Limiting**: Protection against abuse
- **CORS**: Proper CORS headers for APIs

### Recommendations for Production
1. **Replace Self-Signed Certs**: Use Let's Encrypt or commercial certificates
2. **Strong Passwords**: Change all default passwords
3. **Fail2Ban**: Implement IP banning for failed auth attempts
4. **Regular Updates**: Keep Nginx and Docker images updated
5. **Log Monitoring**: Monitor access logs for suspicious activity
6. **Network Security**: Consider firewall rules for additional protection

## Customization

### Adding New Services

1. **Create Nginx config file**:
```nginx
# nginx/conf.d/newservice.conf
server {
    listen 80;
    server_name newservice.duongbd.site;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name newservice.duongbd.site;

    # SSL configuration
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    # Optional: Basic authentication
    auth_basic "New Service";
    auth_basic_user_file /etc/nginx/.htpasswd-newservice;

    location / {
        proxy_pass http://newservice:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

2. **Update tunnel.yml**:
```yaml
- hostname: newservice.duongbd.site
  service: https://localhost:443
  originRequest:
    noTLSVerify: false
    connectTimeout: 30s
    httpHostHeader: newservice.duongbd.site
```

3. **Update docker-compose.yml**:
```yaml
newservice:
  image: service-image:latest
  container_name: newservice
  # ... other config
  networks:
    - scangoo-network
```

### Custom Domains
- Update SSL certificates for your domain
- Update tunnel.yml hostname rules
- Update Nginx server_name directives

## Performance Optimization

### Nginx Tuning
```nginx
# In nginx/nginx.conf
worker_processes auto;
worker_connections 2048;

# Enable HTTP/2
listen 443 ssl http2;

# Optimize SSL
ssl_session_cache shared:SSL:20m;
ssl_session_timeout 20m;

# Enable caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Monitoring
- Use Prometheus + Grafana for metrics
- Monitor `nginx-status` endpoint
- Set up alerts for error rates and response times

## Migration from Traefik

### Changes Made
1. **Removed**: Traefik service and configurations
2. **Added**: Nginx reverse proxy with equivalent functionality
3. **Updated**: All service routing to use Nginx instead of Traefik
4. **Enhanced**: Added service dashboard and detailed logging

### Benefits of Nginx over Traefik
- ✅ **Simpler Configuration**: Traditional Nginx config syntax
- ✅ **Better Performance**: Lower resource usage, faster processing
- ✅ **Mature Technology**: Battle-tested, widely adopted
- ✅ **Detailed Logging**: Comprehensive access and error logging
- ✅ **Fine-grained Control**: More precise configuration options
- ✅ **Status Monitoring**: Built-in status and health endpoints

The Nginx setup provides equivalent functionality to Traefik with better performance and more traditional configuration patterns.