# SSL Setup Explanation for duongbd.site

## 🔒 Overview
Your SSL setup uses **Let's Encrypt certificates** with **Nginx reverse proxy** to secure multiple subdomains for your infrastructure services.

## 🏗️ Architecture Components

### 1. **SSL Certificate Management** (`setup-ssl.sh`)
- **Provider**: Let's Encrypt (free, automated certificates)
- **Method**: Webroot validation via HTTP challenge
- **Domains**: kafka.duongbd.site, kibana.duongbd.site, es.duongbd.site
- **Auto-renewal**: Certbot container checks twice daily

### 2. **Nginx Configuration** (nginx.conf + conf.d/*.conf)

**Global SSL Settings** ([nginx.conf:50-58](nginx/nginx.conf#L50-L58)):
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256...';
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_stapling on;
ssl_stapling_verify on;
```

**Per-Domain Setup** ([kafka-ui.conf:4-59](nginx/conf.d/kafka-ui.conf#L4-L59)):
- HTTP → HTTPS redirect (port 80)
- HTTPS on port 443 with security headers
- IP whitelist protection
- Reverse proxy to backend services

**Kibana Configuration** ([kibana.conf:18-64](nginx/conf.d/kibana.conf#L18-L64)):
- Extended timeouts (300s) for Kibana's dashboard loading
- WebSocket support for real-time updates
- Same SSL certificate pattern as other services

### 3. **Docker Integration** (docker-compose.yml)
- **Nginx container**: Frontend reverse proxy on ports 80/443
- **Certbot container**: Automated certificate renewal
- **Volume mounts**: Persistent SSL certificates

## 🚀 Setup Process

### Prerequisites Check
1. ✅ DNS A records pointing to server IP
2. ✅ Ports 80/443 open in firewall
3. ✅ docker-compose available

### Certificate Generation
```bash
./setup-ssl.sh
```
**Process**:
1. Creates temporary Nginx config for HTTP validation
2. Starts Nginx container
3. Requests certificates for each domain
4. Validates domain ownership via HTTP challenge
5. Stores certificates in `./certbot/conf/`

### Security Features
- **HSTS**: Strict-Transport-Security header ([kafka-ui.conf:28](nginx/conf.d/kafka-ui.conf#L28))
- **IP Whitelist**: Only allowed IPs can access services ([allowed-ips.conf](nginx/allowed-ips.conf))
- **Rate Limiting**: 10 requests/second general limit ([nginx.conf:47](nginx/nginx.conf#L47))
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, XSS protection

## 📁 File Structure
```
duongbd-server-setup/
├── setup-ssl.sh              # SSL certificate generation script
├── nginx/
│   ├── nginx.conf           # Global Nginx + SSL configuration
│   ├── conf.d/
│   │   ├── kafka-ui.conf    # kafka.duongbd.site SSL setup
│   │   ├── kibana.conf      # kibana.duongbd.site SSL setup
│   │   └── elasticsearch.conf # es.duongbd.site SSL setup
│   └── allowed-ips.conf     # IP whitelist configuration
├── certbot/
│   ├── conf/                # SSL certificates storage
│   └── www/                 # ACME challenge files
└── docker-compose.yml       # Container orchestration
```

## 🔧 Configuration Steps

### 1. **Add Your IP to Whitelist**
Edit [nginx/allowed-ips.conf](nginx/allowed-ips.conf):
```nginx
# Add your allowed IPs below:
allow YOUR_PUBLIC_IP;
allow YOUR_OFFICE_IP_RANGE;
```

### 2. **Run SSL Setup**
```bash
chmod +x setup-ssl.sh
./setup-ssl.sh
```

### 3. **Start Services**
```bash
docker-compose down && docker-compose up -d
```

## 🛡️ Security Layers

1. **Transport Layer**: TLS 1.2/1.3 encryption
2. **Network Layer**: IP whitelist protection
3. **Application Layer**: Rate limiting + security headers
4. **Certificate Layer**: Automated renewal with Let's Encrypt

## 📊 Certificate Management

**Auto-renewal**: Certbot container runs renewal checks every 12 hours
**Storage**: Certificates persist in `./certbot/conf/` volume
**Validation**: HTTP challenge method via temporary Nginx configuration

## 🌐 Access URLs (Post-Setup)
- https://kafka.duongbd.site → Kafka UI
- https://kibana.duongbd.site → Kibana Dashboard
- https://es.duongbd.site → Elasticsearch

## 🔍 Service-Specific Configurations

### Kibana SSL Configuration
The Kibana setup includes special considerations:
- **Extended Timeouts**: 300s timeouts for dashboard loading and complex queries ([kibana.conf:51-53](nginx/conf.d/kibana.conf#L51-L53))
- **WebSocket Support**: Enables real-time updates for live dashboards ([kibana.conf:56-58](nginx/conf.d/kibana.conf#L56-L58))
- **HTTP/1.1 Protocol**: Required for WebSocket upgrade headers ([kibana.conf:56](nginx/conf.d/kibana.conf#L56))

### Certificate Paths
Each service uses identical certificate patterns:
```nginx
ssl_certificate /etc/letsencrypt/live/SERVICE.duongbd.site/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/SERVICE.duongbd.site/privkey.pem;
```

This setup provides enterprise-grade SSL security with automated management for your infrastructure services.