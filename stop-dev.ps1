param(
    [switch]$v
)
$ErrorActionPreference = "Continue"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

$Root = $PSScriptRoot
if (-not $Root -or $Root -eq '') { $Root = (Get-Location).Path }
$ComposeFile = Join-Path $Root "quakeroute-api/compose.yaml"

Write-Host "==========================================" -ForegroundColor White
Write-Host " QuakeRoute Stop Development" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White

if (!(Test-Path $ComposeFile)) {
    Write-Err "compose.yaml not found at $ComposeFile"
    exit 1
}

if ($v) {
    Write-Warn "Destructive flag -v detected: this will DELETE database volume pgdata!"
    $confirm = Read-Host "Type 'yes' to confirm deletion of pgdata volume"
    if ($confirm -ne 'yes') {
        Write-Info "Aborted - volume preserved"
        exit 0
    }
    Write-Info "Stopping and removing volumes..."
    $result = docker compose -f $ComposeFile down -v 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "docker compose down -v failed:`n$result"
        exit 1
    }
    Write-Ok "Stopped and removed volumes (pgdata deleted)"
    Write-Host "==========================================" -ForegroundColor White
    exit 0
}

Write-Info "Stopping Docker services (preserving pgdata)..."
$ps = docker compose -f $ComposeFile ps -q 2>$null
if (-not $ps) {
    Write-Ok "No running services - already stopped"
} else {
    $result = docker compose -f $ComposeFile down 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "docker compose down failed:`n$result"
        exit 1
    }
    Write-Ok "Docker services stopped"
    Write-Ok "Volume pgdata preserved"
}

Write-Info "Flutter: stop-dev does not kill global flutter/dart processes."
Write-Host "       If you started 'flutter run', stop it with Ctrl+C in its terminal or close the window." -ForegroundColor DarkGray

Write-Ok ".env preserved"

Write-Host "==========================================" -ForegroundColor White
Write-Host " Stopped. Data preserved." -ForegroundColor Green
Write-Host " To start again: .\start-dev.ps1" -ForegroundColor Cyan
Write-Host " To delete data: .\stop-dev.ps1 -v (requires confirmation)" -ForegroundColor DarkGray
Write-Host "==========================================" -ForegroundColor White

exit 0
