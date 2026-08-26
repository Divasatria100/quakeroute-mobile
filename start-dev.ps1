#Requires -Version 5.1
$ErrorActionPreference = "Continue"

# QuakeRoute Development Bootstrap Script
# Idempotent, non-destructive, safe to run multiple times.

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

$Root = $PSScriptRoot
if (-not $Root -or $Root -eq "") { $Root = (Get-Location).Path }

$ApiDir = Join-Path $Root "quakeroute-api"
$MobileDir = Join-Path $Root "quakeroute-mobile"
$ComposeFile = Join-Path $ApiDir "compose.yaml"
$EnvFile = Join-Path $ApiDir ".env"
$EnvExample = Join-Path $ApiDir ".env.example"

Write-Host "==========================================" -ForegroundColor White
Write-Host " QuakeRoute Development Environment" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White

# 1. Validate repository structure
Write-Info "Validating repository structure..."
if (!(Test-Path $ComposeFile)) { Write-Err "compose.yaml not found at $ComposeFile"; exit 1 }
if (!(Test-Path (Join-Path $MobileDir "pubspec.yaml"))) { Write-Warn "Flutter pubspec.yaml not found at $MobileDir\pubspec.yaml — mobile bootstrap will be skipped" }
else { Write-Ok "Repository structure OK" }

# 2. Check prerequisites
Write-Info "Checking prerequisites..."
# PowerShell already required via #Requires
Write-Ok "PowerShell $($PSVersionTable.PSVersion) OK"

$dockerVersion = $null
try { $dockerVersion = docker --version 2>$null } catch {}
if (-not $dockerVersion) { Write-Err "Docker not found. Install Docker Desktop https://docs.docker.com/desktop/"; exit 1 }
Write-Ok "Docker $dockerVersion"

try { docker info 1>$null 2>$null; if ($LASTEXITCODE -ne 0) { throw "not running" } } catch { Write-Err "Docker daemon not running. Start Docker Desktop and try again."; exit 1 }
Write-Ok "Docker daemon running"

$composeVersion = $null
try { $composeVersion = docker compose version 2>$null } catch {}
if (-not $composeVersion) { Write-Err "Docker Compose v2 not found."; exit 1 }
Write-Ok "Docker Compose $composeVersion"

$gitVersion = $null
try { $gitVersion = git --version 2>$null } catch {}
if ($gitVersion) { Write-Ok "Git $gitVersion" } else { Write-Warn "Git not found — clone already done, continuing" }

$flutterAvailable = $false
try { $flutterVersion = flutter --version 2>$null | Select-Object -First 1; if ($flutterVersion) { $flutterAvailable = $true; Write-Ok "Flutter $flutterVersion" } } catch {}
if (-not $flutterAvailable) { Write-Warn "Flutter SDK not found — backend will start, mobile skipped. Install https://flutter.dev" }

# 3. Prepare .env
Write-Info "Preparing environment..."
if (!(Test-Path $EnvFile)) {
    if (!(Test-Path $EnvExample)) { Write-Err ".env.example not found at $EnvExample"; exit 1 }
    Copy-Item -Path $EnvExample -Destination $EnvFile
    Write-Ok ".env created from .env.example"
} else {
    Write-Ok ".env already exists — preserved"
}

# 4. Start Docker
Write-Info "Starting Docker services..."
Push-Location $ApiDir
try {
    $upOutput = docker compose -f $ComposeFile up -d 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "docker compose up failed:`n$upOutput"
        # Check port conflict hint
        $portCheck = netstat -ano 2>$null | Select-String -Pattern ":8000|:5432"
        if ($portCheck) { Write-Err "Port conflict detected:`n$portCheck`nStop conflicting service or check compose.yaml ports." }
        Pop-Location
        exit 1
    }
    Write-Ok "Docker compose up -d succeeded"
} finally {
    if ((Get-Location).Path -ne $ApiDir) { Pop-Location }
}

