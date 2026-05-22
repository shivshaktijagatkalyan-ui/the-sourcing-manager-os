# FRONTEND RUNTIME AUDIT

Generated: 2026-05-22
Verdict: B. PARTIAL - BLOCKERS REMAIN

## What was tested
- Flutter source, training-mode guards, Platform Admin drawer navigation, localhost browser runtime, and browser dashboard smoke checks.

## What passed
- `flutter analyze` passed.
- `flutter build web --release` passed.
- `flutter build apk --release` passed.
- `npm run broker-dashboard:final-check` passed.
- Platform Admin drawer `Organizations` now routes to `SuperAdminDashboard` at `flutter_app/lib/main.dart:658-662` and `flutter_app/lib/widgets/global_drawer.dart:123-130`.
- Training-mode write guards are present in the audited write forms.

## What failed
- Browser dev logs on `http://127.0.0.1:5058/?training=true&mockRole=platform_admin` emitted Flutter runtime errors from `main.dart.js`. The screenshot still rendered the dashboard, but the DOM snapshot was unreliable and exposed only the accessibility node after reload.
- The Super Admin training/demo dashboard showed `Release Gate PASS` and `Migration Drift UNKNOWN` even though the actual release gate failed. Demo values are hardcoded at `flutter_app/lib/screens/super_admin_dashboard.dart:707-708`.

## What is dangerous
- Operational users can see stale platform-health signals that contradict real release evidence.
- A local UI that renders while logging runtime errors can hide broken accessibility/DOM behavior.

## What is unproven
- Role-aware rendering for every role under live Supabase auth.
- Offline/retry flows under network loss.
- Production dashboard health accuracy unless `super-admin-dashboard` has fresh `deployment_events` records.

## Exact blocker
- Misleading demo health defaults: `flutter_app/lib/screens/super_admin_dashboard.dart:701-708`.

## Exact recommended fix
- Remove hardcoded `lastReleaseGate: 'pass'` from demo/admin fallback states or label it explicitly as demo-only.
- On production builds, fail closed when platform-health evidence is missing instead of showing pass.
- Add browser regression tests that assert no Flutter runtime errors after app startup and drawer navigation.

## Harsh-truth verdict
Frontend build integrity is good, and the previous route bug is fixed, but runtime health reporting is not trustworthy enough for production operations.

