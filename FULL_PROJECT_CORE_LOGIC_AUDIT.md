# Full Project Core Logic Audit

## Latest Verification Addendum - 2026-05-05
- Updated status: CONTROLLED UAT READY / NOT FULL DAILY-USE ACCEPTED
- What changed after the original audit:
  - Remote migration parity is now verified through `20240517000200`.
  - Remote Supabase functions now include `manage-external-broker`, `initiate-broker-call`, `lead-from-broker`, and `manage-caller-workflow`.
  - `flutter analyze` now exits clean with `No issues found!`.
  - Local Flutter web production build succeeds.
  - Security constitution scanners pass.
  - A fail-closed role-gating bug was found and fixed locally: `unknown` role was previously treated as admin in `flutter_app/lib/main.dart`.
- Remaining acceptance boundary:
  - The code is ready for controlled end-to-end UAT, but not yet accepted for daily pilot operations until the real Vinod/Jitu/Wadhwa flow is tested on device with Exotel, GPS/photo, browser network inspection, logs, and audit table review.
  - The local Flutter source was patched after the claimed deployment summary; the hosted PWA must use the rebuilt bundle before relying on the fixed role gate.
- Fresh verification evidence:
  - `python scripts/security-check.py`: PASS
  - `npm run security`: PASS
  - `npm run sprint7:check`: PASS
  - `flutter analyze`: PASS
  - `flutter build web --release`: PASS
  - `npm run build`: PASS
  - `git diff --check`: PASS, CRLF warnings only
  - `npx supabase migration list`: PASS, local and remote migrations match through `20240517000200`
  - `npx supabase functions list`: PASS, practical MVP functions are active
  - `npx tsc --noEmit`: FAIL / NOT APPLICABLE, root TypeScript compiler is not installed and AGENTS.md states this gate is not applicable for this Flutter/Supabase hybrid

## 1. Executive Summary
- Overall status: PARTIAL
- Practical MVP readiness: BLOCKED
- Field pilot readiness: BLOCKED
- Major blockers:
  - Remote Supabase migration history is missing the practical MVP migrations `20240514000000` through `20240517000200`.
  - Remote Edge Functions list does not include `manage-external-broker`, `initiate-broker-call`, `lead-from-broker`, or `manage-caller-workflow`.
  - `flutter analyze` exits with failure because 26 analyzer issues remain.
  - Live workflow evidence is missing for broker onboarding, broker secure call, lead intake, caller assignment, caller outcome, GPS/photo, and Exotel.
  - Root `npx tsc --noEmit` fails because this repo has no root TypeScript compiler setup. AGENTS.md marks this gate as not applicable for the Flutter/Supabase architecture.
- Security risks:
  - One-time phone/email intake exists in broker/lead upload screens and is sent to Edge Functions for encryption. No post-submit display was found, but browser request inspection must be tested during UAT.
  - Main navigation exposes many admin/operator screens in the drawer regardless of role. Backend RLS/Edge Functions should block unsafe actions, but role-specific UX gating is incomplete.
  - Several advanced functions rely on local migrations that are not deployed yet.

## 2. What Is Already Built
- Backend database:
  - Sprint 1 foundation tables exist in local migrations: `leads_public`, `leads_sensitive`, `data_loans`, `call_attempts`, `audit_events`, `site_visits`, `broker_locks`.
  - Practical MVP tables exist locally: `brokers_public`, `brokers_sensitive`, `broker_activations`, `broker_activity_logs`, `broker_followups`.
  - Caller assignment support exists locally: `assigned_caller_id`, call outcome fields, assignment trigger, `assign_lead_to_caller_v1`.
  - Enterprise/RBAC/risk/payout/compliance tables exist in local migrations.
- Edge Functions:
  - Sprint 1-7 and reliability functions exist locally.
  - Practical MVP functions exist locally: `manage-external-broker`, `initiate-broker-call`, `lead-from-broker`, `manage-caller-workflow`.
  - Review hardening exists locally for strict permission checks, state transition row counts, generic error responses, and incident abuse telemetry.
- Flutter screens:
  - Broker CRM screens exist: Add Broker, Broker List, Broker Detail, Follow-up Queue, Activation Pipeline.
  - Caller screens exist: Caller Dashboard and Caller Lead Queue.
  - Site visit, risk, payout, compliance, onboarding, diagnostics, and role dashboards exist.
- Role dashboards:
  - `RoleDashboardContainer` routes `caller`, `broker`, and `sourcing_manager`.
  - Unknown roles show Access Restricted.
