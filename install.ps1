# Muxit installer for Windows
#
# Usage (end-user):
#   irm https://raw.githubusercontent.com/muxit-io/muxit/main/install.ps1 | iex
#
# Or with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/muxit-io/muxit/main/install.ps1))) -InstallPath "C:\Tools\Muxit"
#
# This script:
#   1. Queries the GitHub Releases API for the latest Muxit release.
#   2. Downloads the muxit-win-x64-v<version>.zip release archive and checksums.txt.
#   3. Verifies the SHA256.
#   4. Extracts into %LOCALAPPDATA%\Muxit (or -InstallPath override).
#      Existing workspace/ directory is preserved (never overwritten).
#   5. Creates a Start Menu shortcut to muxit.exe.
#   6. Prints the launch URL.

[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA 'Muxit'),
    [switch]$NoShortcut,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # speeds up Invoke-WebRequest for zip download

$repo = 'muxit-io/muxit'
# Release archives are versioned (e.g. "muxit-win-x64-v0.3.0.zip"). We match by
# pattern so legacy un-versioned assets ("muxit-win-x64.zip") still resolve.
$zipPattern = 'muxit-win-x64*.zip'
$checksumName = 'checksums.txt'

function Write-Section($msg) {
    Write-Host ""
    Write-Host "== $msg ==" -ForegroundColor Cyan
}

Write-Section "Muxit Installer"
Write-Host "  Install path: $InstallPath"

# 1. Fetch release metadata
Write-Section "Fetching latest release"
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing
} catch {
    throw "Failed to reach GitHub Releases API: $($_.Exception.Message)"
}
$tag = $release.tag_name
Write-Host "  Version: $tag"

$zipAsset = $release.assets | Where-Object { $_.name -like $zipPattern } | Select-Object -First 1
if (-not $zipAsset) { throw "Release $tag is missing a $zipPattern asset" }
$zipName = $zipAsset.name

$checksumAsset = $release.assets | Where-Object { $_.name -eq $checksumName } | Select-Object -First 1

# 2. Download zip + checksums
Write-Section "Downloading $zipName"
$tempDir = Join-Path $env:TEMP "muxit-install-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$zipPath = Join-Path $tempDir $zipName
Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing
$sizeMB = '{0:N1}' -f ((Get-Item $zipPath).Length / 1MB)
Write-Host "  Downloaded ($sizeMB MB)"

# 3. Verify checksum
if ($checksumAsset) {
    Write-Section "Verifying checksum"
    $checksumPath = Join-Path $tempDir $checksumName
    Invoke-WebRequest -Uri $checksumAsset.browser_download_url -OutFile $checksumPath -UseBasicParsing
    $expected = (Get-Content $checksumPath | Where-Object { $_ -match "\s+$zipName$" } | Select-Object -First 1)
    if ($expected) {
        $expectedHash = ($expected -split '\s+')[0].ToLower()
        $actualHash = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLower()
        if ($expectedHash -ne $actualHash) {
            throw "Checksum mismatch! Expected $expectedHash, got $actualHash"
        }
        Write-Host "  OK ($actualHash)"
    } else {
        Write-Warning "No SHA256 entry for $zipName in $checksumName; skipping verification."
    }
} else {
    Write-Warning "No checksums.txt asset in release; skipping verification."
}

# 4. Stop any running muxit.exe so we can overwrite its files
$running = Get-Process -Name 'muxit' -ErrorAction SilentlyContinue
if ($running) {
    Write-Section "Stopping running Muxit"
    $running | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# 5. Extract into install path. Preserve an existing workspace/ directory if present.
Write-Section "Installing to $InstallPath"
New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

$existingWorkspace = Join-Path $InstallPath 'workspace'
$hasWorkspace = Test-Path $existingWorkspace
if ($hasWorkspace) {
    Write-Host "  Preserving existing workspace/ directory"
}

# Remove old server files (but keep workspace/ and anything the user added there).
# We scrub only the top-level files and the directories we ship.
$shipped = @('muxit.exe', 'muxit.pdb')
Get-ChildItem -Path $InstallPath -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Extension -in @('.dll', '.exe', '.pdb', '.json', '.xml') -or $_.Name -in $shipped) {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}
foreach ($sub in @('wwwroot', 'runtimes', 'Assets', 'workspace-template')) {
    $p = Join-Path $InstallPath $sub
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}

Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force
Write-Host "  Extracted."

# 6. Start Menu shortcut
$exe = Join-Path $InstallPath 'muxit.exe'
if (-not (Test-Path $exe)) {
    throw "muxit.exe not found at $exe after extraction"
}

# 6a. Visual C++ runtime — needed by the tray icon's native library
# (notification_icon.dll imports VCRUNTIME140.dll). A clean Windows image does
# not have it; Windows Sandbox is the usual place people hit this. Non-fatal:
# without it everything works except the tray icon.
$vcRuntime = Join-Path $env:SystemRoot 'System32\vcruntime140.dll'
if (-not (Test-Path $vcRuntime)) {
    Write-Section "Installing Visual C++ runtime (needed for the tray icon)"
    $vcRedist = Join-Path $tempDir 'vc_redist.x64.exe'
    try {
        Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' `
            -OutFile $vcRedist -UseBasicParsing
        $proc = Start-Process -FilePath $vcRedist `
            -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
        # 3010 = success, reboot required.
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
            Write-Host "  Installed."
        } else {
            throw "vc_redist.x64.exe exited with $($proc.ExitCode)"
        }
    } catch {
        Write-Warning "Could not install the Visual C++ runtime: $($_.Exception.Message)"
        Write-Host "  Muxit will run fine, but the system tray icon will be unavailable."
        Write-Host "  To fix it later, install https://aka.ms/vs/17/release/vc_redist.x64.exe (needs admin)."
    }
}

if (-not $NoShortcut) {
    Write-Section "Creating Start Menu shortcut"
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $lnkPath = Join-Path $startMenu 'Muxit.lnk'
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $exe
        $lnk.WorkingDirectory = $InstallPath
        $lnk.Description = 'Muxit — hardware orchestration platform'
        # muxit.exe embeds the Muxit icon (see <ApplicationIcon> in
        # MuxitServer.csproj), which a shortcut would normally inherit. Point at
        # it explicitly anyway: on an upgrade over an older install the shell
        # keeps serving the .lnk's cached icon, and re-stating the source is
        # what makes it re-read the new exe.
        $lnk.IconLocation = "$exe,0"
        $lnk.Save()
        Write-Host "  $lnkPath"
    } catch {
        Write-Warning "Could not create Start Menu shortcut: $($_.Exception.Message)"
    }
}

# 7. Cleanup temp files
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# 8. Report + optionally launch
Write-Section "Done"
Write-Host "  Installed: $exe"
Write-Host "  Version:   $tag"
Write-Host ""
Write-Host "  Launch Muxit:" -ForegroundColor Green
Write-Host "    & `"$exe`""
Write-Host "  Then open http://127.0.0.1:8765 in your browser."
Write-Host ""

if (-not $NoLaunch) {
    Write-Host "Starting Muxit..." -ForegroundColor Green
    Start-Process -FilePath $exe -WorkingDirectory $InstallPath
}
