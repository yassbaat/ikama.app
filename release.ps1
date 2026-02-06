# Iqamah Release Script for Windows
# Run this after building: npm run tauri build

$version = "1.0.0"
$tag = "v$version"

# Check if gh CLI is installed
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: GitHub CLI (gh) not installed." -ForegroundColor Red
    Write-Host "Install from: https://cli.github.com/"
    exit 1
}

# Check if logged in
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Please login to GitHub first: gh auth login" -ForegroundColor Yellow
    exit 1
}

# Paths to built files
$exePath = "src-tauri/target/release/bundle/nsis/iqamah_$($version)_x64-setup.exe"
$msiPath = "src-tauri/target/release/bundle/msi/iqamah_$($version)_x64_en-US.msi"

# Check files exist
if (!(Test-Path $exePath)) {
    Write-Host "Error: EXE not found at $exePath" -ForegroundColor Red
    Write-Host "Run: npm run tauri build" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path $msiPath)) {
    Write-Host "Error: MSI not found at $msiPath" -ForegroundColor Red
    exit 1
}

Write-Host "Creating release $tag..." -ForegroundColor Green

# Create release with gh CLI
gh release create $tag `
    --title "Iqamah $version" `
    --notes-file RELEASE_NOTES.md `
    $exePath `
    $msiPath

Write-Host "✅ Release created successfully!" -ForegroundColor Green
Write-Host "URL: https://github.com/yassbaat/ikama.app/releases/tag/$tag"
