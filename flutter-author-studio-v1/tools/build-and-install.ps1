$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

flutter pub get
flutter build windows --release
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'package-windows.ps1')
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install-author-studio.ps1') -CreateDesktopShortcut

$installedExe = Join-Path $env:LOCALAPPDATA 'Programs\Indie Author OS\authoros.exe'
Start-Process $installedExe
Write-Host "Updated and launched: $installedExe"