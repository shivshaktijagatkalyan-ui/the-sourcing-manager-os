# Sprint 1-10 Audit Report

Date: 2026-05-04
Workspace: `C:\Users\iBUGG3D\Desktop\The Sourcing MAnager OS`
Audit scope: Sprint 1 through Sprint 10 source, migrations, Edge Functions, deployment script, local build gates, and no-PII scans.

## Executive Verdict

The repository contains substantial Sprint 1-7 implementation, Sprint 9 reliability artifacts, and Sprint 8/10 documentation/UI artifacts. The local Flutter app builds when the Flutter SDK is called by absolute path, and both security scanners pass.

The project is not proven production-complete from this audit because remote Supabase migration/function verification is blocked by 403 credentials, root `npm run build` fails on this shell because `flutter` is not on PATH, and several service-role Edge Functions still lack mandatory authentication/authorization gates.

Status:

- Code exists: PASS
- Migrations exist: PARTIAL for Sprint 1-7 and 9; missing Sprint 8 and 10 backend migrations
- Edge Function source exists: PASS for many required functions
- Static no-phone scan: PASS
- Python security scanner: PASS only through absolute Python path
- Node security scanner: PASS
- Sprint 7 static check: PASS
- Flutter analyze/build: PASS through `C:\src\flutter\bin\flutter.bat`
- Root `npm run build`: FAIL because `flutter` is not on PATH
- Root `npx tsc --noEmit`: N/A by `AGENTS.md`, but command still FAILS when run
- Supabase remote migrations: NOT VERIFIED, CLI returned 403
- Supabase remote functions: NOT VERIFIED, CLI returned 403
- End-to-end live workflow: NOT VERIFIED

## Blocking Findings

### P0 - Incident response can mutate production state without authenticating the caller

File: `supabase/functions/incident-response/index.ts`
Lines: 16-37

The function creates a service-role client, reads `action`, `organization_id`, and `reason` directly from the request body, then pauses organizations or revokes all active data loans. It does not call `auth.getUser()`, does not verify a role, and does not require `can_pause_org` or incident/admin permission.

Impact:

- If deployed, this function can be used to pause an organization or revoke access loans without authenticated operator authorization.
- This is a fail-open control-plane path.

Required fix:

- Authenticate the caller.
- Require strict enterprise permission such as `can_pause_org` or an incident-response-only permission.
- Validate organization scope.
- Write sanitized audit and abuse events.
- Return generic errors only.

### P0 - Dynamic lead routing can reassign broker ownership without authenticating the caller

File: `supabase/functions/route-incoming-leads/index.ts`
Lines: 16-25 and 63-69

The function uses service role, accepts `lead_id` and `organization_id` from the request, and updates `leads_public.broker_id`. It does not authenticate the caller or require a system/admin permission.

Impact:

- If deployed, a caller could alter lead assignment and broker ownership routing.
- It can create commission and data-ownership disputes.

Required fix:

- Authenticate caller or require a server-only secret for scheduled/system jobs.
- Validate org ownership and exact routing permission.
- Ensure the lead belongs to the target org before assignment.
- Keep assignment deterministic and audit-safe.

### P0 - Rate-limit endpoint allows unauthenticated spoofed writes

File: `supabase/functions/check-rate-limit/index.ts`
Lines: 16-25 and 50-55

The function accepts `user_id`, `action`, `limit_per_minute`, and `organization_id` from the request body, then inserts `rate_limit_events` using service role. It does not authenticate the caller and does not derive actor identity from the JWT.

Impact:

- If deployed, callers can spoof rate-limit records for other users or organizations.
- Audit/rate-limit telemetry becomes untrustworthy.

Required fix:

- Authenticate the caller.
- Derive `actor_id` from JWT, not request body.
- Keep limits server-defined, not request-defined.
- Require admin/system permission for cross-user checks.

### P0 - Legacy admin-pilot-action bypasses Sprint 7 onboarding controls

File: `supabase/functions/admin-pilot-action/index.ts`
Lines: 27-39 and 72-86

