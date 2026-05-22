# MASTER SYSTEM AUDIT REPORT

Generated: 2026-05-22
System: FutureTrust / The Sourcing Manager OS
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- Frontend runtime at `http://127.0.0.1:5058/?training=true&mockRole=platform_admin`.
- Flutter web/APK build gates, Flutter analyzer, root TypeScript no-emit gate, security scripts, Sprint 7 static check, AI tool static check, broker dashboard final check, trust-loop UAT, and controlled release gate.
- Supabase Edge Functions, RLS migrations, database workflow functions, callback handling, site visit proof chain, broker locks, and Next API surfaces.

## What passed
- `python scripts/security-check.py` passed.
- `npm run security` passed.
- `npm run sprint7:check` passed.
- `npx tsc --noEmit` passed.
- `npm run ai:tools:check` passed.
- `npm run broker-dashboard:final-check` passed.
- `npm run build` passed and built Flutter web.
- `flutter analyze` passed.
- `flutter build web --release` passed with a non-blocking Cupertino font warning.
- `flutter build apk --release` passed and produced `build/app/outputs/flutter-apk/app-release.apk`.
- Browser check confirmed the Platform Admin `Organizations` drawer route now lands on `SuperAdminDashboard` instead of the old organization-context dead end.
- Training guards are present in `flutter_app/lib/screens/add_broker_screen.dart:64`, `flutter_app/lib/screens/add_lead_from_broker.dart:52`, `flutter_app/lib/screens/add_lead_from_broker.dart:83`, and `flutter_app/lib/screens/caller_lead_queue_screen.dart:25`.

## What failed
- `powershell -ExecutionPolicy Bypass -File scripts/release-gate.ps1` failed. `CONTROLLED_PILOT_RELEASE_GATE_REPORT.md` records `Supabase migration dry run | FAIL | 1`.
- `npx supabase db push --dry-run --linked` reported local migrations that would be inserted before the last remote migration: `001_create_crm_erp_schema.sql`, `20260507000210_sprint8_goals_expanded.sql`, `20260518000000_fix_authenticated_broker_rls.sql`, and `20260518000000_fix_authenticated_broker_rls_CLEAN.sql`.
- A standalone `node scripts/uat-trust-loop.mjs` run failed at photo proof with `{"ok":false,"reason":"invalid_proof_path"}`. The later release-gate UAT pass was dependent on a different generated UUID/path and does not remove the bug.
- Current provider success is not production proof because `ENABLE_PROVIDER_MOCK=true` is set in `.env:38` and `provider.env:11`, and `supabase/functions/initiate-call/index.ts:196` bypasses Exotel.

## What is dangerous
- Unauthenticated Next API routes use a service-role Supabase client. `web-dashboard/src/lib/server-supabase.ts:3` creates the service-role client, while routes such as `web-dashboard/src/app/api/crm-erp/leads/search/route.ts:20` and `web-dashboard/src/app/api/crm-erp/leads/batch-update/route.ts:14` expose read/update paths without route auth.
- The legacy CRM migration drops production-shaped tables at `supabase/migrations/001_create_crm_erp_schema.sql:5-7` and then creates broad authenticated policies with `USING (true)` / `WITH CHECK (true)` at lines `104-126`.
- The Super Admin demo snapshot can show `lastReleaseGate: 'pass'` and `migrationDrift: 'unknown'` at `flutter_app/lib/screens/super_admin_dashboard.dart:707-708`, conflicting with the actual failed release gate.

## What is unproven
- Real Exotel outbound call acceptance.
- Valid signed Exotel callback success path from the provider.
- Production migration application order.
- Cross-org safety of the newly introduced CRM/ERP Next API.
- Non-flaky photo proof validation.

## Exact blockers
- Provider mock bypass: `supabase/functions/initiate-call/index.ts:196-203`.
- Migration drift: `scripts/release-gate.ps1:47-48` runs `npx supabase db push --dry-run --linked`, which currently fails.
- Service-role API exposure: `web-dashboard/src/lib/server-supabase.ts:3-11` plus unauthenticated API routes under `web-dashboard/src/app/api/crm-erp`.
- Flaky photo proof path rejection: `supabase/functions/verify-site-visit-proof/index.ts:28` and `:233-234`.

## Exact recommended fix
- Remove `ENABLE_PROVIDER_MOCK=true` from production and pilot secrets; allow mock only in isolated UAT projects with an explicit environment assertion.
- Fix migration ordering/drift before any pilot cutover; do not use `--include-all` blindly until destructive migrations are reviewed.
- Put all Next API routes behind authenticated session/JWT validation and organization/role checks, or remove them from deployable production.
- Replace phone-number regex scanning of entire storage paths with structured filename validation and evidence-object verification.
- Feed release-gate and migration status from real deployment evidence, not demo snapshot defaults.

## Harsh-truth verdict
C. BLOCKED - SECURITY / LOGIC FAILURE FOUND.

