# Open Android DeX — Windows 11 Build & Packaging Script
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 [-Version <version>]
param(
    [string]$Version = $env:APP_VERSION
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  🚀 Open Android DeX — Windows 11 Build Pipeline" -ForegroundColor Cyan
if ($Version) {
    Write-Host "  Version: $Version" -ForegroundColor Cyan
}
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Enable Windows Desktop in Flutter
Write-Host "==> Enabling Windows Desktop support in Flutter..."
flutter config --enable-windows-desktop

# 2. Install dependencies
Write-Host "==> Fetching Flutter dependencies..."
flutter pub get

# 3. Build Windows Release
Write-Host "==> Compiling Windows 11 x64 Release..."
flutter build windows --release

$ReleaseDir = "build\windows\x64\runner\Release"
$OutDir = "build\release_artifacts"
if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Build output directory not found at $ReleaseDir"
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 4. Bundle Platform-Tools (ADB) and scrcpy into Release directory for 100% zero-configuration out-of-the-box setup
Write-Host "==> Bundling portable platform-tools (ADB) and scrcpy for zero-setup execution..." -ForegroundColor Cyan

$AdbDir = "$ReleaseDir\platform-tools"
if (-not (Test-Path "$AdbDir\adb.exe")) {
    Write-Host "    -> Downloading Google Android Platform-Tools..."
    $AdbZip = "$env:TEMP\platform-tools-windows.zip"
    try {
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $AdbZip -UseBasicParsing
        Expand-Archive -Path $AdbZip -DestinationPath $ReleaseDir -Force
        Remove-Item $AdbZip -Force -ErrorAction SilentlyContinue
        Write-Host "    -> Bundled platform-tools successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to download platform-tools: $_"
    }
}

$ScrcpyDir = "$ReleaseDir\scrcpy"
if (-not (Test-Path "$ScrcpyDir\scrcpy.exe")) {
    Write-Host "    -> Downloading Genymobile scrcpy v2.7..."
    $ScrcpyZip = "$env:TEMP\scrcpy-win64.zip"
    $ScrcpyTemp = "$env:TEMP\scrcpy_extract_$PID"
    try {
        Invoke-WebRequest -Uri "https://github.com/Genymobile/scrcpy/releases/download/v2.7/scrcpy-win64-v2.7.zip" -OutFile $ScrcpyZip -UseBasicParsing
        New-Item -ItemType Directory -Force -Path $ScrcpyTemp | Out-Null
        Expand-Archive -Path $ScrcpyZip -DestinationPath $ScrcpyTemp -Force
        $ExtractedFolder = (Get-ChildItem $ScrcpyTemp -Directory | Select-Object -First 1).FullName
        if ($ExtractedFolder) {
            Move-Item -Path $ExtractedFolder -Destination $ScrcpyDir -Force
        }
        Remove-Item $ScrcpyZip -Force -ErrorAction SilentlyContinue
        Remove-Item $ScrcpyTemp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    -> Bundled scrcpy successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to download scrcpy: $_"
    }
}

# Resolve output filenames (versioned if version is provided)
if ($Version) {
    $ZipFilename = "Open-Android-DeX-$Version-Windows-x64-Portable.zip"
    $SetupBase = "Open-Android-DeX-$Version-Windows-x64-Setup"
} else {
    $ZipFilename = "Open-Android-DeX-Windows-x64-Portable.zip"
    $SetupBase = "Open-Android-DeX-Windows-x64-Setup"
}

# 4. Package Portable ZIP
$ZipPath = "$OutDir\$ZipFilename"
Write-Host "==> Creating Portable ZIP at $ZipPath..."
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -Force

# 5. Compile Inno Setup Installer (if ISCC is installed)
$iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
}

if (Test-Path $iscc) {
    Write-Host "==> Compiling Inno Setup Installer..."
    $cleanVersion = if ($Version) { $Version.TrimStart('v') } else { "1.0.0" }
    & $iscc "/DMyAppVersion=$cleanVersion" "/DOutputBaseFilename=$SetupBase" windows\packaging\installer.iss
    $InstallerSrc = "build\windows_installer\$SetupBase.exe"
    if (Test-Path $InstallerSrc) {
        Copy-Item $InstallerSrc "$OutDir\$SetupBase.exe" -Force
        Write-Host "  ✅ Setup Installer: $OutDir\$SetupBase.exe" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ Notice: Inno Setup 6 (ISCC.exe) not found. Portable ZIP created successfully." -ForegroundColor Yellow
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ✅ Windows Build Complete!" -ForegroundColor Green
Write-Host "  Portable ZIP: $ZipPath" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