- Caller support:
  - Caller dashboard and queue are present.
  - Secure customer call invokes `initiate-call` with only `lead_id`.
  - Outcome updates invoke `manage-caller-workflow`.
- Broker CRM:
  - Broker add/list/detail/follow-up/pipeline screens exist.
  - Broker secure call invokes `initiate-broker-call` with only `broker_id`.
- Site visit connection:
  - Local migrations connect `site_visits` to `source_broker_id` and `source_lead_id`.
  - GPS/photo functions exist and use atomic RPCs.
- Performance dashboard:
  - Sourcing Manager, Broker, Caller, leaderboard, payout, and ROI screens exist.
- Documentation:
  - Extensive roadmap, runbooks, UAT, launch, security, and compliance docs exist.

## 3. What Is Actually Working
- Verified by command:
  - `python scripts/security-check.py`: PASS.
  - `npm run security`: PASS.
  - `npm run sprint7:check`: PASS.
  - `git diff --check`: PASS, only CRLF warnings.
  - `flutter build web --release`: PASS, produced `build\web`.
  - `npm run build`: PASS, delegates to Flutter web build.
  - `npx supabase migration list`: PASS, remote connection works and reports migration drift.
  - `npx supabase functions list`: PASS, remote function list is readable.
- Verified in source:
  - Sensitive lead/broker storage uses ciphertext columns.
  - Secure call buttons send IDs only in the inspected Flutter code paths.
  - Frontend protected writes are routed through Edge Functions; no `.insert`, `.update`, `.delete`, or `.upsert` calls were found in Flutter source.
  - The pasted P0/P1 review findings were addressed locally:
    - Secure RPCs return `ok=false` when no row transitions.
    - `broker-upload-lead` now checks active org and `can_upload_leads`.
    - `verify-site-gps` returns generic safe errors.
    - `incident-response`, `route-incoming-leads`, `check-rate-limit`, and `admin-pilot-action` now authenticate and use permission gates locally.

## 4. What Is Only Documented But Not Implemented
- v1.0 completion claims are not proven by deployed state.
- Practical MVP broker CRM is implemented locally but not deployed remotely.
- Practical MVP remote smoke tests are not present.
- A real 7-day field pilot run is not evidenced.
- Real Exotel broker/customer call-through is not evidenced after the latest local hardening.
- Real browser DevTools no-PII inspection is not evidenced after the latest local hardening.
- Legal/compliance docs exist as drafts/runbooks, not lawyer-approved production sign-off.
- Public launch readiness is documented but not verified by UAT evidence.

## 5. What Is Missing
- Remote migrations missing:
  - `20240514000000_practical_mvp_crm.sql`
  - `20240515000000_broker_performance_linkage.sql`
  - `20240516000000_caller_workflow_support.sql`
  - `20240517000000_incident_response_abuse_event.sql`
  - `20240517000100_permission_wiring_hardening.sql`
  - `20240517000200_caller_assignment_security.sql`
- Remote Edge Functions missing:
  - `manage-external-broker`
  - `initiate-broker-call`
  - `lead-from-broker`
  - `manage-caller-workflow`
- Clean Flutter analyzer result is missing.
- Live smoke-test evidence is missing for the exact Vinod/Jitu/Wadhwa pilot flow.
- Role-gated navigation is incomplete in Flutter; the drawer exposes screens beyond the detected role.
- No dedicated deployed `schedule-site-visit` function exists; scheduling is implemented locally as an action inside `lead-from-broker`.

## 6. Frontend ↔ Backend Wiring
- Add Broker: PARTIAL
  - UI exists and calls `manage-external-broker`.
  - Backend exists locally and encrypts sensitive fields.
  - Remote function and tables are not deployed.
- Broker List: PARTIAL
  - UI reads `brokers_public` and `broker_activations`.
  - Remote tables are not deployed.
- Broker Detail: PARTIAL
  - UI shows broker profile, activation, leads, site visits, and performance counts.
  - Calls practical MVP functions locally.
  - Remote support is missing.
- Follow-up Queue: PARTIAL
  - UI exists and calls `manage-external-broker`.
  - Remote table/function support is missing.
- Activation Pipeline: PARTIAL
  - UI exists and reads `broker_activations`.
  - Remote table support is missing.
- Secure Broker Call: PARTIAL / MANUAL REQUIRED
  - UI sends `broker_id` only.
  - Local Edge Function decrypts only server-side and wipes variables.
  - Remote function is not deployed; Exotel call-through not verified.
