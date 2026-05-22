$ErrorActionPreference = "Continue"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$ReportPath = Join-Path $Root "CONTROLLED_PILOT_RELEASE_GATE_REPORT.md"
$Results = New-Object System.Collections.Generic.List[object]

function Invoke-GateStep {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  Write-Host "==> $Name"
  $started = Get-Date
  try {
    & $Command
    $exit = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 0 }
    $status = if ($exit -eq 0) { "PASS" } else { "FAIL" }
  } catch {
    $exit = 1
    $status = "FAIL"
    Write-Host $_.Exception.Message
  }
  $duration = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
  $Results.Add([pscustomobject]@{
    Step = $Name
    Status = $status
    ExitCode = $exit
    DurationSeconds = $duration
  }) | Out-Null
}

Set-Location $Root

Invoke-GateStep "Security constitution scan" {
  python scripts/security-check.py
}

Invoke-GateStep "Root TypeScript check" {
  npx tsc --noEmit
}

Invoke-GateStep "Supabase function/config drift check" {
  node scripts/check-function-drift.mjs
}

Invoke-GateStep "Supabase migration dry run" {
  npx supabase db push --dry-run --linked
}

Invoke-GateStep "Flutter analyze" {
  Push-Location (Join-Path $Root "flutter_app")
  try {
    flutter analyze
  } finally {
    Pop-Location
  }
}

Invoke-GateStep "Flutter web release build" {
  Push-Location (Join-Path $Root "flutter_app")
  try {
    flutter build web --release
  } finally {
    Pop-Location
  }
}

Invoke-GateStep "Flutter APK release build" {
  Push-Location (Join-Path $Root "flutter_app")
  try {
    flutter build apk --release
  } finally {
    Pop-Location
  }
}

Invoke-GateStep "Trust loop UAT" {
  node scripts/uat-trust-loop.mjs
}

$lines = @(
  "# CONTROLLED PILOT RELEASE GATE REPORT",
  "",
  "Generated: $((Get-Date).ToUniversalTime().ToString("o"))",
  "",
  "| Step | Status | Exit Code | Duration Seconds |",
  "| --- | --- | ---: | ---: |"
)

foreach ($result in $Results) {
  $lines += "| $($result.Step) | $($result.Status) | $($result.ExitCode) | $($result.DurationSeconds) |"
}

$failed = $Results | Where-Object { $_.Status -ne "PASS" }
$lines += ""
$lines += "## Result"
$lines += ""
if ($failed) {
  $lines += "FAIL - controlled pilot release gate did not pass."
} else {
  $lines += "PASS - controlled pilot release gate passed."
}

Set-Content -LiteralPath $ReportPath -Value $lines -Encoding UTF8

if ($failed) {
  exit 1
}
