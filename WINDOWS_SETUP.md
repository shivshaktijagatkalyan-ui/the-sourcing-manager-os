# Windows Setup Guide - The Sourcing Manager OS

Follow these instructions to set up your local environment for deploying and testing the Sourcing Manager OS.

## 1. Install PowerShell 7 (Recommended)
While Windows PowerShell 5.1 works, **PowerShell 7.x (Core)** is recommended for the best experience.
- **Install**: `winget install Microsoft.PowerShell`
- **Verify**: `pwsh --version`

## 2. Install Python 3
Required for the `security-check.py` scanner.
- **Download**: [python.org](https://www.python.org/downloads/windows/) (Check "Add Python to PATH" during installation)
- **Alternative**: `winget install Python.Python.3.11`
- **Verify**: `python --version` or `py -3 --version`

## 3. Install Supabase CLI
Required for database migrations and deploying Edge Functions.
- **Install (npm)**: `npm install supabase --save-dev`
- **Install (Scoop)**: `scoop install supabase`
- **Verify**: `npx supabase --version` (or `supabase --version` if installed globally)

## 4. Install Flutter SDK
Required for the PWA frontend.
- **Download**: [flutter.dev](https://docs.flutter.dev/get-started/install/windows)
- **Setup**: Extract to `C:\src\flutter` and add `C:\src\flutter\bin` to your User PATH environment variables.
- **Verify**: `flutter --version`

## 5. Verify Your Setup
Run the following script from the project root to confirm all tools are correctly configured:
```powershell
.\scripts\production-deploy.ps1
```

### Common Issues:
- **PATH not updated**: If you just installed a tool, you must restart your terminal for the PATH changes to take effect.
- **Execution Policy**: If you cannot run the `.ps1` script, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`.
