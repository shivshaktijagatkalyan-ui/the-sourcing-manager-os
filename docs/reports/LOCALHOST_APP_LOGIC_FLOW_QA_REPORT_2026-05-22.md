# Localhost App Logic Flow QA Report - 2026-05-22

Workspace: `C:\Users\iBUGG3D\Desktop\The Sourcing MAnager OS`

## Scope

Checked the built Flutter Web PWA and the separate Next.js broker dashboard on localhost.

Local targets used:

- Flutter release web build: `http://127.0.0.1:5055`
- Fresh Flutter training origins for deterministic role checks: `http://127.0.0.1:5056`, `http://127.0.0.1:5057`
- Next broker dashboard: `http://127.0.0.1:3000/broker`

Screenshots:

- `output/playwright/flutter-admin-dashboard.png`
- `output/playwright/flutter-admin-organizations-route-bug.png`
- `output/playwright/flutter-admin-projects-route-bug.png`
- `output/playwright/flutter-caller-queue-updated.png`
- `output/playwright/next-broker-secure-lead-modal.png`

## Verification Commands

Passed:

```powershell
npm run build
```

Result: Flutter release web build completed successfully.

Passed:

```powershell
npx tsc --noEmit
```

Result: no TypeScript errors.

Passed:

```powershell
cd web-dashboard
npm run build
```

Result: Next.js production build completed successfully.

Passed:

```powershell
cd flutter_app
& 'C:\src\flutter\bin\flutter.bat' analyze
```

Result: no Flutter analyzer issues.

## Flow Results

### Flutter PWA - Sourcing Manager

Status: PASS with environment caveat below.

- Sourcing Manager training dashboard rendered.
- Add Broker flow accepted a safe alias-only demo broker and showed success.
- Add Lead From Broker flow selected source broker, accepted masked one-time contact entry, ingested alias/metadata, cleared the visible fields, and showed a success modal with lead alias only.
- No plain contact value was visible in the tested success screens.

### Flutter PWA - Caller

Status: PASS.

- Caller dashboard rendered from fresh training origin.
- Assigned Calls queue showed one assigned lead from seeded training data.
- Secure Call action queued successfully and displayed "No sensitive data was returned."
- Outcome update to `visit_scheduled` updated visible badges and dashboard count.
- A follow-up Secure Call after terminal outcome was blocked with "Active data loan required", preserving the loan gate.

### Flutter PWA - Broker

Status: PASS.

- Broker Business Vault rendered.
- Broker Lead Upload accepted alias, masked one-time phone input, area, project, and budget.
- Success modal returned only alias and lead ID.
- Phone field was cleared/placeholder-only after submit.

### Flutter PWA - Platform Admin

Status: PARTIAL.

- Super Admin Control Room rendered with health, KPI, workflow, risk, and audit sections.
- Projects drawer item opened the admin ERP/analytics project view.
- Organizations drawer item opened a dead-end "No organization context found." screen. See bug B1.

### Next Broker Dashboard

Status: PASS.

- `/broker` loaded with no browser console errors.
- Production build passed.
- Search field accepted alias search (`L-1042`) and narrowed the command center.
- Add Secure Lead opened the secure intake modal.
- Dashboard showed no raw contact values in the tested surface.

## Bugs Found

### B1 - Admin Organizations drawer route opens an org-scoped dead end

Severity: P1

Remediation status: FIXED on 2026-05-22.

Fix evidence:

- Screenshot: `output/playwright/flutter-admin-organizations-route-fixed-5058.png`
- Verification origin: `http://127.0.0.1:5058/?training=true&mockRole=platform_admin`
- Result: `Organizations` now opens `Real Estate Operations Control Room` / `FutureTrust Command Center`.

Evidence:

- Screenshot: `output/playwright/flutter-admin-organizations-route-bug.png`
- Browser path: `http://127.0.0.1:5057/?training=true&mockRole=platform_admin`

Observed:

- Platform admin opens drawer.
- Tap `Organizations`.
- App shows: `No organization context found.`

Code references:

- `flutter_app/lib/main.dart:188` registers `OrganizationDashboard` in `_screens`.
- `flutter_app/lib/main.dart:647` to `flutter_app/lib/main.dart:650` maps Admin `Organizations` to `_select(9)`.
- `flutter_app/lib/screens/organization_dashboard.dart:21` to `flutter_app/lib/screens/organization_dashboard.dart:42` requires a live Supabase user/org context and has no training fallback.

Impact:

- Platform admin cannot use the drawer Organizations route in localhost training.
- In live production, the route is also suspicious for platform-admin use because it loads only the current user's `pilot_users.org_id`, not the organization list/control view shown in the Super Admin dashboard.

Suggested fix:

- Route platform admin `Organizations` to an organization list/control screen or add an explicit training/demo snapshot path.
- Avoid `Supabase.instance.client.auth.currentUser!` on a training route.

### B2 - Some training-mode write flows can still hit live Supabase when Supabase is configured

Severity: P0/P1 depending on environment.

Remediation status: FIXED on 2026-05-22.

Fix evidence:

- `flutter_app/lib/screens/add_broker_screen.dart`
- `flutter_app/lib/screens/add_lead_from_broker.dart`
- `flutter_app/lib/screens/caller_lead_queue_screen.dart`
- Regression test: `flutter_app/test/defect_audit_regression_test.dart`

Evidence type: static code check plus Production vs Preview assumption.

Observed locally:

- Current localhost build had no Supabase Dart defines, so these screens used training/demo logic.

Risk:

- If the same code is built with `SUPABASE_URL` and `SUPABASE_ANON_KEY`, then opened on localhost/preview with `?training=true`, several write paths branch on `AppConfig.isSupabaseConfigured` only.
- That contradicts the visible banner: `TRAINING MODE - NO DATA IS SAVED`.

Code references:

- `flutter_app/lib/screens/add_broker_screen.dart:64`
- `flutter_app/lib/screens/add_lead_from_broker.dart:51`
- `flutter_app/lib/screens/add_lead_from_broker.dart:82`
- `flutter_app/lib/screens/caller_lead_queue_screen.dart:382`

Impact:

- Demo/training actions could read or mutate live Supabase data in a configured Preview/local environment.
- Affected areas include broker creation, lead-from-broker intake, broker picker reads, and caller outcome updates.

Suggested fix:

- Change these branches to `AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode`, matching the safer pattern already used by `BrokerUploadScreen`, `BrokerDashboardScreen`, and caller queue reads.

## Final Status

Local built PWA: PASS

Next broker dashboard: PASS

Core training sales flows tested: PASS

Blocking localhost bug: FIXED - Admin Organizations route no longer opens the org-scoped dead end

Production/Preview risk: FIXED - audited write branches now skip live Supabase when `AppConfig.isTrainingMode` is true