# 5. Wait for PostgreSQL healthy
Write-Info "Waiting for PostgreSQL to become healthy..."
$timeoutSec = 60
$elapsed = 0
$healthy = $false
while ($elapsed -lt $timeoutSec) {
    $health = docker inspect --format='{{.State.Health.Status}}' quakeroute-db 2>$null
    if ($health -eq "healthy") { $healthy = $true; break }
    # Fallback pg_isready
    $ready = docker compose -f $ComposeFile exec -T db pg_isready -U quakeroute -d quakeroute 2>$null
    if ($LASTEXITCODE -eq 0) { $healthy = $true; break }
    Start-Sleep -Seconds 2
    $elapsed += 2
}
if (-not $healthy) {
    Write-Err "PostgreSQL not ready after ${timeoutSec}s. Check 'docker compose -f $ComposeFile logs db'"
    exit 1
}
Write-Ok "PostgreSQL ready (healthy)"

# 6. Laravel dependencies (only if missing)
Write-Info "Checking Laravel dependencies..."
$vendorExists = Test-Path (Join-Path $ApiDir "vendor\autoload.php")
if (-not $vendorExists) {
    Write-Info "vendor/ missing — running composer install..."
    $installResult = docker compose -f $ComposeFile exec -T app composer install --no-interaction 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Try run --rm fallback if exec fails (container not ready)
        $installResult = docker compose -f $ComposeFile run --rm app composer install --no-interaction 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Err "composer install failed:`n$installResult"; exit 1 }
    }
    Write-Ok "Composer dependencies installed"
} else {
    Write-Ok "Composer dependencies ready (vendor/ exists)"
}

# 7. APP_KEY
$envContent = Get-Content $EnvFile -Raw
if ($envContent -match "APP_KEY=\s*$" -or $envContent -match "APP_KEY=base64:\s*$") {
    Write-Info "Generating APP_KEY..."
    $keyResult = docker compose -f $ComposeFile exec -T app php artisan key:generate 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Err "key:generate failed:`n$keyResult"; exit 1 }
    Write-Ok "APP_KEY generated"
} else {
    Write-Ok "APP_KEY already set"
}

# 8. storage:link + config:clear
$storageLink = Join-Path $ApiDir "public\storage"
if (!(Test-Path $storageLink)) {
    Write-Info "Creating storage link..."
    docker compose -f $ComposeFile exec -T app php artisan storage:link 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "storage:link created" } else { Write-Warn "storage:link skipped or failed (non-critical)" }
}
docker compose -f $ComposeFile exec -T app php artisan config:clear 2>&1 | Out-Null
Write-Ok "Config cleared"

# 9. Database migration (only pending)
Write-Info "Checking database migrations..."
$migrateStatus = docker compose -f $ComposeFile exec -T app php artisan migrate:status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warn "migrate:status failed — will attempt migrate"
    $pending = $true
} else {
    $pending = $migrateStatus | Select-String -Pattern "Pending"
    if ($pending) { Write-Info "Pending migrations detected" } else { Write-Ok "No pending migrations" }
}

if ($pending) {
    Write-Info "Running pending migrations..."
    $migrateResult = docker compose -f $ComposeFile exec -T app php artisan migrate --force 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Err "Migration failed:`n$migrateResult"; exit 1 }
    Write-Ok "Migrations applied"
} else {
    Write-Ok "Database ready"
}

# 10. Seed simulation scenarios only if missing
Write-Info "Checking simulation scenarios..."
$scenarioRaw = docker compose -f $ComposeFile exec -T db psql -U quakeroute -d quakeroute -t -A -c "SELECT count(*) FROM simulation_scenarios;" 2>$null
if ($scenarioRaw -is [array]) { $scenarioRaw = ($scenarioRaw | Select-Object -Last 1) }
$scenarioCount = ($scenarioRaw -replace '\s','').Trim()
if (-not $scenarioCount -or $scenarioCount -eq "0" -or ([int]::TryParse($scenarioCount, [ref]$null) -and [int]$scenarioCount -lt 6)) {
    Write-Info "Seeding simulation scenarios..."
    $seedResult = docker compose -f $ComposeFile exec -T app php artisan db:seed --class=SimulationScenarioSeeder --force 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Warn "Seed failed:`n$seedResult" } else { Write-Ok "Simulation scenarios seeded" }
} else {
    Write-Ok "Simulation scenarios already seeded ($scenarioCount)"
}

