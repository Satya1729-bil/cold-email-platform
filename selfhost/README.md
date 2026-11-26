# Your own cold email platform: setup

This folder adds your brand and simple scripts to the Warmbly open-source code.
The flow is:

1. Run it on your own computer in VS Code (to test).
2. Push the code to your own private GitHub repository.
3. On the AWS EC2 server, pull the code from GitHub and run one script.

Everything else in this project is the original Warmbly code (Apache 2.0 license).
Keep the `LICENSE` file. Do not use the name "Warmbly" or its logo as your product name.

## Files in this folder

| File | What it does |
| --- | --- |
| `brand.env` | Your brand name, domain and sender details. Edit this first. |
| `run-local.ps1` | Starts the app on a Windows computer |
| `run-local.sh` | Starts the app on a Mac, Linux or WSL computer |
| `deploy-ec2.sh` | Sets up and starts the app on the AWS server, with HTTPS |
| `update-ec2.sh` | Pulls your latest code from GitHub and restarts the server |
| `Caddyfile.template` | HTTPS settings for the server (filled in by `deploy-ec2.sh`) |
| `docker-compose.caddy.yml` | Adds Caddy (the HTTPS server) on AWS |

## Step 1: Edit your brand

Open `selfhost/brand.env` in VS Code. Change `YourBrand`, `yourbrand.com` and the
address to your real details. Save.

## Step 2: Run it on your computer

You need **Docker Desktop** installed and running. Installing it needs admin
rights, so this does not work on a locked office laptop. Use a personal computer,
or skip to Step 3 and test on the AWS server instead.

Also check you have about **10 GB free disk**. The first build takes 10 to 20 minutes.

1. Unzip the project and open the folder in VS Code (**File > Open Folder**).
2. Open a terminal (**Terminal > New Terminal**).
3. Run:

   Windows:
   ```
   powershell -ExecutionPolicy Bypass -File selfhost\run-local.ps1
   ```
   Mac or Linux:
   ```
   bash selfhost/run-local.sh
   ```
4. At the end it prints a **setup link**. Open it once and create your admin account.
5. Open the dashboard at http://localhost:5173.

To stop it: `docker compose -p warmbly down`

On your computer, system emails (login codes, invites) are not sent. They are
written to the logs. See them with: `docker compose -p warmbly logs backend`

## Step 3: Push the code to your own private GitHub repository

1. On github.com, click **New repository**. Give it a name, choose **Private**,
   and do not add a README. Click **Create repository**.
2. In the VS Code terminal, inside the project folder, run (put in your GitHub
   username and repository name):

   ```
   git init
   git add .
   git commit -m "My cold email platform, based on Warmbly"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
   git push -u origin main
   ```

The `.env` file holds secrets and is never pushed (it is in `.gitignore`).

## Step 4: Deploy on the AWS EC2 server

Before this, follow Steps 1 and 2 of the setup guide doc: launch the EC2 server
(Ubuntu 24.04, t3.medium, **40 GB disk**, ports 22, 80 and 443 open) and add the
DNS A records for `app.`, `admin.`, `api.`, `ws.`, `track.`, `forms.` and
`portal.` under your domain, all pointing to the server's Elastic IP.

1. Connect to the server (**EC2 > Connect > EC2 Instance Connect**).
2. Make a GitHub token so the server can read your private repository:
   github.com > **Settings > Developer settings > Personal access tokens >
   Fine-grained tokens > Generate new token**. Give it access to only this
   repository, with **Contents: Read-only**. Copy the token.
3. On the server, run:

   ```
   sudo apt-get update && sudo apt-get install -y git
   git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git app
   cd app
   sudo bash selfhost/deploy-ec2.sh
   ```

   When git asks for a password, paste the token (not your GitHub password).
4. The script installs Docker, makes real secrets, sets up HTTPS and starts
   everything. The first build takes 15 to 30 minutes.
5. **Copy the two encryption keys it prints** into a password manager. Without
   them, a backup can never be opened again.
6. Open the setup link it prints, create your admin account, then go to
   `https://app.yourdomain.com`.

## Step 5: Making changes later

1. Change files on your computer in VS Code.
2. Commit and push:
   ```
   git add .
   git commit -m "Describe your change"
   git push
   ```
3. On the server:
   ```
   cd ~/app
   sudo bash selfhost/update-ec2.sh
   ```

## Useful commands on the server

Run these inside `~/app`.

| What | Command |
| --- | --- |
| See what is running | `sudo docker compose -p warmbly ps` |
| See recent logs | `sudo docker compose -p warmbly -f docker-compose.yml -f selfhost/docker-compose.caddy.yml logs --tail 50` |
| Health check | `sudo docker compose -p warmbly exec backend warmblyctl status` |
| New setup link | `sudo docker compose -p warmbly exec backend warmblyctl setup-link` |
| Stop everything | `sudo docker compose -p warmbly -f docker-compose.yml -f selfhost/docker-compose.caddy.yml down` |

## Getting the latest Warmbly updates

The original project releases often. To bring their changes into your copy:

```
git remote add upstream https://github.com/warmbly/warmbly.git
git fetch upstream
git merge upstream/main
git push
```

Then run `update-ec2.sh` on the server. If you changed the same files they did,
git will ask you to fix the conflicts first.
