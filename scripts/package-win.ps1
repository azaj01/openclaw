# package-flutter.ps1 - Prepare Flutter runtime assets
$ErrorActionPreference = "Stop"
# Correctly resolve ROOT relative to scripts folder or CWD
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $PSScriptRoot) { $PSScriptRoot = "$PSScriptRoot/scripts" }
$ROOT = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$ROOT\package.json")) { $ROOT = (Get-Location).Path }

Write-Host "Project Root: $ROOT" -ForegroundColor Gray

$BUILD   = "$ROOT\build\flutter-assets"
$NODEJS  = "24.0.0"
$ARCH    = "win-x64"
$NODEURL = "https://nodejs.org/dist/v$NODEJS/node-v$NODEJS-$ARCH.zip"
$NODZIP  = "$BUILD\node-$ARCH.zip"

Write-Host "=== OpenClaw Flutter Asset Packager ===" -ForegroundColor Cyan
Write-Host "Output: $BUILD"

if (Test-Path $BUILD) { 
    Write-Host "Cleaning $BUILD..."
    Remove-Item -Recurse -Force $BUILD 
}
New-Item -ItemType Directory -Force -Path $BUILD | Out-Null

# 1. Download Portable Node
Write-Host "[1/3] Downloading Portable Node.js ($NODEJS)..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $NODEURL -OutFile $NODZIP -UseBasicParsing

# 2. Prepare Local OpenClaw package
Write-Host "[2/3] Packing local OpenClaw package..." -ForegroundColor Yellow
$tempDir = "$BUILD\temp_openclaw"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Clear any previous local packs
Get-Item -Path "$ROOT\openclaw-*.tgz" -ErrorAction SilentlyContinue | Remove-Item -Force

Set-Location $ROOT
Write-Host "      Running pnpm pack..."
$packFileRaw = (pnpm pack) | Select-String "openclaw-.*\.tgz"
if (-not $packFileRaw) { throw "pnpm pack failed" }
$packFileName = ($packFileRaw -split " ")[-1].Trim()
$packFilePath = "$ROOT\$packFileName"

Write-Host "      Pack file generated: $packFileName"

Write-Host "      Extracting to $tempDir..."
tar -xf $packFilePath -C $tempDir
Remove-Item $packFilePath

# 3. Install production dependencies
Write-Host "      Installing production dependencies..."
Set-Location "$tempDir\package"

# Ensure we don't try to link workspace:* packages which break in standalone
# We use pnpm to install to be consistent with the repo
$env:NPM_CONFIG_UPDATE_NOTIFIER="false"
$env:NODE_LLAMA_CPP_SKIP_DOWNLOAD="1"

# We use npm install here as it's more reliable for standalone 'package' folder 
# without needing a full pnpm workspace setup in the temp dir.
npm install --omit=dev --ignore-scripts --no-audit --no-fund

# 4. Create final zip
Write-Host "[3/3] Creating final openclaw.zip bundle..." -ForegroundColor Yellow
Set-Location $tempDir
$zipPath = "$BUILD\openclaw.zip"
Compress-Archive -Path "package" -DestinationPath $zipPath -Force

Set-Location $ROOT
Remove-Item -Recurse -Force $tempDir

Write-Host "`n=== Done ===" -ForegroundColor Green
$nodeSize = (Get-Item $NODZIP).Length / 1MB
$ocSize = (Get-Item $zipPath).Length / 1MB
Write-Host "Node zip: $([math]::Round($nodeSize, 1)) MB -> $NODZIP"
Write-Host "OpenClaw zip: $([math]::Round($ocSize, 1)) MB -> $zipPath"
Write-Host "`nCopy these two files into your Flutter project's assets/runtime/ folder!" -ForegroundColor Yellow
