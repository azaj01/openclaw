# package-flutter.ps1 - Prepare Flutter runtime assets
$ErrorActionPreference = "Stop"
# Correctly resolve ROOT relative to scripts folder or CWD
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $PSScriptRoot) { $PSScriptRoot = "$PSScriptRoot/scripts" }
$ROOT = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$ROOT\package.json")) { $ROOT = (Get-Location).Path }

Write-Host "Project Root: $ROOT" -ForegroundColor Gray

$BUILD   = "$ROOT\build\flutter-assets-v2"
$NODEJS  = "24.0.0"
$ARCH    = "win-x64"
$NODEURL = "https://nodejs.org/dist/v$NODEJS/node-v$NODEJS-$ARCH.zip"
$NODZIP  = "$BUILD\node-$ARCH.zip"

Write-Host "=== OpenClaw Flutter Asset Packager ===" -ForegroundColor Cyan
Write-Host "Output: $BUILD"

if (Test-Path $BUILD) { 
    Write-Host "Cleaning $BUILD..."
    Remove-Item -Recurse -Force $BUILD -ErrorAction SilentlyContinue
}
if (-not (Test-Path $BUILD)) {
    New-Item -ItemType Directory -Force -Path $BUILD | Out-Null
}
# 1. Download Portable Node
Write-Host "[1/3] Downloading Portable Node.js ($NODEJS)..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $NODEURL -OutFile $NODZIP -UseBasicParsing

# 2. Prepare Local OpenClaw package
Write-Host "[2/3] Packing local OpenClaw package..." -ForegroundColor Yellow
$tempDir = "$BUILD\temp_openclaw"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

Write-Host "      Copying artifacts manually using robocopy for reliability..."
$destPackage = "$tempDir\package"
New-Item -ItemType Directory -Force -Path $destPackage | Out-Null

# Files in ROOT
$rootFiles = @("CHANGELOG.md", "LICENSE", "openclaw.mjs", "README.md", "package.json")
foreach ($f in $rootFiles) {
    if (Test-Path "$ROOT\$f") { Copy-Item "$ROOT\$f" "$destPackage\" -Force }
}

# Directories (using robocopy for robustness and speed)
$dirs = @("assets", "dist", "docs", "skills", "scripts")
foreach ($d in $dirs) {
    if (Test-Path "$ROOT\$d") {
        # /E: subdirs including empty, /XD: exclude dirs, /XF: exclude files
        # Skip .map files and generated docs
        $excludeDirs = ".generated", ".i18n"
        $excludeFiles = "*.map"
        robocopy "$ROOT\$d" "$destPackage\$d" /E /XD $excludeDirs /XF $excludeFiles /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    }
}

# Keep only necessary scripts
if (Test-Path "$destPackage\scripts") {
    Get-ChildItem -Path "$destPackage\scripts" | Where-Object { $_.Name -notmatch "npm-runner.mjs|postinstall-bundled-plugins.mjs" } | Remove-Item -Force -Recurse
}

Write-Host "      Artifacts staged in $destPackage."

# 3. Install production dependencies
Write-Host "      Installing production dependencies using npm..."
Set-Location "$destPackage"

# We use npm install here as it's more reliable for standalone 'package' folder 
# without needing a full pnpm workspace setup in the temp dir.
$env:NPM_CONFIG_UPDATE_NOTIFIER="false"
$env:NODE_LLAMA_CPP_SKIP_DOWNLOAD="1"

npm install --omit=dev --ignore-scripts --no-audit --no-fund

Write-Host "      Dependencies installed."

# 4. Create final zip
Write-Host "[3/3] Creating final openclaw.zip bundle using tar..." -ForegroundColor Yellow
Set-Location $tempDir
$zipPath = "$BUILD\openclaw.zip"
# tar.exe handles long paths better than Compress-Archive on Windows
tar.exe -a -c -f $zipPath package

Set-Location $ROOT
Remove-Item -Recurse -Force $tempDir

Write-Host "`n=== Done ===" -ForegroundColor Green
$nodeSize = (Get-Item $NODZIP).Length / 1MB
$ocSize = (Get-Item $zipPath).Length / 1MB
Write-Host "Node zip: $([math]::Round($nodeSize, 1)) MB -> $NODZIP"
Write-Host "OpenClaw zip: $([math]::Round($ocSize, 1)) MB -> $zipPath"
Write-Host "`nCopy these two files into your Flutter project's assets/runtime/ folder!" -ForegroundColor Yellow
