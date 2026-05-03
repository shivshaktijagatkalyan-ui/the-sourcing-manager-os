# Deployment Guide - The Sourcing Manager OS

Sprint 1 deployment is blocked until the Windows setup, deployment gate, and live smoke tests all pass with real command output. Do not start Sprint 2 from this state.

## 0. Windows Setup First

Before deployment, complete [WINDOWS_SETUP.md](./WINDOWS_SETUP.md). The required local tools are:

- Python 3 via `python` or `py -3`
- Supabase CLI via `supabase`
- Flutter SDK via `flutter`
- Git via `git`

Run the deployment gate from the project root:

```powershell
cd "C:\Users\iBUGG3D\Desktop\The Sourcing MAnager OS"
./scripts/production-deploy.ps1
```

If the gate reports a missing tool, deployment stops safely. Do not bypass the gate, do not fake smoke-test results, and do not mark Sprint 1 deployed.

## 1. Supabase Project Setup

1. Create a Supabase project in the India/Mumbai region where available.
2. Login:

```powershell
supabase login
```

3. Link the project:

```powershell
supabase link --project-ref your-project-ref
```

## 2. Environment Secrets

Set secrets through Supabase Dashboard or CLI. Do not commit or print secret values.

```powershell
supabase secrets set PHONE_ENCRYPTION_KEY="your-secure-key"
supabase secrets set EXOTEL_SID="your-sid"
supabase secrets set EXOTEL_API_KEY="your-key"
supabase secrets set EXOTEL_API_TOKEN="your-token"
supabase secrets set EXOTEL_CALLER_ID="your-verified-id"
supabase secrets set EXOTEL_SUBDOMAIN="api.in.exotel.com"
```

## 3. Commands Run By The Gate

The production gate runs these commands only after all required tools are found:

```powershell
python scripts/security-check.py
supabase db push
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback
cd flutter_app
flutter pub get
flutter analyze
flutter build web --release
```

If the Windows Python launcher is used, the scanner command is:

```powershell
py -3 scripts/security-check.py
```

## 4. Exotel Callback URL

In the Exotel dashboard, set the callback URL to:

```text
https://your-project.supabase.co/functions/v1/exotel-callback
```

Do not call Exotel from the frontend. The browser may send only `lead_id` to `initiate-call`.

## 5. Live Smoke Test Checklist

Record actual results in [LIVE_SMOKE_TEST_RESULTS.md](./LIVE_SMOKE_TEST_RESULTS.md) only after deployment succeeds.

- [ ] Broker uploads a lead; response contains only `lead_id` and `alias`.
- [ ] `leads_public` contains metadata only.
- [ ] `leads_sensitive` contains ciphertext only.
- [ ] No plaintext contact data appears in database search, logs, UI, network payloads, screenshots, or exports.
- [ ] Caller without active data loan receives `access_denied`.
- [ ] Expired or revoked loan blocks call at Edge Function time.
- [ ] DND blocked lead returns `dnd_blocked`.
- [ ] Missing consent returns `consent_required`.
- [ ] Exotel bridge call queues through server-side PSTN only.
- [ ] Authenticated frontend user cannot select from `leads_sensitive`.
