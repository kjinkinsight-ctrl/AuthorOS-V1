param(
    [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$distDir = Join-Path $projectRoot 'dist'
$packageDir = Join-Path $distDir "IndieAuthorOS-$Version-windows-x64"
$archivePath = Join-Path $distDir "IndieAuthorOS-$Version-windows-x64.zip"

if (-not (Test-Path (Join-Path $releaseDir 'author_studio_v1.exe'))) {
    throw "Release build not found. Run 'flutter build windows --release' first."
}

$exe = Get-Item (Join-Path $releaseDir 'author_studio_v1.exe')
if ($exe.Length -le 0) {
    throw "Release executable is empty: $($exe.FullName)"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
if (Test-Path $archivePath) {
    Remove-Item -Force $archivePath
}

Copy-Item -Path $releaseDir -Destination $packageDir -Recurse
Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $archivePath -CompressionLevel Optimal

Write-Host "Portable package: $packageDir"
Write-Host "ZIP package: $archivePath"
Write-Host "Executable size: $($exe.Length) bytes"