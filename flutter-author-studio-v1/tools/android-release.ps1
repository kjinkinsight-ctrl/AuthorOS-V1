param(
    [string]$KeyStorePath = "",
    [string]$KeyAlias = "authorstudio-release",
    [string]$StorePassword = "change-me",
    [string]$KeyPassword = "change-me",
    [string]$DisplayName = "Author Studio",
    [string]$Organization = "Author Studio",
    [string]$Country = "AU"
)

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($KeyStorePath)) {
    $KeyStorePath = Join-Path $projectRoot "android\app\release-keystore.jks"
}

$androidDir = Join-Path $projectRoot "android"
$keyPropertiesPath = Join-Path $androidDir "key.properties"

New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
$keystoreDir = Split-Path $KeyStorePath -Parent
New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null

if (-not (Test-Path $KeyStorePath)) {
    Write-Host "Creating Android keystore at $KeyStorePath"
    keytool -genkeypair -v `
        -keystore $KeyStorePath `
        -alias $KeyAlias `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass $StorePassword `
        -keypass $KeyPassword `
        -dname "CN=$DisplayName, OU=Android, O=$Organization, L=Online, S=Online, C=$Country"
}

$keyProperties = @"
storePassword=$StorePassword
keyPassword=$KeyPassword
keyAlias=$KeyAlias
storeFile=$KeyStorePath
"@

Set-Content -Path $keyPropertiesPath -Value $keyProperties -Encoding UTF8

Write-Host "Signing config created at $keyPropertiesPath"
Write-Host "Building release APK and AAB..."

Set-Location $projectRoot
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release

Write-Host "Release outputs:"
Write-Host "  APK: $projectRoot\build\app\outputs\flutter-apk\app-release.apk"
Write-Host "  AAB: $projectRoot\build\app\outputs\bundle\release\app-release.aab"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Upload the AAB to Google Play Console"
Write-Host "  2. Add screenshots, privacy policy, and store listing text"
Write-Host "  3. Complete content rating and data safety disclosures"
