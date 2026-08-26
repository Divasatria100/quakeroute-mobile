#Requires -Version 5.1
<#
.SYNOPSIS
    QuakeRoute Android Emulator Launcher - standalone, AVD-agnostic, safe, idempotent.

.DESCRIPTION
    Detects Flutter/Android tooling, reuses a running emulator if ready,
    otherwise discovers an AVD dynamically, launches it, waits for boot,
    and runs Flutter on the detected Android device. Android emulator API:
    http://10.0.2.2:8000/api/v1 (validated, not rewritten).

.PARAMETER Avd
    Explicit AVD name to launch. If omitted: 0 AVD - error, 1 AVD - auto-select, >1 - error with list.

.PARAMETER TimeoutSeconds
    Boot readiness timeout (default 120s).

.PARAMETER NoRun
    Launch/wait for emulator but skip `flutter run`.

.PARAMETER Stop
    Stop only the emulator launched by this invocation (PID-tracked). Never kills unrelated processes.

.EXAMPLE
    .\launch-android.ps1
    .\launch-android.ps1 -Avd Pixel_6 -TimeoutSeconds 180
    .\launch-android.ps1 -NoRun
    .\launch-android.ps1 -Stop

.NOTES
    PowerShell 5.1 compatible. No hard-coded AVD, no global taskkill, no .env rewrite.
#>
param(
    [string]$Avd = "",
    [int]$TimeoutSeconds = 120,
    [switch]$NoRun,
    [switch]$Stop
)

$ErrorActionPreference = "Continue"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

$Root = $PSScriptRoot
if (-not $Root -or $Root -eq "") { $Root = (Get-Location).Path }

# Resolve Flutter project dir (supports both layouts)
$MobileDirCandidateA = Join-Path $Root "quakeroute-mobile"
$MobileDirCandidateB = $Root
$MobileDir = $null
if (Test-Path (Join-Path $MobileDirCandidateA "pubspec.yaml")) { $MobileDir = $MobileDirCandidateA }
elseif (Test-Path (Join-Path $MobileDirCandidateB "pubspec.yaml")) { $MobileDir = $MobileDirCandidateB }
else { $MobileDir = $MobileDirCandidateA }

$EnvFile = Join-Path $MobileDir ".env"
$EnvExample = Join-Path $MobileDir ".env.example"

Write-Host "==========================================" -ForegroundColor White
Write-Host " QuakeRoute Android Launcher" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White

