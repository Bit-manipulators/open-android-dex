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

# 2.5 Ensure Windows FFmpeg SDK is available for hardware/multithreaded video stream decoding
Write-Host "==> Ensuring Windows FFmpeg SDK is set up..."
$DownloadsDir = "build\downloads"
New-Item -ItemType Directory -Force -Path $DownloadsDir | Out-Null
$FFmpegZip = "$DownloadsDir\ffmpeg-master-latest-win64-gpl-shared.zip"
$FFmpegDestDir = "windows\ffmpeg"

if (-not (Test-Path "$FFmpegDestDir\include\libavcodec\avcodec.h")) {
    if (-not (Test-Path $FFmpegZip)) {
        $FFmpegUrl = "https://github.com/FFmpeg-Builds/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip"
        Write-Host "  Downloading Windows FFmpeg SDK from $FFmpegUrl..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $FFmpegUrl -OutFile $FFmpegZip
    }
    Write-Host "  Extracting Windows FFmpeg SDK..."
    $FFmpegExtractDir = "$DownloadsDir\ffmpeg_extracted"
    New-Item -ItemType Directory -Force -Path $FFmpegExtractDir | Out-Null
    Expand-Archive -Path $FFmpegZip -DestinationPath $FFmpegExtractDir -Force
    $ExtractedSub = (Get-ChildItem -Path "$FFmpegExtractDir\ffmpeg-*" -Directory | Select-Object -First 1).FullName
    New-Item -ItemType Directory -Force -Path $FFmpegDestDir | Out-Null
    Copy-Item -Path "$ExtractedSub\*" -Destination $FFmpegDestDir -Recurse -Force
}
Write-Host "  ✅ Windows FFmpeg SDK ready at $FFmpegDestDir" -ForegroundColor Green

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

# 3.5 Bundle standalone ADB, scrcpy, and runtime dependencies
Write-Host "==> Bundling portable ADB and scrcpy binaries for Windows..."
$ScrcpyVersion = "v5.0.1"
$DownloadsDir = "build\downloads"
New-Item -ItemType Directory -Force -Path $DownloadsDir | Out-Null
$ScrcpyZip = "$DownloadsDir\scrcpy-win64-$ScrcpyVersion.zip"

if (-not (Test-Path $ScrcpyZip)) {
    $ScrcpyUrl = "https://github.com/Genymobile/scrcpy/releases/download/$ScrcpyVersion/scrcpy-win64-$ScrcpyVersion.zip"
    Write-Host "  Downloading portable scrcpy & adb bundle from $ScrcpyUrl..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ScrcpyUrl -OutFile $ScrcpyZip
}

$ScrcpyExtractDir = "$DownloadsDir\scrcpy-win64-$ScrcpyVersion"
if (-not (Test-Path $ScrcpyExtractDir)) {
    Write-Host "  Extracting scrcpy-win64 bundle..."
    Expand-Archive -Path $ScrcpyZip -DestinationPath $DownloadsDir -Force
}

$SourceDir = if (Test-Path "$DownloadsDir\scrcpy-win64-$ScrcpyVersion\scrcpy-win64-$ScrcpyVersion") {
    "$DownloadsDir\scrcpy-win64-$ScrcpyVersion\scrcpy-win64-$ScrcpyVersion"
} else {
    "$DownloadsDir\scrcpy-win64-$ScrcpyVersion"
}

# Copy adb, scrcpy, scrcpy-server, and all supporting DLLs directly into ReleaseDir
Write-Host "  Copying bundled binaries into Release package ($ReleaseDir)..."
Get-ChildItem -Path "$SourceDir\*" -Exclude "*.bat", "*.vbs" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $ReleaseDir -Recurse -Force
}

# Also ensure data\flutter_assets\assets\bin has adb and scrcpy for flutter asset resolution
$AssetsBinDir = "$ReleaseDir\data\flutter_assets\assets\bin"
New-Item -ItemType Directory -Force -Path $AssetsBinDir | Out-Null
Copy-Item "$SourceDir\adb.exe" "$AssetsBinDir\" -Force -ErrorAction SilentlyContinue
Copy-Item "$SourceDir\scrcpy.exe" "$AssetsBinDir\" -Force -ErrorAction SilentlyContinue
Copy-Item "$SourceDir\scrcpy-server" "$AssetsBinDir\" -Force -ErrorAction SilentlyContinue

# Copy FFmpeg runtime DLLs into ReleaseDir and AssetsBinDir
if (Test-Path "$FFmpegDestDir\bin") {
    Write-Host "  Copying FFmpeg runtime DLLs into Release package ($ReleaseDir)..."
    Get-ChildItem -Path "$FFmpegDestDir\bin\*.dll" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $ReleaseDir -Force
        Copy-Item -Path $_.FullName -Destination $AssetsBinDir -Force -ErrorAction SilentlyContinue
    }
}

# Copy MSVC runtime DLLs (msvcp140.dll, vcruntime140.dll) to ensure standalone execution on clean Windows systems
Write-Host "  Checking for MSVC runtime DLLs to include..."
$vcRedistDirs = @(
    (Get-ChildItem -Path "C:\Program Files\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -ErrorAction SilentlyContinue | Select-Object -Last 1).FullName,
    (Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -ErrorAction SilentlyContinue | Select-Object -Last 1).FullName,
    "C:\Windows\System32"
)
foreach ($dir in $vcRedistDirs) {
    if ($dir -and (Test-Path $dir)) {
        Copy-Item "$dir\msvcp140*.dll" "$ReleaseDir\" -Force -ErrorAction SilentlyContinue
        Copy-Item "$dir\vcruntime140*.dll" "$ReleaseDir\" -Force -ErrorAction SilentlyContinue
        if ((Test-Path "$ReleaseDir\msvcp140.dll") -and (Test-Path "$ReleaseDir\vcruntime140.dll")) {
            Write-Host "  ✅ Included MSVC runtime DLLs (msvcp140.dll, vcruntime140.dll)" -ForegroundColor Green
            break
        }
    }
}

Write-Host "  ✅ Successfully bundled adb.exe, scrcpy.exe, scrcpy-server, and DLLs into Windows build!" -ForegroundColor Green

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
    $cleanVersion = if ($Version) { $Version.TrimStart('v') } else { "2.0.2" }
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
