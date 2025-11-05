# Traefik + Cloudflared Setup Guide

## Overview

This setup integrates Traefik as a reverse proxy with Cloudflare tunneling to provide secure, scalable access to your Docker services.

## Architecture

```
Internet → Cloudflare → cloudflared → Traefik → Docker Services
```

**Benefits:**
- 🔧 Centralized routing management
- 🛡️ SSL termination at edge
- 📊 Load balancing and health checks
- 🔍 Path-based routing capabilities
- 🚀 Performance improvements with compression
- 🔐 Basic authentication per service
- 📈 Metrics and monitoring

## Files Created

### Configuration Files
- `traefik/traefik.yml` - Main Traefik configuration
- `traefik/dynamic-config.yml` - Dynamic routing rules
- `traefik/certs/` - Self-signed SSL certificates
- `tunnel-traefik.yml` - Updated Cloudflare tunnel config
- `deploy-traefik.sh` - Automated deployment script

### Modified Files
- `docker-compose.yml` - Added Traefik service and updated existing services with routing labels

## Services & Access

| Service | URL | Credentials |
|---------|-----|-------------|
| **Traefik Dashboard** | https://traefik.duongbd.site/dashboard/ | admin:admin123 |
| **Kafka UI** | https://kafka.duongbd.site | kafka:password123 |
| **Redis Commander** | https://redis.duongbd.site | redis:password123 |
| **MySQL Adminer** | https://mysql.duongbd.site | admin:admin123 |
| **Elasticsearch** | https://es.duongbd.site | elastic:password123 |
| **Kibana** | https://kibana.duongbd.site | (no auth) |
| **Nexus Repository** | https://nexus.duongbd.site | (no auth) |

## Deployment

### Quick Deploy
```bash
./deploy-traefik.sh
```

### Dry Run (Preview Changes)
```bash
./deploy-traefik.sh --dry-run
```

### Force Deploy (Skip Backups)
```bash
./deploy-traefik.sh --force
```

## Configuration Details

### Traefik Features
- **SSL/TLS**: Self-signed certificates for local HTTPS
- **Security Headers**: HSTS, XSS protection, content type sniffing
- **Compression**: Gzip compression for all services
- **Rate Limiting**: 100 requests/minute with burst of 50
- **Health Checks**: Per-service health monitoring
- **Metrics**: Prometheus metrics endpoint
- **Basic Auth**: Per-service authentication

### Cloudflare Integration
- All HTTP services route through Traefik on port 8443
- SSH and Kafka broker maintain direct connections
- Proper Host header forwarding for correct routing

### Security Features
- Basic authentication for sensitive services
- Security headers (HSTS, XSS protection, etc.)
- CORS support for Elasticsearch API
- Rate limiting to prevent abuse
- No TLS verification for local development

## Management

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f traefik
docker-compose logs -f kafka-ui

# Cloudflared logs
tail -f /var/log/cloudflared.log
```

### Service Management
```bash
# Stop all services
docker-compose down

# Restart specific service
docker-compose restart traefik

# Update and restart
docker-compose pull
docker-compose up -d
```

### Backup & Restore
```bash
# Manual backup
cp -r traefik/ backups/traefik-$(date +%Y%m%d_%H%M%S)/
cp docker-compose.yml backups/

# The deployment script automatically creates backups
ls backups/
```

## Troubleshooting

### Common Issues

**Port Conflicts**
- Ensure ports 80, 443, 8443, and 8082 are available
- Check with: `netstat -tulpn | grep -E ':(80|443|8443|8082)'`

**Network Issues**
- Verify Docker network exists: `docker network ls | grep scangoo-network`
- Create if missing: `docker network create scangoo-network`

**SSL Certificate Issues**
- Regenerate certificates: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout traefik/certs/key.pem -out traefik/certs/cert.pem -subj "/CN=*.duongbd.site"`

**Cloudflared Issues**
- Check tunnel config: `cloudflared tunnel ingress validate tunnel-traefik.yml`
- View tunnel logs: `tail -f /var/log/cloudflared.log`

**Service Not Accessible**
1. Check if service is running: `docker ps`
2. Check service logs: `docker-compose logs [service-name]`
3. Verify Traefik routing: `curl -H "Host: service.duongbd.site" http://localhost`
4. Check Cloudflare tunnel status

### Health Monitoring

```bash
# Check Traefik health
curl http://localhost:8082/ping

# Check service health through Traefik
curl -k https://localhost:8443/ping

# View metrics
curl http://localhost:8082/metrics
```

## Migration from Direct Cloudflared

### Previous Setup
- Direct port mapping: `cloudflared → localhost:PORT`
- Multiple subdomains → multiple ports
- No centralized management

### New Setup
- Centralized routing: `cloudflared → Traefik → services`
- Single HTTPS entry point (8443)
- Enhanced security and monitoring

### Migration Steps
1. Deploy new setup with `./deploy-traefik.sh`
2. Test all services through new URLs
3. Update any hardcoded URLs in applications
4. Optionally remove old `tunnel.yml` after validation

## Customization

### Adding New Services
1. Add service to `docker-compose.yml` with Traefik labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.duongbd.site`)"
  - "traefik.http.routers.myservice.entrypoints=websecure"
  - "traefik.http.routers.myservice.tls=true"
  - "traefik.http.services.myservice.loadbalancer.server.port=8080"
```

2. Add routing rule to `tunnel-traefik.yml`:
```yaml
- hostname: myservice.duongbd.site
  service: https://localhost:8443
```

### Custom Authentication
Replace password hashes in service labels:
```bash
# Generate new hash
htpasswd -nb user password

# Use in docker-compose.yml
- "traefik.http.middlewares.myservice-auth.basicauth.users=user:$$generated_hash$$"
```

### Custom Domains
Update:
- `traefik/certs/cert.pem` and `key.pem` for your domain
- `tunnel-traefik.yml` hostname rules
- Service labels in `docker-compose.yml`

## Performance Optimization

### Resource Allocation
Current memory limits (adjust based on usage):
- Traefik: 512MB limit, 256MB reservation
- Services: Individual limits in docker-compose.yml

### Monitoring
- Traefik metrics: http://localhost:8082/metrics
- Service health checks configured per service
- Docker stats: `docker stats`

## Security Considerations

1. **Change Default Passwords**: Update all basic auth passwords
2. **Use Valid SSL Certificates**: Replace self-signed certs in production
3. **Network Isolation**: Services only accessible through Traefik
4. **Regular Updates**: Keep Traefik and Docker images updated
5. **Access Logs**: Monitor access logs for suspicious activity

## Support

- Traefik Documentation: https://doc.traefik.io/traefik/
- Cloudflare Tunnel Documentation: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- Docker Compose Documentation: https://docs.docker.com/compose/