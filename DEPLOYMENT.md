# Deployment Guide - The Sourcing Manager OS

Follow these steps to deploy **Sprint 1 (v0.1.0)** to production.

## 1. Supabase Project Setup
1. Create a new Supabase project in the **India (Mumbai)** region.
2. Install Supabase CLI: `npm install supabase --save-dev`
3. Login: `npx supabase login`
4. Link project: `npx supabase link --project-ref your-project-ref`

## 2. Database Migration
Apply the Sprint 1 schema and RLS policies:
```bash
npx supabase db push
```
*Note: This will execute `supabase/migrations/20240504000000_sprint1_foundation.sql`.*

## 3. Environment Secrets
Set the required secrets for Edge Functions via the Supabase Dashboard or CLI:

```bash
npx supabase secrets set PHONE_ENCRYPTION_KEY="your-secure-key"
npx supabase secrets set EXOTEL_SID="your-sid"
npx supabase secrets set EXOTEL_API_KEY="your-key"
npx supabase secrets set EXOTEL_API_TOKEN="your-token"
npx supabase secrets set EXOTEL_CALLER_ID="your-verified-id"
```

## 4. Edge Function Deployment
Deploy the enforcement logic:
```bash
npx supabase functions deploy broker-upload-lead
npx supabase functions deploy initiate-call
npx supabase functions deploy exotel-callback
```

## 5. Flutter Web Deployment
1. Navigate to `flutter_app`.
2. Update `lib/main.dart` with your production `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
3. Build for web:
   ```bash
   flutter build web --release
   ```
4. Deploy the contents of `build/web` to your hosting provider (Vercel, Netlify, or Firebase Hosting).

## 6. Exotel Callback URL
In your Exotel Dashboard, ensure your callback URL for the virtual number is set to:
`https://your-project.supabase.co/functions/v1/exotel-callback`

## 7. Live Smoke Test Checklist
- [ ] **Upload**: Broker uploads a lead; check that only `lead_id` and `alias` are returned.
- [ ] **DB Check**: Verify `phone_ciphertext` exists in `leads_sensitive`. Ensure `leads_public` has NO phone column.
- [ ] **Unauthorized Call**: Attempt to call a lead without an active `data_loan`. Expected: `access_denied`.
- [ ] **Bridge Call**: Call a lead with an active loan. Verify Exotel bridges the call and status updates in `call_attempts`.
- [ ] **RLS Bypass Check**: Try to SELECT from `leads_sensitive` as an authenticated user. Expected: 0 rows (Default Deny).
