# Traefik Reverse Proxy Setup (Server-Side)

## Overview

This setup adds Traefik as a reverse proxy to work with your existing cloudflared installation on Ubuntu server.

## Prerequisites

- ✅ cloudflared already installed and running on Ubuntu server
- ✅ Docker and Docker Compose installed
- ✅ Existing Docker services (Kafka, Redis, MySQL, etc.)

## Quick Deployment

Since you already have cloudflared running, you only need to:

1. **Update your cloudflared tunnel configuration** on the server:
   ```bash
   # Replace your existing tunnel.yml with tunnel-traefik.yml
   sudo cp tunnel-traefik.yml /path/to/your/tunnel.yml

   # Restart cloudflared to apply changes
   sudo systemctl restart cloudflared
   ```

2. **Deploy Traefik and updated services**:
   ```bash
   # Deploy Traefik configuration
   docker compose down
   docker compose up -d --force-recreate
   ```

## What Changed

### Service URLs
All services now route through Traefik on port 8443:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Kafka UI** | https://kafka.duongbd.site | kafka:password123 |
| **Redis Commander** | https://redis.duongbd.site | redis:password123 |
| **MySQL Adminer** | https://mysql.duongbd.site | admin:admin123 |
| **Elasticsearch** | https://es.duongbd.site | elastic:password123 |
| **Kibana** | https://kibana.duongbd.site | (no auth) |
| **Nexus Repository** | https://nexus.duongbd.site | (no auth) |

### Key Changes from Original Setup

1. **All HTTP services** now route through Traefik (port 8443) instead of direct ports
2. **SSL termination** happens at Traefik level
3. **Basic authentication** added for sensitive services
4. **Security headers** and compression enabled
5. **Health checks** for all services
6. **Centralized logging** and metrics

### Unchanged Services
- **SSH**: ssh.duongbd.site → localhost:22 (direct)
- **Kafka Broker**: kafka-broker.duongbd.site → localhost:9092 (direct TCP)

## Files to Update on Server

### 1. Cloudflare Tunnel Config
Replace your existing tunnel configuration with `tunnel-traefik.yml`:

```yaml
tunnel: d46bfa9f-b5ef-4393-8191-dc058a9577db
credentials-file: /home/boi/.cloudflared/d46bfa9f-b5ef-4393-8191-dc058a9577db.json

ingress:
  # SSH service - direct routing (unchanged)
  - hostname: ssh.duongbd.site
    service: ssh://localhost:22

  # All HTTP services now route through Traefik
  - hostname: kafka.duongbd.site
    service: https://localhost:8443
    originRequest:
      noTLSVerify: false
      connectTimeout: 30s
      httpHostHeader: kafka.duongbd.site

  # ... (other services similar)
```

### 2. Docker Compose
The updated `docker-compose.yml` includes:
- Traefik service with proper configuration
- All existing services updated with Traefik routing labels
- Removed direct port exposures (8080, 8081, etc.)

## Verification Steps

After deployment:

1. **Check Traefik is running**:
   ```bash
   docker ps | grep traefik
   curl http://localhost:8082/ping
   ```

2. **Test service routing**:
   ```bash
   # Test local routing
   curl -k -H "Host: kafka.duongbd.site" https://localhost:8443

   # Test external access
   curl https://kafka.duongbd.site
   ```

3. **Check cloudflared logs**:
   ```bash
   sudo journalctl -u cloudflared -f
   ```

## Troubleshooting

### Services Not Accessible
1. Check if Traefik is running: `docker ps | grep traefik`
2. Check Traefik logs: `docker compose logs traefik`
3. Verify cloudflared config: `cloudflared tunnel ingress validate tunnel.yml`
4. Check if services are healthy: `docker compose ps`

### Port Conflicts
- Ensure port 8443 is available for Traefik
- Check other services aren't using ports 80, 443, 8082

### Cloudflared Issues
```bash
# Restart cloudflared
sudo systemctl restart cloudflared

# Check status
sudo systemctl status cloudflared

# View logs
sudo journalctl -u cloudflared -f
```

## Management Commands

```bash
# View all services
docker compose ps

# View Traefik logs
docker compose logs -f traefik

# View specific service logs
docker compose logs -f kafka-ui

# Restart Traefik
docker compose restart traefik

# Restart all services
docker compose restart

# Stop all services
docker compose down
```

## Benefits of This Setup

✅ **Centralized Management**: All routing through one reverse proxy
✅ **Enhanced Security**: Basic auth, security headers, SSL
✅ **Better Performance**: Compression, health checks, load balancing
✅ **Monitoring**: Metrics and logging for all services
✅ **Scalability**: Easy to add new services with consistent routing

## Next Steps

1. Deploy the updated configuration
2. Test all service URLs
3. Update any application configurations with new URLs
4. Monitor service health through Traefik dashboard
5. Optionally customize authentication passwords for production

The setup maintains your existing infrastructure while adding a robust reverse proxy layer for better security and management.