- Lead From Broker: PARTIAL
  - UI and local Edge Function exist.
  - Local audit column bug was fixed.
  - Remote function/table support is missing.
- Caller Assignment: PARTIAL
  - UI invokes `manage-caller-workflow`.
  - Local RPC-backed assignment/data-loan path was added.
  - Remote migration/function support is missing.
- Caller Queue: PARTIAL
  - UI reads assigned leads from `leads_public`.
  - Depends on local caller assignment migration not deployed remotely.
- Secure Customer Call: PARTIAL / MANUAL REQUIRED
  - UI sends only `lead_id`.
  - Function checks permission, active loan, consent, DND, and org scope locally.
  - Real Exotel call-through not verified in this audit.
- Call Outcome: PARTIAL
  - UI invokes `manage-caller-workflow`.
  - RPC exists locally.
  - Remote function/migration support is missing.
- Site Visit Scheduling: PARTIAL
  - Implemented locally as `lead-from-broker` action.
  - Remote practical MVP function/migration support is missing.
- GPS/Photo Verification: PARTIAL / MANUAL REQUIRED
  - Core deployed Sprint 2 functions exist remotely.
  - Latest local hardening still needs deployment and physical GPS/camera smoke testing.
- Broker Performance Dashboard: PARTIAL
  - UI counts exist.
  - Depends on practical MVP linkage migrations not deployed remotely.

## 7. Role Dashboard Audit
- Sourcing Manager Dashboard: PARTIAL
  - Present and builds.
  - Reads safe operational tables.
  - Action buttons currently instruct users to use the side menu instead of navigating directly.
- Broker Dashboard: PARTIAL
  - Present and builds.
  - Reads safe metadata tables.
- Caller Dashboard: PARTIAL
  - Present and builds.
  - Reads assigned lead counts and call attempts.
- Admin Dashboard: PARTIAL
  - Multiple admin/operator screens exist.
  - Drawer is not role-filtered; backend must enforce access.
- Unknown role fallback: PASS
  - Unknown/anonymous roles show Access Restricted.

## 8. Security Constitution Audit
- phone exposure: PARTIAL
  - No post-submit phone display found in scanned UI.
  - One-time input and request submission exist for broker/lead intake and must be verified in browser DevTools.
- email exposure: PARTIAL
  - Broker invite uses hashed invite references.
  - Add Broker has one-time email input for encrypted broker sensitive storage.
- masked phone: PASS by scanner.
- last four: PASS by scanner.
- WhatsApp/tel links: PASS by scanner.
- contact export: PASS in inspected source.
- raw logs: PASS by scanner after local fixes.
- sensitive table access: PASS in local migrations for `leads_sensitive` and `brokers_sensitive` frontend SELECT denial.
- audit no-PII: PARTIAL
  - Local fixes moved practical MVP audits to `event_context`.
  - Live remote audit table contents were not inspected in this audit.
- RLS: PARTIAL
  - RLS is enabled in local migrations.
  - Remote practical MVP RLS is not active because those migrations are not applied.
- result: PARTIAL / BLOCKED for field pilot.

## 9. Build Results
- security-check.py: PASS
  - Output: `Security constitution scan passed`
- npm run security: PASS
  - Output: `Security constitution scan passed`
- npm run sprint7:check: PASS
  - Output: `Sprint 7 static check passed`
- flutter analyze: FAIL
  - Exit code: 1
  - Output summary: 26 issues found.
  - Main categories: `use_build_context_synchronously`, unused fields, deprecated `value` usage.
- flutter build web: PASS
  - Output: `Built build\web`
- npm run build: PASS
  - Delegated to Flutter build and produced web build.
- npx tsc --noEmit: FAIL / NOT APPLICABLE
  - Output says TypeScript is not installed and AGENTS.md states root TypeScript is not applicable for this Flutter/Supabase hybrid.
- npx supabase migration list: PASS
  - Shows remote migration drift; practical MVP migrations are local only.
- npx supabase functions list: PASS
  - Shows deployed core functions but not practical MVP functions.

## 10. Bugs Found
- file: `supabase/functions/manage-caller-workflow/index.ts`
  - issue: Service-role assignment path was weakly gated and incompatible with trigger actor attribution.
  - severity: P0
  - suggested fix: Use strict permission checks and RPC-backed assignment with explicit actor and organization scope.
- file: `supabase/functions/lead-from-broker/index.ts`
  - issue: Inserted into non-existent `audit_events.organization_id` and `audit_events.context` columns.
  - severity: P0
  - suggested fix: Use `recordAudit` and `event_context`.
