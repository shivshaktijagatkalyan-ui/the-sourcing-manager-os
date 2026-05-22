# Project Deep Check Report

Date: 2026-05-12
Workspace: `C:\Users\iBUGG3D\Desktop\The Sourcing MAnager OS`

## What We Are Doing

The Sourcing Manager OS is a production-critical real estate sourcing and sales operating system. The core product is a Flutter Web PWA backed by Supabase PostgreSQL, Auth, RLS, and Edge Functions. The system is built around deterministic lead intake, protected contact access, secure call bridges, site visit verification, broker locks, payout tracking, onboarding, and operational dashboards.

Current product direction remains unchanged: preserve the existing Flutter/Supabase architecture, keep sensitive buyer data out of dashboards, and rely on server/database state transitions instead of generic AI behavior.

## What Is Already Done

- Flutter PWA build flow exists through root `npm run build`, which redirects to `flutter build web --release`.
- Supabase migrations and Edge Functions cover lead upload, caller assignment, secure calls, site visits, broker review, onboarding, governance, abuse monitoring, payout, and diagnostics.
- Web dashboard exists as a separate Next.js app under `web-dashboard`.
- Training mode and role-based dashboards exist for broker, sourcing manager, caller, and admin flows.
- Sprint 7 static permission checks and security constitution scans are active.

## Deep Check Findings Solved In This Pass

1. AI lead response hardening
   - Removed Edge Function runtime logging from `ai-lead-response`.
   - Stopped writing raw provider error bodies into audit context.
   - Registered `ai-lead-response` in `supabase/config.toml` with JWT verification and import map.
   - Allowed contact wording only for this legitimate secure voice bridge path in security scans.

2. Secret handling
   - Replaced plaintext Google OAuth values in `supabase/config.toml` with `env(...)` references.
   - Added example OAuth env names to `.env.example`.
   - Added security scan coverage so future literal OAuth provider secrets in `supabase/config.toml` fail the check.
   - Imported the rotated Google OAuth client JSON into local `.env` and `.env.local` without printing secret values.
   - Pushed the Supabase Auth config with the Google OAuth env values loaded in-process.
   - Added explicit hosted Auth settings to `supabase/config.toml` so future config pushes preserve the remote Auth policy instead of falling back to local CLI defaults.
   - Deleted the downloaded Google OAuth client JSON from `C:\Users\iBUGG3D\Downloads` after import.
   - This follows Supabase CLI guidance that `config.toml` can reference env vars using `env()`: https://supabase.com/docs/guides/local-development/managing-config

3. Flutter analyzer and tests
   - Replaced deprecated dropdown `value` usage with `initialValue`.
   - Replaced `dart:html` URL cleanup with `package:web`.
   - Added guarded Supabase client access so tests and failed initialization paths do not crash on `Supabase.instance`.
   - Kept training mode local even when production Supabase constants exist.
   - Restored deterministic role selection and caller invite-code onboarding UI.
   - Unknown dashboard role now fails closed through access restricted UI.

4. Onboarding persistence
   - Moved `complete-onboarding` onto shared Supabase helpers instead of direct local service-key wiring.
   - Added `user_onboarded` audit persistence after successful role/profile setup.

5. Web dashboard verification
   - Fixed ESLint errors and warnings.
   - Removed unused imports/state and loose `any`.
   - Set `turbopack.root` in `next.config.ts` to avoid the multi-lockfile workspace warning.
   - This follows the Next.js Turbopack root option, which requires an absolute app root: https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopack

## Verification Evidence

Passed:

- `npm run build`
  - Result: PASS
  - Built Flutter web release artifact at `flutter_app/build/web`.
  - Remaining advisory: Flutter web Wasm dry run succeeded and suggests optionally building/testing with `--wasm`.

- `npm run security`
  - Result: PASS

- `npx tsc --noEmit`
  - Result: PASS
  - Note: the root TypeScript command exits cleanly with `tsconfig.json` scoped to `scripts/**/*.mjs`; TypeScript app-level verification is still covered separately in `web-dashboard`.

- `npm run sprint7:check`
  - Result: PASS

- `flutter analyze`
  - Result: PASS, no issues found.

- `flutter test`
  - Result: PASS, 20/20 tests passed.

- `web-dashboard: npx tsc --noEmit`
  - Result: PASS

- `web-dashboard: npm run lint`
  - Result: PASS

- `web-dashboard: npm run build`
  - Result: PASS

Deployment actions completed after this report was created:

