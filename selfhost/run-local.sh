#!/usr/bin/env bash
# Run the app on your own Mac, Linux or WSL computer.
# Needs Docker with Compose v2. Use:  bash selfhost/run-local.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v docker >/dev/null || { echo "Docker is not installed: https://docs.docker.com/get-docker/"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker, then try again."; exit 1; }

# 1. Create .env the first time
[ -f .env ] || { cp .env.example .env; echo "Created .env from .env.example"; }

# 2. Apply your brand from selfhost/brand.env (every run, so edits are picked up)
sed -i.bak -E '/^(EMAIL_BRAND_[A-Z_]+|EMAIL_NAME|EMAIL_ADDRESS)=/d' .env && rm -f .env.bak
{ echo; echo "# Branding (copied from selfhost/brand.env)";
  grep -E '^(EMAIL_BRAND_[A-Z_]+|EMAIL_NAME|EMAIL_ADDRESS)=.+' selfhost/brand.env | tr -d '\r'; } >> .env
echo "Applied brand settings from selfhost/brand.env"

# 3. Build and start. The first build takes 10 to 20 minutes and needs about 10 GB of disk.
docker compose -p warmbly up -d --build

# 4. Wait for the backend, then print the link that creates your admin account
printf "Waiting for the backend"
for _ in $(seq 1 90); do
  docker compose -p warmbly exec -T backend warmblyctl status >/dev/null 2>&1 && break
  printf "."; sleep 2
done; echo
docker compose -p warmbly exec -T backend warmblyctl setup-link

echo
echo "Dashboard:   http://localhost:5173"
echo "Admin panel: http://localhost:5174"
echo "Open the setup link above once to create your admin account."
echo "Stop everything:  docker compose -p warmbly down"
