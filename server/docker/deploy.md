# SplitPay — Digital Ocean Droplet Deployment Guide

This guide walks you through deploying the SplitPay backend on a Digital Ocean Droplet using Docker and docker-compose.

---

## Prerequisites

- A Digital Ocean account
- A registered domain name (optional but recommended for SSL)
- SSH key added to your DO account

---

## Step 1: Create a Droplet

1. Log in to [cloud.digitalocean.com](https://cloud.digitalocean.com)
2. Click **Create > Droplets**
3. Choose:
   - **Image:** Ubuntu 22.04 LTS
   - **Plan:** Basic — at least 2 GB RAM / 1 vCPU ($12/month)
   - **Region:** Closest to your users
   - **Authentication:** SSH Key (recommended)
4. Click **Create Droplet**
5. Note your Droplet's IP address

---

## Step 2: Connect to the Droplet

```bash
ssh root@YOUR_DROPLET_IP
```

---

## Step 3: Install Docker and docker-compose

```bash
# Update packages
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Verify Docker installation
docker --version

# Install docker-compose plugin
apt-get install -y docker-compose-plugin

# Verify
docker compose version

# (Optional) Allow non-root user to use Docker
usermod -aG docker $USER
```

---

## Step 4: Install Other Dependencies

```bash
# Install nginx, certbot, git
apt-get install -y nginx certbot python3-certbot-nginx git
```

---

## Step 5: Clone the Repository

```bash
# Create app directory
mkdir -p /opt/splitpay
cd /opt/splitpay

# Clone your repo
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git .
```

---

## Step 6: Configure Environment Variables

```bash
cd /opt/splitpay/BE

# Copy the example env file
cp .env.example .env

# Edit with your production values
nano .env
```

Set these production values:

```env
NODE_ENV=production
PORT=3000
API_PREFIX=/api/v1
DATABASE_URL=postgresql://postgres:STRONG_PASSWORD@postgres:5432/splitpay_db
JWT_ACCESS_SECRET=GENERATE_A_STRONG_32_CHAR_SECRET
JWT_REFRESH_SECRET=GENERATE_ANOTHER_STRONG_32_CHAR_SECRET
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
GOOGLE_CLIENT_ID=your-google-oauth2-client-id
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100
ALLOWED_ORIGINS=https://yourdomain.com
LOG_LEVEL=info
POSTGRES_USER=postgres
POSTGRES_PASSWORD=STRONG_PASSWORD
POSTGRES_DB=splitpay_db
```

**Generate strong secrets:**
```bash
# Generate a random 32-character secret
openssl rand -hex 32
```

---

## Step 7: Start the Application

```bash
cd /opt/splitpay/BE

# Build and start all services in the background
docker compose up -d --build

# Check logs
docker compose logs -f api

# Verify the API is running
curl http://localhost:3000/api/v1/health
```

---

## Step 8: Configure Nginx as a Reverse Proxy

Create an Nginx configuration file:

```bash
nano /etc/nginx/sites-available/splitpay
```

Paste the following (replace `yourdomain.com` with your actual domain or Droplet IP):

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_read_timeout 90s;
        proxy_connect_timeout 90s;
        proxy_send_timeout 90s;
    }
}
```

Enable the site:

```bash
# Enable site
ln -s /etc/nginx/sites-available/splitpay /etc/nginx/sites-enabled/

# Remove default site
rm /etc/nginx/sites-enabled/default

# Test config
nginx -t

# Reload nginx
systemctl reload nginx
```

---

## Step 9: SSL with Certbot (Let's Encrypt)

```bash
# Obtain and install SSL certificate (replace with your domain)
certbot --nginx -d yourdomain.com -d www.yourdomain.com \
  --non-interactive \
  --agree-tos \
  --email your@email.com \
  --redirect

# Auto-renewal is configured automatically
# Verify renewal
certbot renew --dry-run
```

After certbot runs, your Nginx config will be updated to redirect HTTP to HTTPS automatically.

---

## Step 10: Configure Firewall

```bash
# Allow SSH, HTTP, HTTPS
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Check status
ufw status
```

---

## Step 11: Set Up Auto-Restart on Reboot

Create a systemd service for docker-compose:

```bash
nano /etc/systemd/system/splitpay.service
```

```ini
[Unit]
Description=SplitPay Docker Compose Application
Requires=docker.service
After=docker.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/splitpay/BE
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable splitpay
systemctl start splitpay
```

---

## Updating the Application

```bash
cd /opt/splitpay

# Pull latest changes
git pull origin main

cd BE

# Rebuild and restart
docker compose up -d --build

# Verify
curl https://yourdomain.com/api/v1/health
```

---

## Monitoring and Logs

```bash
# View API logs (live)
docker compose logs -f api

# View postgres logs
docker compose logs -f postgres

# View all service statuses
docker compose ps

# View resource usage
docker stats
```

---

## Database Backup

```bash
# Create a backup
docker exec splitpay_postgres pg_dump -U postgres splitpay_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
cat backup.sql | docker exec -i splitpay_postgres psql -U postgres splitpay_db
```

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `502 Bad Gateway` | Check `docker compose logs api` — the container may have crashed |
| DB connection refused | Ensure postgres container is healthy: `docker compose ps` |
| Migrations not running | Run manually: `docker compose exec api npx prisma migrate deploy` |
| SSL cert issues | Check certbot: `certbot certificates` |
| Port 3000 already in use | `lsof -i :3000` then kill the process |
