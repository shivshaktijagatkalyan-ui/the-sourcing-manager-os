# The Sourcing Manager OS - Production Deployment Script
# Run this from the project root

function Check-Tool {
    param (
        [string]$Name,
        [string]$Command,
        [string]$InstallMsg
    )
    Write-Host "Checking for $Name..." -NoNewline
    $toolPath = Get-Command $Command -ErrorAction SilentlyContinue
    if ($null -eq $toolPath) {
        Write-Host " MISSING" -ForegroundColor Red
        Write-Host "Required: $Name is not in your PATH." -ForegroundColor Yellow
        Write-Host "Why: $InstallMsg" -ForegroundColor Gray
        return $false
    }
    Write-Host " OK ($($toolPath.Source))" -ForegroundColor Green
    return $true
}

Write-Host "=== Sourcing Manager OS Deployment Pre-flight ===" -ForegroundColor Cyan

$allToolsFound = $true

# 1. Check Git
if (-not (Check-Tool "Git" "git" "Required for version control and tagging releases.")) { $allToolsFound = $false }

# 2. Check Python (with fallback)
$pythonCmd = "python"
Write-Host "Checking for Python 3..." -NoNewline
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        $pythonCmd = "py -3"
        Write-Host " OK (using py -3)" -ForegroundColor Green
    } else {
        Write-Host " MISSING" -ForegroundColor Red
        Write-Host "Required: Python 3.10+ is needed for security-check.py." -ForegroundColor Yellow
        Write-Host "Install: Download from python.org or run 'winget install Python.Python.3.11'" -ForegroundColor Gray
        $allToolsFound = $false
    }
} else {
    Write-Host " OK" -ForegroundColor Green
}

# 3. Check Supabase
if (-not (Check-Tool "Supabase CLI" "supabase" "Required for DB migrations and Edge Functions. Install: 'npm install supabase --save-dev' or 'scoop install supabase'")) { $allToolsFound = $false }

# 4. Check Flutter
if (-not (Check-Tool "Flutter SDK" "flutter" "Required for PWA build. Install: Download from flutter.dev and add to PATH.")) { $allToolsFound = $false }

if (-not $allToolsFound) {
    Write-Host "`nERROR: Some required tools are missing. Please follow WINDOWS_SETUP.md." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Starting v0.1.0 Security Check ===" -ForegroundColor Cyan
if ($pythonCmd -eq "py -3") {
    py -3 scripts/security-check.py
} else {
    python scripts/security-check.py
}

if ($LASTEXITCODE -ne 0) { 
    Write-Host "Security check failed. Aborting deployment." -ForegroundColor Red
    exit 1 
}

Write-Host "`n=== Proceeding with Deployment ===" -ForegroundColor Cyan

# 5. Database
Write-Host "Applying Database Migrations..." -ForegroundColor Cyan
supabase db push

# 6. Edge Functions
Write-Host "Deploying Edge Functions..." -ForegroundColor Cyan
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback

# 7. Flutter Build
Write-Host "Building Flutter PWA..." -ForegroundColor Cyan
cd flutter_app
flutter pub get
flutter analyze
flutter build web
cd ..

Write-Host "`nDeployment preparation complete." -ForegroundColor Green
Write-Host "Next Step: Perform Live Smoke Tests in LIVE_SMOKE_TEST_RESULTS.md." -ForegroundColor Yellow
