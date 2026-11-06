# Open Android DeX — Windows 11 Build & Packaging Script
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1
$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  🚀 Open Android DeX — Windows 11 Build Pipeline" -ForegroundColor Cyan
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

# 4. Package Portable ZIP
$ZipPath = "$OutDir\Open-Android-DeX-Windows-x64-Portable.zip"
Write-Host "==> Creating Portable ZIP at $ZipPath..."
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -Force

# 5. Compile Inno Setup Installer (if ISCC is installed)
$iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
}

if (Test-Path $iscc) {
    Write-Host "==> Compiling Inno Setup Installer..."
    & $iscc windows\packaging\installer.iss
    $InstallerSrc = "build\windows_installer\Open-Android-DeX-Windows-x64-Setup.exe"
    if (Test-Path $InstallerSrc) {
        Copy-Item $InstallerSrc "$OutDir\Open-Android-DeX-Windows-x64-Setup.exe" -Force
        Write-Host "  ✅ Setup Installer: $OutDir\Open-Android-DeX-Windows-x64-Setup.exe" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ Notice: Inno Setup 6 (ISCC.exe) not found. Portable ZIP created successfully." -ForegroundColor Yellow
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ✅ Windows Build Complete!" -ForegroundColor Green
Write-Host "  Portable ZIP: $ZipPath" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
