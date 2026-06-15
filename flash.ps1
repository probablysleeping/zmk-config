# ZMK Corne-J Flash Helper
# Run from PowerShell: .\flash.ps1

$firmware = @(
    @{ name = "Dongle";        file = "eyelash_corne_dongle.uf2" },
    @{ name = "Left Half";     file = "eyelash_corne_left_peripheral.uf2" },
    @{ name = "Right Half";    file = "eyelash_corne_right_peripheral.uf2" }
)

$resetFile = "settings_reset-nice_nano_v2-zmk.uf2"

function Wait-ForDrive {
    Write-Host "  Waiting for NRF52BOOT drive..." -ForegroundColor Yellow
    $timeout = 30
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -match '^[D-Z]$' } |
            ForEach-Object { "$($_.Name):\" } |
            Where-Object { Test-Path (Join-Path $_ "INFO_UF2.TXT") }
        if ($drive) {
            Write-Host "  Found bootloader drive: $drive" -ForegroundColor Green
            return $drive
        }
        Start-Sleep -Seconds 1
        $elapsed++
    }
    Write-Host "  Timed out waiting for drive. Did you double-tap reset?" -ForegroundColor Red
    return $null
}

function Copy-Firmware($drive, $file) {
    if (-not (Test-Path $file)) {
        Write-Host "  ERROR: $file not found in current directory." -ForegroundColor Red
        Write-Host "  Download firmware.zip from GitHub Actions and extract it here." -ForegroundColor Red
        return $false
    }
    Write-Host "  Copying $file to $drive..." -ForegroundColor Cyan
    Copy-Item $file $drive -Force
    Write-Host "  Done. Device will reboot." -ForegroundColor Green
    return $true
}

function Pause-ForUser($msg) {
    Write-Host ""
    Write-Host $msg -ForegroundColor White
    Write-Host "Press ENTER when ready..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# ---- Check firmware files exist ----
Write-Host ""
Write-Host "=== ZMK Corne-J Flash Script ===" -ForegroundColor Magenta
Write-Host ""

$missing = @()
foreach ($fw in $firmware) { if (-not (Test-Path $fw.file)) { $missing += $fw.file } }
if (-not (Test-Path $resetFile)) { $missing += $resetFile }

if ($missing.Count -gt 0) {
    Write-Host "Missing firmware files:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Download firmware.zip from GitHub Actions, extract it, and run this script from that folder." -ForegroundColor Yellow
    exit 1
}

Write-Host "All firmware files found." -ForegroundColor Green

# ---- Flash each device ----
foreach ($fw in $firmware) {
    Write-Host ""
    Write-Host "--- Flashing: $($fw.name) ---" -ForegroundColor Magenta

    # Step 1: settings_reset
    Pause-ForUser "Step 1/$($firmware.Count * 2 - 1): Plug in $($fw.name) via USB-C, then DOUBLE-TAP its reset button."
    $drive = Wait-ForDrive
    if (-not $drive) { exit 1 }

    Write-Host "  Copying settings_reset first to clear old pairing..." -ForegroundColor Cyan
    Copy-Item $resetFile $drive -Force
    Write-Host "  Done. Device will reboot." -ForegroundColor Green
    Start-Sleep -Seconds 3

    # Step 2: actual firmware
    Pause-ForUser "Step 2: DOUBLE-TAP reset again on $($fw.name) to re-enter bootloader."
    $drive = Wait-ForDrive
    if (-not $drive) { exit 1 }

    $ok = Copy-Firmware $drive $fw.file
    if (-not $ok) { exit 1 }
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "=== All devices flashed! ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Unplug everything." -ForegroundColor Gray
Write-Host "  2. Power on both keyboard halves." -ForegroundColor Gray
Write-Host "  3. Plug the dongle into your PC." -ForegroundColor Gray
Write-Host "  4. Wait ~10 seconds for halves to pair with the dongle." -ForegroundColor Gray
Write-Host "  5. The dongle should appear as a keyboard immediately (no BT pairing needed on PC)." -ForegroundColor Gray
Write-Host ""
