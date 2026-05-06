# Deployment & Rollback Runbook (Sprint 9)

## 1. Pre-deployment Checklist

- [ ] Security Scan Passed (`scripts/security-check.py`)
- [ ] Database Backup Verified
- [ ] Migration Dry-run (Local)
- [ ] Flutter Analysis Passed

## 2. Deployment Steps

1. Run `./scripts/production-deploy.ps1`.
2. Monitor `system_health_events` for 10 minutes.
3. Check `provider_failures` for Exotel connectivity.

## 3. Rollback Scenarios

### A. Edge Function Failure

- **Action**: Redeploy previous version using `supabase functions deploy <name>`.
- **Audit**: Log a `rollback_event`.

### B. Bad Migration (Reversible)

- **Action**: Run `supabase db query "BEGIN; ROLLBACK; ..."` or apply a compensatory migration.
- **Risk**: High. Use "Fail-Closed" mode during the window.

### C. Flutter Build Regression

- **Action**: Revert to previous build artifact in hosting provider.
- **Client Impact**: Users will see the old UI on next refresh.

## 4. Emergency System Pause

In case of severe data corruption:

- Call `incident-response(action='pause_all')`.
- This sets `system_health.status = 'incident'` and blocks all data-loan triggers.
