# Run the app on your own Windows computer.
# Needs Docker Desktop (installing it needs admin rights).
# Use: open the project in VS Code, open a terminal, run:
#   powershell -ExecutionPolicy Bypass -File selfhost\run-local.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker is not installed. Install Docker Desktop first: https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
    exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is installed but not running. Open Docker Desktop, wait until it says 'running', then try again." -ForegroundColor Red
    exit 1
}

# 1. Create .env the first time
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example"
}

# 2. Apply your brand from selfhost\brand.env (every run, so edits are picked up)
$brandKeys = '^(EMAIL_BRAND_[A-Z_]+|EMAIL_NAME|EMAIL_ADDRESS)='
$kept  = Get-Content ".env" | Where-Object { $_ -notmatch $brandKeys }
$brand = Get-Content "selfhost\brand.env" | Where-Object { $_ -match '^(EMAIL_BRAND_[A-Z_]+|EMAIL_NAME|EMAIL_ADDRESS)=.+' }
$kept + "" + "# Branding (copied from selfhost/brand.env)" + $brand | Set-Content ".env" -Encoding ascii
Write-Host "Applied brand settings from selfhost\brand.env"

# 3. Build and start. The first build takes 10 to 20 minutes and needs about 10 GB of disk.
docker compose -p warmbly up -d --build
if ($LASTEXITCODE -ne 0) { Write-Host "Start failed. See the messages above." -ForegroundColor Red; exit 1 }

# 4. Wait for the backend, then print the link that creates your admin account
Write-Host -NoNewline "Waiting for the backend"
for ($i = 0; $i -lt 90; $i++) {
    docker compose -p warmbly exec -T backend warmblyctl status *> $null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 2
}
Write-Host ""
docker compose -p warmbly exec -T backend warmblyctl setup-link

Write-Host ""
Write-Host "Dashboard:   http://localhost:5173" -ForegroundColor Green
Write-Host "Admin panel: http://localhost:5174" -ForegroundColor Green
Write-Host "Open the setup link above once to create your admin account."
Write-Host "Stop everything:  docker compose -p warmbly down"
