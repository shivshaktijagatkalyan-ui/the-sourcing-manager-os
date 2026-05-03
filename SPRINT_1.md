# Sprint 1: Enforcement Spine

## Goal

Build the minimum production foundation for encrypted lead storage, time-bound data loans, secure PSTN calling, and alias-only Flutter screens.

## Implemented

- `leads_public`
- `leads_sensitive`
- `data_loans`
- `call_attempts`
- `audit_events`
- `site_visits`
- `broker_locks`
- RLS enabled and forced on every table
- No frontend `SELECT` policy on `leads_sensitive`
- Append-only audit trigger
- `updated_at` triggers
- 45-day broker lock trigger skeleton
- pgcrypto encryption/decryption RPCs revoked from frontend roles
- Active data-loan helper
- `broker-upload-lead`
- `initiate-call`
- `exotel-callback`
- Flutter lead queue, broker upload, and call status UI
- Node security scanner and GitHub workflow

## Required Abuse Tests

1. Caller without active loan presses call: expect `access_denied`.
2. Caller with expired loan presses call: expect `loan_expired`.
3. Broker revokes loan and caller refreshes UI: lead disappears or loses active badge.
4. Broker revokes loan after UI loaded and caller presses call: Edge Function returns `revoked`.
5. DND blocked lead: expect `dnd_blocked`.
6. Consent not granted: expect `consent_required`.
7. Frontend DevTools network inspection: call request contains only `lead_id`.
8. App logs: no sensitive values and no raw provider payloads.
9. Database search: no plaintext sensitive contact values in tables.
10. Authenticated select from `leads_sensitive`: blocked by RLS/no policy.

## Setup

```powershell
node scripts/security-check.mjs
```

```powershell
supabase db push
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback
```

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon>
```

## Manual Setup Required

- Supabase project in India/Mumbai region if available.
- Edge Function secrets from `.env.example`.
- Exotel account, approved caller id, and callback URL.
- Real authenticated users and data-loan seed rows for manual abuse testing.
