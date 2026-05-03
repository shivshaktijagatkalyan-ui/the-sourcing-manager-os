# The Sourcing Manager OS

Open-source trustless real estate data enforcement layer for India.

This is not a CRM, marketplace, lead-sharing tool, or WhatsApp automation system. It is an enforcement layer where the system, not user honesty, controls sensitive lead access.

## Mission

- Brokers own lead data.
- Callers can generate activity without receiving sensitive customer data.
- Sourcing managers execute verified site visits.
- Developers track ROI through audited activity and broker locks.

## Sprint 1 Foundation

Sprint 1 builds the enforcement spine:

- `leads_public` stores only public metadata.
- `leads_sensitive` stores encrypted contact ciphertext only.
- `data_loans` controls time-bound access.
- `initiate-call` validates access and sends server-side Exotel PSTN bridge requests.
- Flutter Web/PWA screens are alias-only except the broker one-time upload form.
- Security scanner blocks unsafe frontend and Edge Function terms.

## Tech Stack

- Frontend: Flutter Web / PWA
- Backend: Supabase Edge Functions
- Database: Supabase PostgreSQL, pgcrypto, RLS, triggers, constraints
- Calling: Exotel India PSTN bridge
- License: AGPLv3

## Local Commands

```powershell
node scripts/security-check.mjs
```

Flutter is required for local PWA builds:

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon>
```

## Supabase Setup

1. Create a Supabase project, preferably India/Mumbai region.
2. Apply `supabase/migrations/20240504000000_sprint1_foundation.sql`.
3. Set Edge Function secrets from `.env.example`.
4. Deploy:

```powershell
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback
```
