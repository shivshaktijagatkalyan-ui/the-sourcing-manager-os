# ONBOARDING TRUST GATE REPORT

Date: 2026-05-12

## Result

PASS WITH CONFIG BLOCKER.

Frontend direct role/profile writes were removed from the production onboarding path in `flutter_app/lib/screens/choose_role_screen.dart`. Logged-in users are now sent to server-governed onboarding instead of writing `role_assignments`, `brokers_public`, `sourcing_managers_public`, or `pilot_users` directly from Flutter.

## Changed

- `choose_role_screen.dart`
  - Removed direct client `upsert` calls into trust identity tables.
  - Routes logged-in users to `ExecutiveOnboardingScreen`.
  - Anonymous users still go through auth/signup first.
- `executive_onboarding_screen.dart`
  - Supports a preselected requested role.
  - Invokes `complete-onboarding` only.
- `caller_signup_screen.dart`
  - Google caller signup now requires the entered invite code instead of sending a hardcoded fake invite value.
- `complete-onboarding/index.ts`
  - Returns consistent `{ ok: true }` success.
  - Admin/developer access returns request-only status and does not create privileged role assignments.
  - Caller onboarding now requires `CALLER_INVITE_CODE` from server secrets and fails closed if missing.
  - Internal database error strings are no longer returned directly for common onboarding failures.

## Verified

- Broker onboarding through `complete-onboarding` passed in live UAT.
- No frontend direct writes to role/profile tables remain in `choose_role_screen.dart`.
- `npx tsc --noEmit` passed.
- `flutter analyze` passed.

## Blocker

Remote `CALLER_INVITE_CODE` is not currently present in `supabase secrets list`. New caller onboarding will fail closed until that secret is set.

## Verdict

Server-governed onboarding is now the default trust path. Caller onboarding is intentionally blocked until an invite secret is configured.
