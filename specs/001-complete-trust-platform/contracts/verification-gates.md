# Contract: Verification Gates

## Always Applicable Local Gates

```powershell
python scripts/security-check.py
node scripts/security-check.mjs
node scripts/check-function-drift.mjs
node scripts/ai-safe-tool-check.mjs
npx tsc --noEmit
npm run build
```

## Flutter-Specific Gate

Run when Flutter files change:

```powershell
cd flutter_app
flutter analyze
```

## Migration Gate

Run when Supabase migrations change:

```powershell
npx supabase db push --dry-run --linked
```

## Live UAT Gate

Run only when the operator explicitly accepts remote data mutation:

```powershell
node scripts/uat-trust-loop.mjs
```

## Completion Rule

Completion reports must list every gate run, its result, and any skipped gate
with a reason. A live UAT PASS may be cited only from a fresh run or from a
named report that includes its log output and date.
