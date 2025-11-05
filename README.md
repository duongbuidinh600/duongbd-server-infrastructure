# Traefik Docker Infrastructure

🏗️ **Modern reverse proxy setup with automatic service discovery and secure tunneling**

## 🎯 Architecture Overview

```
Internet → Cloudflare → Cloudflared Tunnel (Ubuntu Server) → Traefik → Docker Services
```

This setup provides:
- **Centralized Management**: Single Traefik entry point for all services
- **Automatic SSL**: Free SSL certificates via Cloudflare
- **Service Discovery**: Automatic detection of Docker containers
- **Security**: Rate limiting, authentication, and security headers
- **Monitoring**: Built-in metrics and health checks

## 🚀 Quick Start

### 1. Configure Environment
```bash
cp .env.example .env
# Edit .env with your credentials
```

### 2. Deploy Services
```bash
./scripts/deploy.sh
```

### 3. Monitor Health
```bash
./scripts/monitor.sh
```

## 📋 Services Configuration

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| Traefik Dashboard | `https://traefik.duongbd.site` | admin/admin123 | Reverse proxy management |
| Kafka UI | `https://kafka.duongbd.site` | - | Kafka cluster management |
| Kibana | `https://kibana.duongbd.site` | - | Elasticsearch visualization |
| Elasticsearch | `https://es.duongbd.site` | - | Search and analytics |
| Nexus | `https://nexus.duongbd.site` | - | Artifact repository |
| MySQL Admin | `https://mysql.duongbd.site` | admin/admin123 | Database administration |
| Redis Commander | `https://redis.duongbd.site` | admin/REDIS_PASSWORD | Redis management |

## 🔧 Configuration Files

### Main Docker Compose
- `docker-compose.yml` - All application services with Traefik labels
- Automatic service discovery via Docker labels
- Removed direct port exposures for security

### Traefik Configuration
- `traefik/docker-compose.yml` - Traefik container
- `traefik/config/traefik.yml` - Main Traefik configuration
- `traefik/config/middlewares.yml` - Security and routing middlewares

### Cloudflare Tunnel Configuration
- `tunnel.yml` - Cloudflare tunnel configuration (Ubuntu server)
- Routes all HTTP traffic through Traefik (port 80)
- SSH bypasses Traefik for direct server access

### Scripts
- `scripts/deploy.sh` - Automated deployment script
- `scripts/monitor.sh` - Health monitoring and status checking

## 🛡️ Security Features

### Authentication
- Basic auth for Traefik dashboard
- Configurable credentials via environment variables

### Security Headers
- HSTS, XSS protection, content type sniffing protection
- Frame options and referrer policies

### Rate Limiting
- Global rate limiting (100 req/s average, 200 burst)
- Per-service rate limiting capabilities

### Network Isolation
- Separate Docker networks for different security levels
- Internal-only communication where possible

## 📊 Monitoring

### Health Checks
All services include Docker health checks:
- `./scripts/monitor.sh` - Quick health overview
- Container status monitoring
- HTTP endpoint checking

### Metrics
- Traefik Prometheus metrics on `:8080/metrics`
- Resource usage monitoring
- Log aggregation capabilities

## 🔄 Service Management

### Adding New Services
1. Add service to `docker-compose.yml`
2. Include Traefik labels:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.my-service.rule=Host(`myservice.duongbd.site`)"
     - "traefik.http.routers.my-service.entrypoints=websecure"
     - "traefik.http.routers.my-service.tls.certresolver=myresolver"
     - "traefik.http.services.my-service.loadbalancer.server.port=8080"
   ```
3. Add hostname to `tunnel.yml`:
   ```yaml
   - hostname: myservice.duongbd.site
     service: http://localhost:80
     originRequest:
       noTLSVerify: true
       connectTimeout: 30s
   ```
4. Deploy: `./scripts/deploy.sh`

### Updating Services
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d

# Check status
./scripts/monitor.sh
```

### Troubleshooting
```bash
# View logs
docker-compose logs -f [service-name]

# Restart specific service
docker-compose restart [service-name]

# Check container status
docker-compose ps

# Inspect Traefik routes
curl http://localhost:8080/api/http/routers
```

## 🌐 Network Architecture

### Docker Networks
- `traefik-network`: Traefik and services exposed to internet
- `scangoo-network`: Internal service communication

### Traffic Flow
1. External traffic → Cloudflare edge
2. Cloudflare → Cloudflared tunnel (Ubuntu Server)
3. Cloudflared → Traefik (port 80)
4. Traefik → Service containers (internal routing based on host headers)

**Key Benefits:**
- Traefik handles SSL termination and security headers
- Centralized routing and middleware management
- Authentication and rate limiting in one place
- Automatic service discovery via Docker labels

## 📝 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TRAEFIK_BASIC_AUTH` | Traefik dashboard credentials | Required |
| `REDIS_PASSWORD` | Redis Commander password | admin123 |
| `DOMAIN` | Base domain for services | duongbd.site |
| `SSL_EMAIL` | Email for SSL certificates | admin@duongbd.site |

## 🔒 Security Considerations

1. **Change Default Passwords**: Update all default credentials before production
2. **Limit Exposure**: Only Traefik exposed to internet via Cloudflared
3. **Regular Updates**: Keep Docker images and dependencies updated
4. **Monitor Logs**: Regularly check access logs for suspicious activity
5. **Backup Data**: Regular backups of MySQL, Elasticsearch, and volume data

## 🚨 Troubleshooting Common Issues

### Services Not Accessible
```bash
# Verify Traefik routing
curl http://localhost:8080/api/http/routers

# Check DNS resolution
nslookup kafka.duongbd.site

# Check Cloudflared tunnel status (Ubuntu server)
systemctl status cloudflared

# Reload tunnel configuration
cloudflared tunnel restart <tunnel-id>

# Validate tunnel configuration
cloudflared tunnel ingress validate
```

### SSL Certificate Issues
```bash
# Check Let's Encrypt storage
ls -la traefik/letsencrypt/

# Verify certificate status
curl -I https://kafka.duongbd.site
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Monitor service health
./scripts/monitor.sh

# Check logs for errors
docker-compose logs -f --tail=100
```

## 📚 Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Compose Reference](https://docs.docker.com/compose/)