- `npx supabase functions deploy ai-lead-response --use-api`
  - Result: PASS
  - Remote status: ACTIVE, version 1, updated `2026-05-12 08:50:52 UTC`.

- `npx supabase functions deploy complete-onboarding --use-api`
  - Result: PASS
  - Remote status: ACTIVE, version 8, updated `2026-05-12 08:51:43 UTC`.

- `npx supabase config push --yes`
  - Result: PASS
  - Google OAuth config was pushed using local env values loaded from the rotated Google client JSON.
  - Existing hosted Auth settings were restored and then made explicit in `supabase/config.toml`.

- `npx supabase db push --dry-run --linked`
  - Result: PASS
  - The CLI connected to the remote database and reported: remote database is up to date.

- `npx supabase functions list`
  - Result: PASS
  - Remote count: 47 functions listed, 47 ACTIVE.
  - Local count: 47 function directories under `supabase/functions` excluding `_shared`.
  - Core UAT functions are ACTIVE, including `broker-upload-lead`, `initiate-call`, `create-site-visit`, `verify-site-gps`, `broker-review-site-visit`, `assign-role`, `route-incoming-leads`, `complete-onboarding`, and `ai-lead-response`.

- `npx supabase secrets list`
  - Result: PARTIAL
  - `PHONE_ENCRYPTION_KEY` is present remotely.
  - Voice AI and Exotel/PSTN provider secret names were not present in the remote Edge Function secret list at verification time.

- `node scripts/live-test-broker.mjs`
  - Result: PASS after script credential/profile lookup fix and broker account confirmation.
  - Broker sign-in, onboarding, and `brokers_public` profile retrieval succeeded.

- `node scripts/live-test-broker-upload.mjs`
  - Result: PASS
  - Created one live UAT lead through `broker-upload-lead`: `1ec547a9-34dc-476b-84dd-8df5790aeb32`.
  - Verified the public row exists in `leads_public`.
  - Verified sensitive contact data exists only in `leads_sensitive` as ciphertext/hash.
  - Verified broker REST read isolation for the created lead.

- `public.has_strict_enterprise_permission(..., 'can_upload_leads', ...)`
  - Result: PASS for `jitu.broker.uat@sourcing-manager-os.test`.
  - Root cause fixed: `complete-onboarding` now assigns the default permission template into `role_assignments.permission_template_id`.

## What Remains

1. Google OAuth secret rotation
   - Status: COMPLETE for the provided rotated Google client JSON.
   - Local `.env` and `.env.local` now contain `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` and `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET`.
   - Hosted Supabase Auth config was pushed with those env values loaded in-process.

2. Set production and local env vars
   - Google OAuth local env is set.
   - Local `.env` and `.env.local` now include fill-in entries for voice AI, phone encryption, and Exotel/PSTN keys.
   - Remote `PHONE_ENCRYPTION_KEY` is set.
   - Voice AI and Exotel/PSTN env values must still be set as remote Edge Function secrets before live call-provider UAT.
   - Note: Supabase CLI reserves `SUPABASE_*` names for Edge Function secrets, so Google OAuth is handled through Auth config env substitution rather than `supabase secrets set`.

3. Deploy Supabase changes
   - Database dry-run now reports the remote database is up to date.
   - Edge Functions `ai-lead-response` and `complete-onboarding` are deployed.
   - Supabase Auth config push with `env(...)` substitution has been verified.

4. Run live production smoke tests
   - Broker uploads a real test lead. Result: PASS for lead `1ec547a9-34dc-476b-84dd-8df5790aeb32`.
   - Public lead row remains PII-free.
   - Sensitive contact remains encrypted.
   - Caller without data loan is blocked.
   - Caller with active loan queues through provider bridge.
   - AI voice call respects consent/DND and records clean audit state after voice provider secrets are set.
   - Site visit proposal, acceptance, arrival, verification, broker review, 45-day lock, and payout ledger paths work end to end.

5. Decide root TypeScript policy
   - Current root `npx tsc --noEmit` exits successfully.
   - If the team wants root TypeScript to perform meaningful checks, the repo still needs an explicit policy change to add a root TypeScript setup without breaking Deno Edge Function conventions.

## Current Status

Local code, Flutter, security, Sprint 7 static checks, tests, web dashboard checks, Google OAuth rotation, sensitive OAuth JSON cleanup, Supabase Auth config push, database migration status, core Edge Function deployment, broker onboarding, and broker lead-upload UAT are clean. Secure call and AI voice UAT still require remote Exotel/voice provider secrets.