- file: `supabase/functions/exotel-callback/index.ts`
  - issue: Used non-existent `provider_sid` and `call_attempts.organization_id`.
  - severity: P0
  - suggested fix: Use `provider_call_id` and derive org from `leads_public`.
- file: `supabase/functions/incident-response/index.ts`
  - issue: Abuse event used an event type not allowed by schema/RPC and used a risk delta outside the table constraint.
  - severity: P0
  - suggested fix: Add allowed event type and clamp risk delta.
- file: `supabase/functions/*`
  - issue: Several functions required permissions that did not exist in permission metadata.
  - severity: P0
  - suggested fix: Add permission definitions and role mappings.
- file: `scripts/production-deploy.ps1`
  - issue: Practical MVP functions were missing from deployment manifest and Flutter path fallback was incomplete.
  - severity: P1
  - suggested fix: Include all practical functions and use detected Flutter executable.
- file: `flutter_app/lib/screens/role_dashboard_container.dart`
  - issue: Missing `AppConfig` import.
  - severity: P1
  - suggested fix: Import `../app_config.dart`.
- file: `flutter_app/lib/main.dart`
  - issue: Navigation drawer is not role-filtered and some indices are inconsistent with screen positions.
  - severity: P1
  - suggested fix: Gate drawer items by role/permission and verify indices.
- file: multiple Flutter screens
  - issue: `flutter analyze` reports 26 warnings/info items.
  - severity: P2
  - suggested fix: Resolve async context usage, unused fields, and deprecated `value` parameters.

## 11. Fixes Applied
- Hardened `manage-caller-workflow` to use JWT identity, strict permissions, safe errors, sanitized notes, and `assign_lead_to_caller_v1`.
- Added `20240517000200_caller_assignment_security.sql` for RPC-backed caller assignment and actor-safe auto data loan trigger.
- Fixed `lead-from-broker` audit writes to use `recordAudit` and removed lead alias from broker activity notes.
- Fixed `exotel-callback` to use `provider_call_id` and derive org context safely.
- Added `20240517000000_incident_response_abuse_event.sql` to allow incident lockdown abuse telemetry.
- Added `20240517000100_permission_wiring_hardening.sql` for missing permission definitions and role mappings.
- Updated `_shared/sprint7.ts` permission list and strict permission helper usage.
- Updated `scripts/production-deploy.ps1` to use Flutter fallback path and deploy practical MVP functions.
- Updated `scripts/security-check.mjs` to match the Python scanner's practical MVP allowlist.
- Fixed `RoleDashboardContainer` missing `AppConfig` import.
- Removed raw backend error response in `manage-caller-workflow`.
- Removed trailing whitespace/new-blank-line diff-check failures.

## 12. Remaining Manual Tests
- Exotel real broker call from `initiate-broker-call`.
- Exotel real customer call from `initiate-call`.
- Browser DevTools request/response inspection during broker upload, lead upload, secure call, and callbacks.
- GPS hardware outside-geofence and inside-geofence tests.
- Camera/photo upload to private storage path.
- Browser login for Vinod/sourcing manager, caller, broker, and unknown role.
- Production Supabase smoke test after applying local migrations.
- RLS direct-select test for `leads_sensitive` and `brokers_sensitive`.
- Audit table inspection for no PII after real flow.
- Full UAT flow: add broker -> activate -> receive lead -> assign caller -> call -> interested -> schedule visit -> verify -> broker lock.

## 13. Final Verdict
B. PARTIAL — FIX LIST REQUIRED

The app is not ready for daily use by Vinod, a caller, and a broker yet. The local codebase is materially built and the Flutter web build succeeds, but the practical MVP database/functions are not deployed remotely, Flutter analyzer is not clean, and the real workflow has not passed live UAT.

## 14. Next Build Order
1. Deploy local migrations `20240514000000` through `20240517000200` to Supabase.
2. Deploy missing practical MVP functions: `manage-external-broker`, `initiate-broker-call`, `lead-from-broker`, `manage-caller-workflow`.
3. Rerun `scripts/production-deploy.ps1` and confirm migration/function drift is resolved.
4. Fix Flutter analyzer issues until `flutter analyze` exits 0.
5. Role-filter the drawer/navigation so users do not see unauthorized operator screens.
6. Run one full Vinod/Jitu/Wadhwa UAT flow with safe test data.
7. Inspect Browser Network, Edge logs, `audit_events`, `call_attempts`, storage paths, and sensitive tables for zero post-submit phone/contact exposure.
8. Record evidence in the UAT and pilot smoke-test reports.
