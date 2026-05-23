# Quickstart: Complete Trust Platform Verification

## 1. Confirm Spec Kit Context

```powershell
specify --version
Get-Content .specify/feature.json
```

Expected:

- `specify 0.8.13`
- active feature directory is `specs/001-complete-trust-platform`

## 2. Run Local Static Gates

```powershell
python scripts/security-check.py
node scripts/security-check.mjs
node scripts/check-function-drift.mjs
node scripts/ai-safe-tool-check.mjs
npx tsc --noEmit
```

Expected:

- security constitution scans pass
- function/config drift passes
- AI-safe tool layer passes
- TypeScript check exits with code 0

## 3. Run Flutter Gate

```powershell
cd flutter_app
flutter analyze
cd ..
```

Expected:

- no analyzer issues

## 4. Run Release Build

```powershell
npm run build
```

Expected:

- Flutter web release build succeeds

## 5. Dry-Run Migrations

```powershell
npx supabase db push --dry-run --linked
```

Expected:

- command exits 0
- output lists pending migrations without applying them

## 6. Seed Test Users Dry Run

```powershell
node scripts/seed-test-users.mjs
```

Expected:

- script prints planned UAT users and does not write to Supabase

## 7. Live UAT Decision

Only run this when remote mutation is acceptable:

```powershell
node scripts/uat-trust-loop.mjs
```

Expected:

- every trust-loop assertion passes from onboarding through broker lock and
  audit review