Write-Info "Checking road network..."
$roadNodesRaw = docker compose -f $ComposeFile exec -T db psql -U quakeroute -d quakeroute -t -A -c "SELECT count(*) FROM road_nodes;" 2>$null
if ($roadNodesRaw -is [array]) { $roadNodesRaw = ($roadNodesRaw | Select-Object -Last 1) }
$roadNodesCount = ($roadNodesRaw -replace '\s','').Trim()
$destRaw = docker compose -f $ComposeFile exec -T db psql -U quakeroute -d quakeroute -t -A -c "SELECT count(*) FROM destinations;" 2>$null
if ($destRaw -is [array]) { $destRaw = ($destRaw | Select-Object -Last 1) }
$destCount = ($destRaw -replace '\s','').Trim()
if (-not $roadNodesCount -or $roadNodesCount -eq "0" -or -not $destCount -or $destCount -eq "0" -or ([int]::TryParse($roadNodesCount, [ref]$null) -and [int]$roadNodesCount -lt 6) -or ([int]::TryParse($destCount, [ref]$null) -and [int]$destCount -lt 5)) {
    Write-Info "Seeding road network and destinations..."
    $seedResult = docker compose -f $ComposeFile exec -T app php artisan db:seed --force 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Warn "Road network seed failed:`n$seedResult" } else { Write-Ok "Road network and destinations seeded" }
} else {
    Write-Ok "Road network already seeded (nodes $roadNodesCount, destinations $destCount)"
}

# 11. Flutter pub get (only if missing)
if ($flutterAvailable) {
    Write-Info "Checking Flutter dependencies..."
    $dartTool = Join-Path $MobileDir ".dart_tool\package_config.json"
    if (!(Test-Path $dartTool)) {
        Write-Info "Running flutter pub get..."
        Push-Location $MobileDir
        try {
            $pubResult = flutter pub get 2>&1
            if ($LASTEXITCODE -ne 0) { Write-Warn "flutter pub get failed:`n$pubResult" } else { Write-Ok "Flutter dependencies ready" }
        } finally { Pop-Location }
    } else {
        Write-Ok "Flutter dependencies ready"
    }
}

# 12. Verify backend
Write-Info "Verifying backend..."
$healthOk = $false
for ($i=0; $i -lt 5; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8000/up" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp -and $resp.StatusCode -eq 200) { $healthOk = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if ($healthOk) { Write-Ok "Laravel http://localhost:8000/up → 200" } else { Write-Warn "Laravel /up not responding yet — check 'docker compose -f $ComposeFile logs app'" }

# AI key warning (not blocking)
$envRaw = Get-Content $EnvFile -Raw
if ($envRaw -match "AI_API_KEY=\s*$") {
    Write-Warn "AI_API_KEY empty — FakeAIProvider will be used (offline). Set AI_API_KEY in .env for real provider."
}

# Flutter device detection (non-blocking)
if ($flutterAvailable) {
    Write-Info "Detecting Flutter devices..."
    $devices = flutter devices 2>$null | Out-String
    if ($devices -match "No devices|Found 0") {
        Write-Warn "No Flutter device/emulator detected."
        Write-Host "       Run 'flutter emulators --launch <id>' or connect a device, then run 'flutter run -d <device>' in $MobileDir" -ForegroundColor Yellow
    } else {
        Write-Ok "Flutter devices:`n$devices"
        Write-Host "       To start Flutter: cd $MobileDir; flutter run -d <device>" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor White
Write-Host " QuakeRoute Development Environment Ready" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor White
Write-Host " Docker      : Running (quakeroute-app, quakeroute-db healthy)" -ForegroundColor White
Write-Host " PostgreSQL  : Ready (db:5432, pgdata preserved)" -ForegroundColor White
Write-Host " Laravel     : http://localhost:8000" -ForegroundColor White
Write-Host " API         : http://localhost:8000/api/v1" -ForegroundColor White
Write-Host "   Android emulator → http://10.0.2.2:8000/api/v1" -ForegroundColor DarkGray
if ($flutterAvailable) {
    Write-Host " Flutter     : SDK ready, pub get done" -ForegroundColor White
} else {
    Write-Host " Flutter     : SDK not found (backend only)" -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor White
Write-Host " Next: cd quakeroute-mobile/quakeroute-mobile; flutter run -d <device>" -ForegroundColor Cyan
Write-Host " Logs: docker compose -f quakeroute-api/compose.yaml logs -f" -ForegroundColor DarkGray
Write-Host " Stop: .\stop-dev.ps1" -ForegroundColor DarkGray
Write-Host ""

exit 0
