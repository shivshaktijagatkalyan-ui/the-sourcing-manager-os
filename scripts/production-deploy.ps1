# The Sourcing Manager OS - Production Deployment Gate
# Run from the project root or any child path. This script never prints secrets.

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectRoot

$script:PythonExecutable = $null
$script:PythonArgs = @()

function Write-MissingTool {
    param (
        [string]$Name,
        [string]$Why,
        [string]$Install,
        [string]$Verify,
        [string]$Link
    )

    Write-Host " MISSING" -ForegroundColor Red
    Write-Host "Missing: $Name" -ForegroundColor Yellow
    Write-Host "Why required: $Why" -ForegroundColor Gray
    Write-Host "Install: $Install" -ForegroundColor Gray
    if ($Link) {
        Write-Host "Download/docs: $Link" -ForegroundColor Gray
    }
    Write-Host "Verify after install: $Verify" -ForegroundColor Gray
}

function Test-ExternalTool {
    param (
        [string]$Name,
        [string]$Command,
        [string[]]$VersionArgs,
        [string]$Why,
        [string]$Install,
        [string]$Verify,
        [string]$Link
    )

    Write-Host "Checking for $Name..." -NoNewline
    
    # Try global command
    $tool = Get-Command $Command -ErrorAction SilentlyContinue
    
    # Special case for Supabase (check npx)
    if ($null -eq $tool -and $Name -eq "Supabase CLI") {
        $npx = Get-Command "npx" -ErrorAction SilentlyContinue
        if ($null -ne $npx) {
            $test = npx supabase --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " OK (using npx supabase)" -ForegroundColor Green
                return $true
            }
        }
    }

    if ($null -eq $tool) {
        Write-MissingTool -Name $Name -Why $Why -Install $Install -Verify $Verify -Link $Link
        return $false
    }

    $oldErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command @VersionArgs *> $null
        $versionExitCode = $LASTEXITCODE
    }
    catch {
        $versionExitCode = 1
    }
    finally {
        $ErrorActionPreference = $oldErrorPreference
    }

    if ($versionExitCode -ne 0) {
        Write-MissingTool -Name $Name -Why $Why -Install $Install -Verify $Verify -Link $Link
        return $false
    }

    Write-Host " OK ($($tool.Source))" -ForegroundColor Green
    return $true
}

function Test-Python3 {
    Write-Host "Checking for Python 3..." -NoNewline

    $pathsToTest = @("python", "py")
    # Add common Windows install paths
    $userProfile = $env:USERPROFILE
    $pathsToTest += Join-Path $userProfile "AppData\Local\Programs\Python\Python312\python.exe"
    $pathsToTest += Join-Path $userProfile "AppData\Local\Programs\Python\Python311\python.exe"

    foreach ($cmd in $pathsToTest) {
        $fullCmd = $cmd
        $args = @("--version")
        if ($cmd -eq "py") { $args = @("-3", "--version") }

        $oldErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            if ($cmd -match "python\.exe$") {
                $versionOutput = & $cmd --version 2>$null
            } else {
                $versionOutput = & $cmd @args 2>$null
            }
            $versionExitCode = $LASTEXITCODE
        }
        catch {
            $versionOutput = ""
            $versionExitCode = 1
        }
        finally {
            $ErrorActionPreference = $oldErrorPreference
        }

        if ($versionExitCode -eq 0 -and "$versionOutput" -match "^Python 3\.") {
            $script:PythonExecutable = $cmd
            if ($cmd -eq "py") { $script:PythonArgs = @("-3") }
            Write-Host " OK ($cmd)" -ForegroundColor Green
            return $true
        }
    }

    Write-MissingTool `
        -Name "Python 3" `
        -Why "Required to run the deployment security constitution scanner before any production action." `
        -Install "winget install Python.Python.3.12" `
        -Verify "python --version; if unavailable, run py -3 --version" `
        -Link "https://www.python.org/downloads/windows/"
    return $false
}

function Stop-IfFailed {
    param ([string]$StepName)

    if ($LASTEXITCODE -ne 0) {
        Write-Host "$StepName failed. Deployment stopped safely." -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== Sourcing Manager OS Deployment Pre-flight ===" -ForegroundColor Cyan
Write-Host "Sprint 2 deployment remains blocked until this gate and live smoke tests pass." -ForegroundColor Yellow

$allToolsFound = $true

if (-not (Test-Python3)) { $allToolsFound = $false }

if (-not (Test-ExternalTool `
    -Name "Supabase CLI" `
    -Command "supabase" `
    -VersionArgs @("--version") `
    -Why "Required for Supabase database migrations and Edge Function deployment." `
    -Install "winget install Supabase.CLI" `
    -Verify "supabase --version" `
    -Link "https://supabase.com/docs/guides/cli")) { $allToolsFound = $false }

