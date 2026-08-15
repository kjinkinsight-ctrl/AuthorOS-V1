param(
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '..\dist\IndieAuthorOS-1.0.0-windows-x64'),
    [switch]$CreateDesktopShortcut
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path $SourceDirectory).Path
$exeName = 'author_studio_v1.exe'
$sourceExe = Join-Path $source $exeName
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\Indie Author OS'
$installedExe = Join-Path $installRoot $exeName
$startMenuRoot = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Indie Author OS'
$startMenuShortcut = Join-Path $startMenuRoot 'Indie Author OS.lnk'

if (-not (Test-Path $sourceExe)) {
    throw "Packaged executable not found: $sourceExe"
}
if ((Get-Item $sourceExe).Length -le 0) {
    throw "Packaged executable is empty: $sourceExe"
}

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $installRoot -Recurse -Force
New-Item -ItemType Directory -Force -Path $startMenuRoot | Out-Null

$shell = New-Object -ComObject WScript.Shell
function New-AppShortcut([string]$path) {
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = $installedExe
    $shortcut.WorkingDirectory = $installRoot
    $shortcut.IconLocation = "$installedExe,0"
    $shortcut.Description = 'Indie Author OS'
    $shortcut.Save()
}

New-AppShortcut $startMenuShortcut
if ($CreateDesktopShortcut) {
    New-AppShortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Indie Author OS.lnk')
}

Write-Host "Installed executable: $installedExe"
Write-Host "Start Menu shortcut: $startMenuShortcut"