$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\Author Studio'
$startMenuRoot = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Author Studio'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Author Studio.lnk'

Get-Process -Name author_studio_v1 -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like "$installRoot*"
} | Stop-Process -Force

if (Test-Path $startMenuRoot) {
    Remove-Item -Recurse -Force $startMenuRoot
}
if (Test-Path $desktopShortcut) {
    Remove-Item -Force $desktopShortcut
}
if (Test-Path $installRoot) {
    Remove-Item -Recurse -Force $installRoot
}

Write-Host 'Author Studio was removed from this user account.'