# - Handle -Stop (ownership-tracked only) -
# Ownership file stores AVD and SERIAL for detached emulator (PID is unreliable for detached qemu)
$OwnershipFile = Join-Path $env:TEMP "quakeroute-emulator.pid"
if ($Stop) {
    if (-not (Test-Path $OwnershipFile)) {
        Write-Info "No emulator owned by this launcher."
        exit 0
    }
    try {
        $content = Get-Content $OwnershipFile -Raw
        $serial = $null
        if ($content -match "SERIAL\s*=\s*(emulator-\d+)") { $serial = $Matches[1] }
        # Resolve adb for -Stop (AdbPath not yet set at this point)
        $adbForStop = $null
        if ($env:ANDROID_HOME -and (Test-Path (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"))) { $adbForStop = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe" }
        elseif ($env:ANDROID_SDK_ROOT -and (Test-Path (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"))) { $adbForStop = Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe" }
        else {
            $maybeAdb = Get-Command adb -ErrorAction SilentlyContinue
            if ($maybeAdb) { $adbForStop = $maybeAdb.Source } else { $adbForStop = "adb" }
        }
        # Fallback: try to resolve via flutter doctor if adb not found
        if (-not (Test-Path $adbForStop)) {
            try {
                $doctorOut = & flutter doctor -v 2>&1 | Out-String
                if ($doctorOut -match "Android SDK at (.+)") {
                    $sdkTry = $Matches[1].Trim()
                    $adbTry = Join-Path $sdkTry "platform-tools\adb.exe"
                    if (Test-Path $adbTry) { $adbForStop = $adbTry }
                }
            } catch {}
        }
        if ($serial) {
            # Verify serial still exists and is emulator
            $devs = @()
            try { $devs = & $adbForStop devices 2>&1 } catch {}
            $found = $false
            foreach ($line in $devs) { if ($line -match "^\s*$serial\s+device") { $found = $true; break } }
            if (-not $found) {
                Write-Warn "Emulator $serial not found or not running. Nothing to stop."
                Remove-Item $OwnershipFile -Force -ErrorAction SilentlyContinue
                exit 0
            }
            Write-Info "Stopping owned emulator $serial..."
            try { & $adbForStop -s $serial emu kill 2>&1 | Out-Null } catch {}
            Start-Sleep -Seconds 3
            $devs2 = @()
            try { $devs2 = & $adbForStop devices 2>&1 } catch {}
            $stillThere = $false
            foreach ($line in $devs2) { if ($line -match "^\s*$serial\s+") { $stillThere = $true; break } }
            if (-not $stillThere) {
                Write-Ok "Emulator $serial stopped."
                Remove-Item $OwnershipFile -Force -ErrorAction SilentlyContinue
                exit 0
            } else {
                Write-Warn "Emulator $serial did not stop gracefully. Trying PID fallback if available."
                if ($content -match "PID\s*=\s*(\d+)") {
                    $pidInt = [int]$Matches[1]
                    $proc = Get-Process -Id $pidInt -ErrorAction SilentlyContinue
                    if ($proc) { Stop-Process -Id $pidInt -ErrorAction SilentlyContinue; Write-Ok "Emulator process PID $pidInt stopped (fallback)." }
                }
                Remove-Item $OwnershipFile -Force -ErrorAction SilentlyContinue
                exit 0
            }
        } else {
            # Legacy format: PID only
            $savedPid = $content.Trim()
            $pidInt = 0
            if ([int]::TryParse($savedPid, [ref]$pidInt)) {
                $proc = Get-Process -Id $pidInt -ErrorAction SilentlyContinue
                if ($proc -and $proc.ProcessName -match "emulator|qemu") {
                    Write-Info "Stopping owned emulator PID $pidInt (legacy)..."
                    Stop-Process -Id $pidInt -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Write-Ok "Emulator stopped (PID $pidInt)."
                    Remove-Item $OwnershipFile -Force -ErrorAction SilentlyContinue
                    exit 0
                }
            }
            Write-Warn "Emulator ownership cannot be verified. Nothing stopped."
            exit 0
        }
    } catch {
        Write-Warn "Emulator ownership cannot be verified. Nothing stopped."
        exit 0
    }
}

# - Phase 1: Environment validation -

# Flutter
Write-Info "Checking Flutter..."
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) { Write-Err "Flutter not found. Install https://flutter.dev and ensure flutter is on PATH."; exit 1 }
$flutterVersion = $null
try { $flutterVersion = & flutter --version 2>&1 | Select-Object -First 1 } catch {}
if (-not $flutterVersion) { Write-Err "Flutter not working. Run 'flutter doctor -v'."; exit 1 }
Write-Ok "Flutter detected: $flutterVersion"

# Android SDK resolution
Write-Info "Resolving Android SDK..."
$SdkCandidates = @()
if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { $SdkCandidates += $env:ANDROID_HOME }
if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) { $SdkCandidates += $env:ANDROID_SDK_ROOT }
# Try flutter doctor -v to parse SDK path
try {
    $doctorOut = & flutter doctor -v 2>&1 | Out-String
    if ($doctorOut -match "Android SDK at (.+)") {
        $sdkFromDoctor = $Matches[1].Trim()
        if (Test-Path $sdkFromDoctor) { $SdkCandidates += $sdkFromDoctor }
    }
} catch {}
# Fallbacks (case-insensitive, Windows LOCALAPPDATA)
$localApp = $env:LOCALAPPDATA
if ($localApp) {
    $SdkCandidates += (Join-Path $localApp "Android\Sdk")
    $SdkCandidates += (Join-Path $localApp "Android\sdk")
}
# Unique candidates
$SdkCandidates = $SdkCandidates | Select-Object -Unique

$SdkRoot = $null
$AdbPath = $null
$EmulatorPath = $null
foreach ($cand in $SdkCandidates) {
    $adbTry = Join-Path $cand "platform-tools\adb.exe"
    $emuTry = Join-Path $cand "emulator\emulator.exe"
    if ((Test-Path $adbTry) -and (Test-Path $emuTry)) { $SdkRoot = $cand; $AdbPath = $adbTry; $EmulatorPath = $emuTry; break }
}
if (-not $SdkRoot) {
    # Last resort: search adb on PATH
    $adbOnPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbOnPath) {
        $AdbPath = $adbOnPath.Source
        $maybeSdk = Split-Path (Split-Path $AdbPath -Parent) -Parent
        $emuTry = Join-Path $maybeSdk "emulator\emulator.exe"
        if (Test-Path $emuTry) { $SdkRoot = $maybeSdk; $EmulatorPath = $emuTry }
    }
}
if (-not $SdkRoot -or -not (Test-Path $AdbPath) -or -not (Test-Path $EmulatorPath)) {
    Write-Err "Android SDK emulator/adb not found."
    Write-Info "Checked candidates:"
    foreach ($c in $SdkCandidates) { Write-Host "  - $c" -ForegroundColor DarkGray }
    Write-Info "Ensure Android SDK is installed and ANDROID_HOME is set, or fix SDK location."
    Write-Info "Run 'flutter doctor -v' for details."
    exit 1
}
Write-Ok "Android SDK detected: $SdkRoot"
Write-Ok "ADB detected: $AdbPath"
Write-Ok "Emulator detected: $EmulatorPath"

# ADB version check
try {
    $adbVer = & $AdbPath version 2>&1 | Select-Object -First 1
    if (-not $adbVer) { throw "no output" }
    Write-Ok "ADB version: $adbVer"
} catch {
    Write-Err "ADB not working at $AdbPath"
    exit 1
}

# - Phase 2: API validation (read-only) -
Write-Info "Validating API configuration..."
$apiUrl = $null
$envToCheck = $null
if (Test-Path $EnvFile) { $envToCheck = $EnvFile }
elseif (Test-Path $EnvExample) { $envToCheck = $EnvExample }
if ($envToCheck) {
    try {
        $content = Get-Content $envToCheck -Raw
        if ($content -match "API_BASE_URL\s*=\s*(.+)") {
            $apiUrl = $Matches[1].Trim().Trim('"').Trim("'")
        }
    } catch {}
}
if ($apiUrl) {
    if ($apiUrl -like "*10.0.2.2:8000*") {
        Write-Ok "Android API URL: $apiUrl"
    } else {
        Write-Warn "API_BASE_URL is not configured for Android emulator: $apiUrl"
        Write-Host "       Expected: http://10.0.2.2:8000/api/v1 for emulator - host" -ForegroundColor DarkGray
    }
} else {
    Write-Warn "API_BASE_URL could not be verified (no .env/.env.example or key missing)."
}

# - Phase 3: Detect already-running emulator -
Write-Info "Checking for running Android emulator..."

function Get-AdbDevices {
    param([string]$Adb)
    $out = @()
    try { $out = & $Adb devices 2>&1 } catch { return @() }
    return $out
}

function Parse-EmulatorDevices {
    param([string[]]$Lines)
    $result = @()
    foreach ($line in $Lines) {
        $trim = $line.Trim()
        if ($trim -match "^(emulator-\d+)\s+(device|offline|unauthorized)$") {
            $result += @{ Serial = $Matches[1]; State = $Matches[2] }
        }
    }
    return $result
}

# Retry a few times for adb to stabilize (transient empty list)
$adbDevicesOut = @()
$emuDevices = @()
for ($retry = 0; $retry -lt 5; $retry++) {
    $adbDevicesOut = Get-AdbDevices -Adb $AdbPath
    $emuDevices = Parse-EmulatorDevices -Lines $adbDevicesOut
    if ($emuDevices.Count -gt 0) { break }
    # Fallback: flutter devices may see emulator even if adb transiently empty
    try {
        $fCheck = & flutter devices 2>&1 | Out-String
        if ($fCheck -match "(emulator-\d+)") {
            $emuDevices = @(@{ Serial = $Matches[1]; State = "device" })
            break
        }
    } catch {}
    Start-Sleep -Seconds 2
}

$readySerial = $null
$existingSerial = $null
if ($emuDevices -and $emuDevices.Count -gt 0) {
    # Prefer device over offline/unauthorized, but reuse any existing emulator
    $deviceEntry = $emuDevices | Where-Object { $_.State -eq "device" } | Select-Object -First 1
    if ($deviceEntry) { $existingSerial = $deviceEntry.Serial }
    else { $existingSerial = $emuDevices[0].Serial }
}
if ($existingSerial) {
    # Check if already booted
    $bootCompleted = ""
    try { $bootCompleted = & $AdbPath -s $existingSerial shell getprop sys.boot_completed 2>&1 | Select-Object -First 1 } catch {}
    $bootCompleted = $bootCompleted.Trim()
    if ($bootCompleted -eq "1") {
        Write-Ok "Android emulator already running."
        Write-Ok "Reusing existing emulator: $existingSerial"
        $androidDeviceId = $existingSerial
        $readySerial = $existingSerial
    } else {
        Write-Info "Found existing emulator $existingSerial (state: $(($emuDevices | Where-Object { $_.Serial -eq $existingSerial } | Select-Object -First 1).State)) - waiting for boot..."
        $androidDeviceId = $existingSerial
        $readySerial = $null
        # Wait for boot without launching new
        Write-Info "Waiting for emulator to become ready (timeout ${TimeoutSeconds}s)..."
        $elapsed = 0
        $interval = 2
        $bootDone = $false
        while ($elapsed -lt $TimeoutSeconds) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
            $stateVal = ""
            try { $stateVal = & $AdbPath -s $existingSerial get-state 2>&1 | Select-Object -First 1 } catch {}
            if ($stateVal.Trim() -ne "device") { Write-Host "[INFO] Emulator booting... ${elapsed}s / ${TimeoutSeconds}s (state: $($stateVal.Trim()))" -ForegroundColor DarkGray; continue }
            $boot = ""
            try { $boot = & $AdbPath -s $existingSerial shell getprop sys.boot_completed 2>&1 | Select-Object -First 1 } catch {}
            if ($boot.Trim() -eq "1") { $bootDone = $true; break }
            Write-Host "[INFO] Emulator booting... ${elapsed}s / ${TimeoutSeconds}s" -ForegroundColor DarkGray
        }
        if ($bootDone) {
            Write-Ok "Android emulator ready: $existingSerial"
            $readySerial = $existingSerial
        } else {
            Write-Err "Android emulator did not become ready within ${TimeoutSeconds} seconds."
            Write-Host "--- adb devices ---" -ForegroundColor Yellow
            try { & $AdbPath devices 2>&1 | Write-Host -ForegroundColor DarkGray } catch {}
            exit 1
        }
    }
}
if ($readySerial) {
    $androidDeviceId = $readySerial
}
if (-not $readySerial) {
    # No existing emulator - proceed to AVD discovery
    # - Phase 4: AVD discovery -
    Write-Info "Discovering Android Virtual Devices..."

    $avds = @()
    try {
        # Primary: flutter emulators (most reliable, avoids emulator binary path quirks)
        $flutterEmuOut = & flutter emulators 2>&1 | Out-String
        foreach ($flLine in ($flutterEmuOut -split "`n")) {
            $trimFl = $flLine.Trim()
            if ($trimFl -like "*android*") {
                $firstTok = ($trimFl -split "\s+")[0].Trim()
                if ($firstTok -match "^[A-Za-z0-9_\-]+$" -and $firstTok -ne "Id" -and $firstTok -ne "android") { $avds = $avds + @($firstTok) }
            }
        }

        # Fallback: emulator -list-avds
        if ($avds.Count -eq 0) {
            $emuOutStr = & $EmulatorPath -list-avds 2>&1 | Out-String
            foreach ($line in ($emuOutStr -split "`n")) {
                $t = $line.Trim()
                if ($t -ne "" -and $t -notmatch "^(INFO|WARN|ERROR)") { $avds = $avds + @($t) }
            }
        }
    } catch {
        Write-Err "Failed to list AVDs via emulator -list-avds."
        Write-Info "Check emulator at $EmulatorPath"
        exit 1
    }
    # Filter empty (force array to avoid scalar unwrap)
    $avds = @($avds | Where-Object { $_ -ne "" } | Select-Object -Unique)

    if ($Avd -ne "") {
        if (-not ($avds -contains $Avd)) {
            Write-Err "AVD '$Avd' not found."
            if ($avds.Count -gt 0) {
                Write-Host "Available Android Virtual Devices:" -ForegroundColor Yellow
                foreach ($a in $avds) { Write-Host "  - $a" -ForegroundColor Yellow }
            }
            exit 1
        }
        $selectedAvd = $Avd
        Write-Ok "Selected AVD (explicit): $selectedAvd"
    } else {
        if ($avds.Count -eq 0) {
            Write-Err "No Android Virtual Device available."
            Write-Info "Create one via Android Studio AVD Manager or 'flutter emulators --create'."
            exit 1
        } elseif ($avds.Count -eq 1) {
            $selectedAvd = $avds[0]
            Write-Ok "Auto-selected AVD: $selectedAvd"
        } else {
            Write-Host "Available Android Virtual Devices:" -ForegroundColor Yellow
            foreach ($a in $avds) { Write-Host "  - $a" -ForegroundColor Yellow }
            Write-Err "Multiple AVDs found. Use -Avd <name>."
            Write-Host "Example: .\launch-android.ps1 -Avd `"$($avds[0])`"" -ForegroundColor Cyan
            exit 1
        }
    }

    # - Phase 5: Launch emulator - detached from launcher console
    # Use cmd /c start to create independent process group (CREATE_NEW_CONSOLE).
    # This ensures Ctrl+C on the launcher (PowerShell/Code Runner) does NOT
    # propagate to emulator.exe / qemu. WindowStyle Hidden previously hid the
    # console but still kept qemu in same console group, so Code Runner killed it.
    # Now: launcher -> cmd (hidden, exits immediately) -> emulator (detached, GUI Normal)
    Write-Info "Launching Android emulator: $selectedAvd (detached)"
    try {
        $null = Start-Process -FilePath "cmd.exe" -ArgumentList "/c start `"`" `"$EmulatorPath`" -avd $selectedAvd" -WindowStyle Hidden -PassThru
        Write-Ok "Emulator launch requested (detached): $selectedAvd"
    } catch {
        Write-Err "Failed to launch emulator: $_"
        exit 1
    }

    # - Phase 6: Wait for boot -
    Write-Info "Waiting for emulator to become ready (timeout ${TimeoutSeconds}s)..."
    $elapsed = 0
    $interval = 2
    $androidDeviceId = $null

    while ($elapsed -lt $TimeoutSeconds) {
        Start-Sleep -Seconds $interval
        $elapsed += $interval

        $devicesNow = Get-AdbDevices -Adb $AdbPath
        $emusNow = Parse-EmulatorDevices -Lines $devicesNow
        # Find any emulator in device state with boot_completed
        foreach ($d in $emusNow) {
            if ($d.State -ne "device") { continue }
            $s = $d.Serial
            $stateVal = ""
            try { $stateVal = & $AdbPath -s $s get-state 2>&1 | Select-Object -First 1 } catch {}
            if ($stateVal.Trim() -ne "device") { continue }
            $boot = ""
            try { $boot = & $AdbPath -s $s shell getprop sys.boot_completed 2>&1 | Select-Object -First 1 } catch {}
            if ($boot.Trim() -ne "1") { continue }
            $androidDeviceId = $s
            break
        }
        if ($androidDeviceId) { break }
        Write-Host "[INFO] Emulator booting... ${elapsed}s / ${TimeoutSeconds}s" -ForegroundColor DarkGray
    }

    if (-not $androidDeviceId) {
        Write-Err "Android emulator did not become ready within ${TimeoutSeconds} seconds."
        Write-Host "--- adb devices ---" -ForegroundColor Yellow
        try { & $AdbPath devices 2>&1 | Write-Host -ForegroundColor DarkGray } catch {}
        Write-Host "--- flutter devices ---" -ForegroundColor Yellow
        try { & flutter devices 2>&1 | Write-Host -ForegroundColor DarkGray } catch {}
        Write-Info "Try increasing timeout: .\launch-android.ps1 -TimeoutSeconds 180"
        exit 1
    }
    Write-Ok "Android emulator ready: $androidDeviceId"
    # Save ownership for detached emulator (AVD + serial)
    try {
        $ownershipContent = "AVD=$selectedAvd`nSERIAL=$androidDeviceId`n"
        Set-Content -Path $OwnershipFile -Value $ownershipContent -Force
    } catch {}
}

# At this point $androidDeviceId holds ready emulator serial (either reused or newly launched)
if (-not $androidDeviceId) {
    # Fallback: try to re-detect from adb
    $finalDevices = Get-AdbDevices -Adb $AdbPath
    $finalEmus = Parse-EmulatorDevices -Lines $finalDevices | Where-Object { $_.State -eq "device" }
    if ($finalEmus -and $finalEmus.Count -gt 0) { $androidDeviceId = $finalEmus[0].Serial }
}

# - GUI readiness check (separate from adb boot) -
# adb ready proves Android booted, not that Qt window is visible
Write-Info "Checking emulator GUI window..."
$guiReady = $false
$guiTimeout = 10
$guiElapsed = 0
# Try to associate with launched PID if available, otherwise any qemu
$launchedPidForGui = $null
if ($proc -and $proc.Id) { $launchedPidForGui = $proc.Id }
while ($guiElapsed -lt $guiTimeout) {
    try {
        $qemuCandidates = @()
        if ($launchedPidForGui) {
            # Find child qemu of the launched emulator process
            try {
                $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$launchedPidForGui" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "qemu*" }
                foreach ($c in $children) {
                    $qp = Get-Process -Id $c.ProcessId -ErrorAction SilentlyContinue
                    if ($qp -and $qp.MainWindowHandle -ne 0 -and $qp.MainWindowTitle -like "Android Emulator*") { $qemuCandidates += $qp }
                }
            } catch {}
        }
        if (-not $qemuCandidates -or $qemuCandidates.Count -eq 0) {
            $qemuCandidates = Get-Process -Name "qemu-system-x86_64" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "Android Emulator*" }
        }
        if (-not $qemuCandidates -or $qemuCandidates.Count -eq 0) {
            $qemuCandidates = Get-Process -Name "qemu-system-x86_64" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
        }
        if ($qemuCandidates -and $qemuCandidates.Count -gt 0) { $guiReady = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
    $guiElapsed += 1
}
if ($guiReady) {
    Write-Ok "Emulator GUI window detected."
} else {
    Write-Warn "Android emulator is booted but GUI window was not detected."
    Write-Info "The emulator may still be starting its desktop window."
    Write-Info "Verify the emulator window manually."
}

# - Phase 7: Flutter device verification -
Write-Info "Verifying Flutter can detect Android device..."
$flutterAndroidId = $null
# Wait up to 30s for flutter devices to list emulator
$flutterWait = 30
$flutterElapsed = 0
while ($flutterElapsed -lt $flutterWait) {
    $fOut = ""
    try { $fOut = & flutter devices 2>&1 | Out-String } catch {}
    # Prefer exact serial match
    if ($androidDeviceId -and $fOut -match $androidDeviceId) { $flutterAndroidId = $androidDeviceId; break }
    # Fallback: find emulator- prefix
    if ($fOut -match "(emulator-\d+)") { $flutterAndroidId = $Matches[1]; break }
    Start-Sleep -Seconds 2
    $flutterElapsed += 2
}
if (-not $flutterAndroidId) {
    # Still try with adb serial directly
    if ($androidDeviceId) { $flutterAndroidId = $androidDeviceId; Write-Warn "Flutter devices did not list emulator explicitly, using ADB serial: $flutterAndroidId" }
    else {
        Write-Err "Flutter cannot detect Android emulator."
        Write-Host "--- flutter devices ---" -ForegroundColor Yellow
        try { & flutter devices 2>&1 | Write-Host -ForegroundColor DarkGray } catch {}
        exit 1
    }
}
Write-Ok "Flutter Android device detected: $flutterAndroidId"

# - Phase 8: NoRun check -
if ($NoRun) {
    Write-Ok "Android emulator ready."
    Write-Info "-NoRun specified. Flutter run skipped."
    exit 0
}

# - Phase 9: Flutter run -
Write-Info "Running Flutter on $flutterAndroidId..."
Write-Host "[INFO] Executing: flutter run -d $flutterAndroidId" -ForegroundColor Cyan
Push-Location $MobileDir
try {
    & flutter run -d $flutterAndroidId
    $runExit = $LASTEXITCODE
    if ($runExit -ne 0) {
        Write-Err "flutter run failed (exit $runExit)."
        exit $runExit
    }
} finally {
    Pop-Location
}

exit 0
