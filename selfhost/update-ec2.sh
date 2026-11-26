#!/usr/bin/env bash
# Pull your latest code from git and restart the app on the server.
#   sudo bash selfhost/update-ec2.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo:  sudo bash selfhost/update-ec2.sh"; exit 1; }
git pull --ff-only
bash selfhost/deploy-ec2.sh