The function uses legacy `pilot_users.role = 'admin'` instead of the Sprint 7 role/permission model. It can upsert pilot users with arbitrary role/status but does not create role assignments, permission templates, activation checks, or onboarding audit records.

Impact:

- This creates an alternate admin path around the Sprint 7 enterprise onboarding model.
- Users may become active without the required organization, role assignment, permissions, profile checks, and audit attribution.

Required fix:

- Retire this function or rewrite it to delegate to the Sprint 7 functions.
- Require strict `can_manage_org_users` / `can_pause_org` permissions.
- Preserve onboarding audit events.

### P0 - Protected call and site-visit workflows do not consistently enforce exact permissions

Files:

- `supabase/functions/initiate-call/index.ts`
- `supabase/functions/create-site-visit/index.ts`
- `supabase/functions/verify-site-gps/index.ts`
- `supabase/functions/upload-site-photo/index.ts`
- `supabase/functions/broker-review-site-visit/index.ts`

Current state:

- `broker-upload-lead` now uses `has_strict_enterprise_permission` for `can_upload_leads`.
- `initiate-call` checks active pilot/org and data loan, but not `can_call_leads`.
- `create-site-visit` checks active pilot and data loan, but not `can_create_site_visits`.
- GPS/photo/review functions check pilot/org status but not exact `can_verify_site_visits` or `can_review_site_visits`.

Impact:

- Service-role functions bypass RLS, so exact permission checks are mandatory.
- Data loans prove temporary access, not role entitlement.

Required fix:

- Add strict permission checks to every service-role workflow:
  - `can_call_leads`
  - `can_create_site_visits`
  - `can_verify_site_visits`
  - `can_review_site_visits`

## High Findings

### P1 - Raw backend errors are still returned in older functions

Files:

- `supabase/functions/admin-pilot-action/index.ts:97`
- `supabase/functions/calculate-trust-score/index.ts:80`
- `supabase/functions/dispute-engine/index.ts:141`
- `supabase/functions/start-site-visit/index.ts:52`
- `supabase/functions/check-rate-limit/index.ts:60`
- `supabase/functions/generate-diagnostics/index.ts:49`
- `supabase/functions/system-health-check/index.ts:46`
- `supabase/functions/incident-response/index.ts:58`
- `supabase/functions/route-incoming-leads/index.ts:84`

Impact:

- Raw database/schema/authorization errors can be returned to clients.
- This does not show phone data in static code, but it violates the safe-error pattern.

Required fix:

- Return only generic safe reasons.
- Store sanitized diagnostics in `edge_function_failures` or audit tables.

### P1 - start-site-visit uses the anon client for protected state mutation

File: `supabase/functions/start-site-visit/index.ts`
Lines: 24-44

The function reads and updates `site_visits` using the authenticated client instead of a backend-owned state transition RPC. Sprint 2 explicitly moved protected state transitions into backend-controlled functions/RPCs.

Impact:

- If RLS blocks update, the workflow fails.
- If a future broad update policy appears, this can re-open direct state mutation risk.

Required fix:

- Move start transition into a `start_site_visit_v2` RPC with row-count checks and actor predicates.
- Use service role only after strict permission and assignment validation.

### P1 - Production deployment script is still Sprint 7 scoped

File: `scripts/production-deploy.ps1`
Lines: 145-147 and 210-260

The script says `Sprint 7 v0.7.0-enterprise-onboarding` and deploys Sprint 1-7 functions. It does not deploy current Sprint 9 function directories:

- `check-rate-limit`
- `generate-diagnostics`
- `system-health-check`

Impact:

- Source can exist while production remains stale.
- Sprint 9 reliability cannot be considered deployed through this script.

Required fix:

- Update deployment version and function list.
- Prefer deriving function names from an audited manifest.
- Keep smoke test status blocked until deployment logs prove success.

### P1 - Supabase config only declares three functions

File: `supabase/config.toml`
Lines: 2-26

Only these functions are configured:

- `admin-pilot-action`
- `calculate-trust-score`
- `dispute-engine`

The repo contains 34 non-shared function directories.