if (-not (Test-ExternalTool `
    -Name "Flutter SDK" `
    -Command "flutter" `
    -VersionArgs @("--version") `
    -Why "Required for Flutter Web/PWA analysis and production build." `
    -Install "winget install Google.Flutter" `
    -Verify "flutter --version; flutter doctor" `
    -Link "https://docs.flutter.dev/get-started/install/windows")) { $allToolsFound = $false }

if (-not (Test-ExternalTool `
    -Name "Git" `
    -Command "git" `
    -VersionArgs @("--version") `
    -Why "Required for release traceability and deployment source control checks." `
    -Install "winget install Git.Git" `
    -Verify "git --version" `
    -Link "https://git-scm.com/download/win")) { $allToolsFound = $false }

if (-not $allToolsFound) {
    Write-Host ""
    Write-Host "ERROR: Deployment pre-flight failed. No migrations, Edge Functions, or Flutter builds were run." -ForegroundColor Red
    Write-Host "Follow WINDOWS_SETUP.md, restart PowerShell, then rerun ./scripts/production-deploy.ps1." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== Running v0.2.0 Security Constitution Scan ===" -ForegroundColor Cyan
$securityArgs = @()
$securityArgs += $script:PythonArgs
$securityArgs += "scripts/security-check.py"
& $script:PythonExecutable @securityArgs
Stop-IfFailed "Security constitution scan"

Write-Host ""
Write-Host "=== Proceeding with Sprint 2 Deployment Commands ===" -ForegroundColor Cyan

Write-Host "Applying database migrations..." -ForegroundColor Cyan
if (Get-Command "supabase" -ErrorAction SilentlyContinue) {
    supabase db push
} else {
    npx supabase db push
}
Stop-IfFailed "Supabase database migration"

Write-Host "Deploying Edge Function: broker-upload-lead..." -ForegroundColor Cyan
if (Get-Command "supabase" -ErrorAction SilentlyContinue) {
    supabase functions deploy broker-upload-lead
} else {
    npx supabase functions deploy broker-upload-lead
}
Stop-IfFailed "broker-upload-lead deployment"

Write-Host "Deploying Edge Function: initiate-call..." -ForegroundColor Cyan
if (Get-Command "supabase" -ErrorAction SilentlyContinue) {
    supabase functions deploy initiate-call
} else {
    npx supabase functions deploy initiate-call
}
Stop-IfFailed "initiate-call deployment"

Write-Host "Deploying Edge Function: exotel-callback..." -ForegroundColor Cyan
if (Get-Command "supabase" -ErrorAction SilentlyContinue) {
    supabase functions deploy exotel-callback
} else {
    npx supabase functions deploy exotel-callback
}
Stop-IfFailed "exotel-callback deployment"

$Sprint2Functions = @(
    "create-site-visit",
    "start-site-visit",
    "verify-site-gps",
    "upload-site-photo",
    "broker-review-site-visit"
)

foreach ($func in $Sprint2Functions) {
    Write-Host "Deploying Edge Function: $func..." -ForegroundColor Cyan
    if (Get-Command "supabase" -ErrorAction SilentlyContinue) {
        supabase functions deploy $func
    } else {
        npx supabase functions deploy $func
    }
    Stop-IfFailed "$func deployment"
}

Write-Host "Building Flutter PWA..." -ForegroundColor Cyan
Push-Location "flutter_app"
try {
    flutter pub get
    Stop-IfFailed "Flutter pub get"

    flutter analyze
    Stop-IfFailed "Flutter analyze"

    flutter build web --release
    Stop-IfFailed "Flutter web build"
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Deployment commands completed. Sprint 2 is not verified until SPRINT_2_SMOKE_TEST_RESULTS.md is updated with real smoke-test results." -ForegroundColor Green
