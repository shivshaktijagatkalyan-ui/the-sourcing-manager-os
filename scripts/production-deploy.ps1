# The Sourcing Manager OS - Production Deployment Script
# Run this from the project root

Write-Host "Starting v0.1.0 Security Check..." -ForegroundColor Cyan
python scripts/security-check.py
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Security check failed. Aborting deployment." -ForegroundColor Red
    exit 1 
}

Write-Host "Linking Supabase Project..." -ForegroundColor Cyan
# Replace with your actual project ref if not already linked
# supabase link --project-ref YOUR_SUPABASE_PROJECT_REF

Write-Host "Applying Database Migrations..." -ForegroundColor Cyan
supabase db push

Write-Host "Deploying Edge Functions..." -ForegroundColor Cyan
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback

Write-Host "Building Flutter PWA..." -ForegroundColor Cyan
cd flutter_app
flutter pub get
flutter analyze
flutter build web
cd ..

Write-Host "Deployment preparation complete." -ForegroundColor Green
Write-Host "Next Step: Perform Live Smoke Tests." -ForegroundColor Yellow
Write-Host "After success, run: git tag v0.1.0 && git push origin v0.1.0" -ForegroundColor Magenta
