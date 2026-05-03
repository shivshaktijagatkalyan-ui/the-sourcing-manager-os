# Windows Setup Guide - The Sourcing Manager OS

Use this guide before running the Sprint 1 deployment gate on Windows. Do not mark Sprint 1 deployed until the gate and live smoke tests pass with real output.

## 1. Use PowerShell 7

PowerShell 7 is recommended for consistent command behavior on Windows.

```powershell
winget install Microsoft.PowerShell
pwsh --version
```

Windows PowerShell 5.1 may run the script, but PowerShell 7 should be used for deployment verification.

## 2. Check What You Already Have

Open PowerShell 7 and run:

```powershell
$PSVersionTable.PSVersion
python --version
py -3 --version
supabase --version
flutter --version
git --version
```

If any command is missing, install that tool, restart PowerShell, and verify again.

## 3. Install Python 3

Python 3 is required for the deployment security constitution scanner. The deploy script prefers `python`; if that is unavailable, it falls back to the Windows launcher with `py -3`.

```powershell
winget install Python.Python.3.12
```

Restart PowerShell and check:

```powershell
python --version
```

If `python` still fails, test:

```powershell
py -3 --version
```

Download page: [python.org/downloads/windows](https://www.python.org/downloads/windows/)

## 4. Install Supabase CLI

Supabase CLI is required for database migrations and Edge Function deployment. The production gate requires the `supabase` command in PATH; it does not use `npx supabase` as a deployment substitute.

```powershell
winget install Supabase.CLI
```

Check:

```powershell
supabase --version
```

Docs: [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli)

## 5. Install Flutter SDK

Flutter is required for PWA analysis and production web build.

```powershell
winget install Google.Flutter
```

Restart PowerShell and check:

```powershell
flutter --version
flutter doctor
```

Docs: [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)

## 6. Install Git

Git is required for deployment source control and release traceability.

```powershell
winget install Git.Git
git --version
```

## 7. PATH Verification

After installing tools, restart PowerShell 7 and run:

```powershell
Get-Command python
Get-Command py
Get-Command supabase
Get-Command flutter
Get-Command git
```

At least one Python path must work: `python` or `py -3`. The other required tools must resolve directly from PATH.

## 8. Run Deployment Gate

From the project root:

```powershell
cd "C:\Users\iBUGG3D\Desktop\The Sourcing MAnager OS"
./scripts/production-deploy.ps1
```

If the script reports a missing tool, stop and fix the local setup first. Do not run migrations, function deployment, or Flutter build manually to bypass the gate.
