#!/usr/bin/env bash
# Set up and start the app on an AWS EC2 server (Ubuntu 24.04).
# Run from the project folder after "git clone":
#   sudo bash selfhost/deploy-ec2.sh
# Safe to run again: it never replaces secrets that already exist.
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo:  sudo bash selfhost/deploy-ec2.sh"; exit 1; }

DOMAIN=$(grep -E '^DOMAIN=' selfhost/brand.env | head -1 | cut -d= -f2- | tr -d '\r" ')
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "yourbrand.com" ]; then
  echo "Set DOMAIN in selfhost/brand.env to your real domain first, commit, push, and pull again."
  exit 1
fi
echo "Domain: $DOMAIN"

# 1. Docker
if ! command -v docker >/dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null

# 2. Swap memory, so the first build does not run out of RAM on a 4 GB server
if ! swapon --show | grep -q .; then
  mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  if [ "$mem_kb" -lt 7000000 ]; then
    echo "Adding 4 GB of swap..."
    fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
fi

# 3. Disk check (the first build needs about 10 GB)
free_gb=$(df -BG --output=avail . | tail -1 | tr -dc '0-9')
[ "$free_gb" -ge 12 ] || echo "WARNING: only ${free_gb} GB free disk. The build needs about 10 GB. Make the EC2 disk bigger if it fails."

# 4. .env with real secrets (only the first time)
if [ ! -f .env ]; then
  cp .env.example .env
  cat >> .env <<ENV

# ---- Production settings, added by selfhost/deploy-ec2.sh on $(date -u +%F) ----
APP_ENV=prod
AUTH_SECRET=$(openssl rand -base64 32)
INTERNAL_API_TOKEN=$(openssl rand -hex 24)
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n')
KMS_LOCAL_MASTER_KEY=$(openssl rand -base64 32)
CREDENTIALS_ENCRYPTION_KEY=$(openssl rand -hex 32)
UPDATER_TOKEN=$(openssl rand -hex 24)
PORTAL_EDGE_TOKEN=$(openssl rand -hex 24)

APP_URL=https://app.$DOMAIN
API_PUBLIC_URL=https://api.$DOMAIN
CORS_ALLOW_ORIGINS=https://app.$DOMAIN,https://admin.$DOMAIN
WEBSOCKET_URL=wss://ws.$DOMAIN/socket/websocket
PHX_HOST=ws.$DOMAIN
CHECK_ORIGIN_HOSTS=https://app.$DOMAIN,https://admin.$DOMAIN
TRACKING_DOMAIN=track.$DOMAIN
FORMS_DOMAIN=forms.$DOMAIN
PORTAL_DOMAIN=portal.$DOMAIN
TRUSTED_PROXIES=127.0.0.1/32,172.16.0.0/12
FORMS_TRUSTED_PROXIES=127.0.0.1/32,172.16.0.0/12
TRACKING_TRUSTED_PROXIES=127.0.0.1/32,172.16.0.0/12
DISABLE_REGISTRATION=invite_only
ENV
  chmod 600 .env

  # Keep a copy of the two keys that unlock all mailbox passwords
  keyfile=/root/encryption-keys-backup.txt
  grep -E '^(KMS_LOCAL_MASTER_KEY|CREDENTIALS_ENCRYPTION_KEY)=' .env > "$keyfile"
  chmod 600 "$keyfile"
  echo
  echo "=================================================================="
  echo " IMPORTANT: copy these two keys to a password manager NOW."
  echo " Without them, a backup of your data can never be opened again."
  echo "------------------------------------------------------------------"
  cat "$keyfile"
  echo "------------------------------------------------------------------"
  echo " (also saved on this server in $keyfile)"
  echo "=================================================================="
  echo
fi

# 5. Brand settings from selfhost/brand.env (every run, so edits are picked up)
sed -i -E '/^(EMAIL_BRAND_[A-Z_]+|EMAIL_NAME|EMAIL_ADDRESS)=/d' .env
sed -i '/^# Branding (copied from selfhost\/brand.env)$/d' .env
{ echo "# Branding (copied from selfhost/brand.env)";
  grep -E '^(EMAIL_BRAND_[A-Z_]+|EMAIL_NAME|EMAIL_ADDRESS)=.+' selfhost/brand.env | tr -d '\r'; } >> .env

# 6. HTTPS config for Caddy
sed "s/__DOMAIN__/$DOMAIN/g" selfhost/Caddyfile.template > selfhost/Caddyfile

# 7. Build and start everything (first time: 15 to 30 minutes)
COMPOSE="docker compose -p warmbly -f docker-compose.yml -f selfhost/docker-compose.caddy.yml"
$COMPOSE up -d --build

# 8. Wait for the backend, then print the link that creates your admin account
printf "Waiting for the backend"
for _ in $(seq 1 120); do
  $COMPOSE exec -T backend warmblyctl status >/dev/null 2>&1 && break
  printf "."; sleep 3
done; echo
$COMPOSE exec -T backend warmblyctl setup-link || true

echo
echo "Done. Open:  https://app.$DOMAIN"
echo "If the page does not load, check that the DNS A records point to this server,"
echo "and see logs with:  sudo $COMPOSE logs --tail 50 caddy backend"
