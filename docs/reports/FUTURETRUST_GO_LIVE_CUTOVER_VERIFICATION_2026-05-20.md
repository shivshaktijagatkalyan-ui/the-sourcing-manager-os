# FutureTrust Go-Live Cutover Verification - 2026-05-20

## Scope

This pass implemented the completion prompt from:

`C:\Users\iBUGG3D\.gemini\antigravity\brain\d78dd930-2228-47ac-b588-d9872df6b51b\codex_completion_prompt.md`

The work focused on final technical hardening blocks:

- Exotel callback signature validation and replay protection.
- Supabase Vault secret-separation migration.
- Offline-first site visit proof queue with encrypted local payloads.
- Photo compression before live upload or offline queue serialization.
- Delayed offline sync database fallback for Super Admin review.

## Implemented

### Exotel Callback Hardening

File:

- `supabase/functions/exotel-callback/index.ts`

Changes:

- Requires `EXOTEL_HMAC_TOKEN`.
- Requires Exotel signature header: `x-exotel-signature` or `x-exotel-signature-sha256`.
- Requires timestamp header: `x-exotel-timestamp` or `x-exotel-request-timestamp`.
- Enforces a 120-second replay window.
- Verifies SHA-256 HMAC signatures using timing-safe comparisons.
- Keeps the existing callback-token check as an additional defense when `EXOTEL_CALLBACK_SECRET` is configured.
- Parses safe call telemetry from signed callback payloads.
- Updates `call_attempts` with provider call ID, status, duration, callback hash, and callback timestamp.
- Expires the linked active `data_loans` row when the provider callback is terminal.
- Writes audit events for received, rejected, invalid-transition, and replayed callbacks.

### Vault Secret Separation

File:

- `supabase/migrations/20260520000200_production_vault_secrets.sql`

Changes:

- Enables Supabase Vault extension.
- Adds `production_secret_registry`.
- Adds service-role-only `register_production_vault_secret(...)`.
- Adds service-role-only `get_production_vault_secret(...)`.
- Revokes client access from secret registry and helper functions.

### Offline Site Visit Sync Fallback

Files:

- `supabase/migrations/20260520000200_production_vault_secrets.sql`
- `supabase/functions/verify-site-gps/index.ts`

Changes:

- Adds offline sync metadata columns to `site_visits`.
- Adds `delayed_sync` site visit status.
- Adds `apply_offline_site_visit_sync(...)`.
- Syncs valid offline GPS proof when inside the visit window.
- Holds late syncs as `held_for_admin_review` with `delayed_sync_review_required = true`.

### Flutter Offline Queue And Compression

Files:

- `flutter_app/lib/services/sync_service.dart`
- `flutter_app/lib/screens/site_visit_verify.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/pubspec.yaml`
- `flutter_app/pubspec.lock`

Changes:

- Adds Hive-backed offline check-in queue.
- Encrypts queued payloads locally using AES-GCM.
- Stores GPS coordinates and photo payload in encrypted queue records.
- Compresses visit photos to 800x600 JPEG at 75% quality.
- Starts a background sync worker after Supabase initialization.
- On photo upload failure, queues the site visit proof for sync when connectivity returns.

### Test Fix

File:

- `flutter_app/test/broker_vault_constitution_test.dart`

Change:

- Corrected the broker dashboard contract path to `../docs/architecture/broker-dashboard-data-contract.md`.

## Verification Results

| Gate | Result |
|---|---|
| `npm run security` | PASS |
| `npx tsc --noEmit` | PASS |
| `flutter analyze` | PASS |
| `flutter test` | PASS |
| `flutter build web --release` | PASS |
| `flutter build apk --release` | PASS |
| root `npm run build` | PASS |
| `git diff --check` on touched files | PASS |

## Build Outputs

- Flutter Web: `flutter_app/build/web`
- Android APK: `flutter_app/build/app/outputs/flutter-apk/app-release.apk`

## Known Local Limitation

Deno is not installed on this workstation, so Supabase Edge Function typechecking was not run with `deno check`. The relevant repository gates and runtime builds passed, but CI or a Supabase CLI/Deno-enabled environment should still run Edge Function checks before deploying these functions.

## Production Notes

- Set `EXOTEL_HMAC_TOKEN` before enabling the hardened callback in production.
- Keep `EXOTEL_CALLBACK_SECRET` configured if existing callback URLs include `callback_token`.
- Register production secrets through `register_production_vault_secret(...)` instead of storing raw provider tokens in client-visible config.
- Set `OFFLINE_QUEUE_KEY` as a release build define for stronger local queue encryption.
- Delayed offline visit syncs intentionally fail closed into Super Admin review instead of auto-verifying broker locks.