Impact:

- Function JWT/config behavior is not centrally visible for most functions.
- Deployment expectations are easy to misread.

Required fix:

- Add explicit function config for all deployed functions or document the deploy manifest.
- Verify JWT behavior for every function.

### P1 - Root build script is environment-fragile

File: `package.json`
Line: 8

`npm run build` delegates to `flutter build web --release`, but this shell does not have `flutter` on PATH. Direct build through `C:\src\flutter\bin\flutter.bat` passes.

Impact:

- Root build gate fails on the current workstation.
- Deployment script also checks bare `flutter`, so it can stop even when the SDK exists.

Required fix:

- Add a Windows-safe Flutter resolver or document that `C:\src\flutter\bin` must be on PATH.
- Keep `npm run build` passing before claiming local build readiness.

## Sprint Coverage

| Sprint | Source Status | Audit Status |
| --- | --- | --- |
| Sprint 1 | Migration and core functions exist | Source mostly aligned; live Exotel flow not verified |
| Sprint 2 | Migration and verification functions exist | RPC hardening added; `start-site-visit` still needs backend-owned transition |
| Sprint 3 | Organizations, disputes, trust artifacts exist | Legacy admin/dispute/trust functions still return raw errors and use legacy roles |
| Sprint 4 | Abuse/risk migration and functions exist | Some functions exist but deployment proof missing |
| Sprint 5 | Payout/routing migration and functions exist | Routing function is unauthenticated and therefore blocked |
| Sprint 6 | Compliance migration/functions/docs exist | Incident response function is unauthenticated and therefore blocked |
| Sprint 7 | Enterprise onboarding migration/functions exist | Static gate passes; legacy functions still bypass exact permissions |
| Sprint 8 | UI/docs exist | No backend migration for training/UX event tables found |
| Sprint 9 | Reliability migration/functions exist | Deployment script does not deploy all Sprint 9 functions |
| Sprint 10 | Docs exist | Launch readiness remains documentation-only without UAT/deployment evidence |

## Local Verification Evidence

Passed:

```powershell
npm run security
# Security constitution scan passed

& 'C:\Users\iBUGG3D\AppData\Local\Programs\Python\Python312\python.exe' scripts\security-check.py
# Security constitution scan passed

npm run sprint7:check
# Sprint 7 static check passed

& 'C:\src\flutter\bin\flutter.bat' analyze
# No issues found

& 'C:\src\flutter\bin\flutter.bat' build web --release
# Built build\web
```

Failed or blocked:

```powershell
python scripts\security-check.py
# Python is not on PATH in this shell

npm run build
# flutter is not on PATH in this shell

npx tsc --noEmit
# TypeScript is not installed/configured; marked N/A in AGENTS.md

npx supabase migration list
# 403, SUPABASE_DB_PASSWORD / privileges required

npx supabase functions list
# 403, privileges required
```

Static no-PII scans:

- No forbidden token hits in `flutter_app/lib` or `supabase/functions`.
- No 10-digit India contact pattern hits in app, functions, scripts, or migrations.

## Deployment and Live Workflow Status

Remote production state is not verified by this audit:

- Migrations could not be listed.
- Functions could not be listed.
- `db push` was not run because credentials are missing and deployment is outside this audit.
- Live Exotel call flow was not tested.
- Browser Network, Supabase logs, storage paths, and audit table outputs were not inspected live.

## Required Next Actions Before Any New Sprint

1. Fix P0 unauthenticated service-role functions.
2. Add strict permission checks to every protected workflow.
3. Replace raw client errors with generic safe responses.
4. Update deployment script/function manifest to current sprint scope.
5. Fix root `npm run build` by resolving Flutter PATH.
6. Deploy with valid Supabase credentials.
7. Run live UAT from lead upload through secure call, GPS/photo, broker lock, payout, dispute, abuse, and role blocks.
8. Confirm no phone/name/raw provider data in UI, browser network, Supabase logs, audit tables, storage paths, or exports.

Until these pass, Sprint 1-10 should be treated as source-present but production-unverified.

