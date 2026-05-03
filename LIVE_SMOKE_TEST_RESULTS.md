# Live Smoke Test Results - Sprint 1

Status: **BLOCKED**

Sprint 1 code may be present, but deployment is not verified. Keep this file blocked until `./scripts/production-deploy.ps1` runs successfully and the smoke tests below are executed against the deployed environment.

## Deployment Gate Verification

- **Current Directory**: `C:\Users\iBUGG3D\Desktop\The Sourcing MAnager OS`
- **Last agent gate run**: 2026-05-04 IST, failed safely during pre-flight
- **PowerShell Version**: 5.1 detected; PowerShell 7 still recommended for manual deployment
- **Python 3**: Missing from agent PATH; verify manually with `python --version` or `py -3 --version`
- **Supabase CLI**: Missing from agent PATH; verify manually with `supabase --version`
- **Flutter SDK**: Missing from agent PATH; verify manually with `flutter --version` and `flutter doctor`
- **Git**: Available in agent PATH via `git`
- **Deployment Script**: Blocked before migrations, Edge Function deployment, or Flutter build

## Smoke Test Checklist

- [ ] Broker lead upload works
- [ ] Broker upload response contains only `lead_id` and `alias`
- [ ] `leads_public` stores metadata only
- [ ] `leads_sensitive` stores ciphertext only
- [ ] no plaintext contact data in database
- [ ] caller without active loan gets `access_denied`
- [ ] caller with expired loan gets `access_denied` or `loan_expired`
- [ ] revoked loan blocks call after UI refresh
- [ ] revoked loan blocks call when caller presses from stale UI
- [ ] DND blocked lead returns `dnd_blocked`
- [ ] consent pending lead returns `consent_required`
- [ ] browser network tab contains only `lead_id` for call initiation
- [ ] app and provider logs contain no raw sensitive payloads
- [ ] authenticated frontend user cannot select from `leads_sensitive`

## Remaining Blockers

The local deployment environment still needs manual tool installation or verification:

1. Python 3 must be available as `python` or `py -3`.
2. Supabase CLI must be available as `supabase`.
3. Flutter SDK must be available as `flutter`.
4. Git must be available as `git`.

Follow [WINDOWS_SETUP.md](./WINDOWS_SETUP.md), restart PowerShell 7, run the deployment gate, then record real smoke-test results here.
