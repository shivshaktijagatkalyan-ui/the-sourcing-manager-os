# Sprint 1: Masked Dialer + Encryption + Basic UI

## Status: IN PROGRESS
**Goal**: Establish the "Enforcement Spine".

## Deliverables
- [x] **Database Schema**: leads_public, leads_sensitive, data_loans, audit_events.
- [x] **RLS Hardening**: Default deny, Broker-only lead access, Loan-based caller access.
- [x] **pgcrypto Encryption**: RPC functions for symmetric AES-256.
- [x] **Edge Function: broker-upload-lead**: Secure lead entry with instant encryption.
- [x] **Edge Function: initiate-call**: Just-in-time decryption + Exotel PSTN bridge.
- [x] **Edge Function: exotel-callback**: Sanitized call status tracking.
- [x] **Flutter UI**: Lead Queue (alias-only) and Secure Upload.
- [x] **Security Guardrails**: Script to block forbidden terms (masked_phone, tel:, etc.)

## Setup Instructions

### 1. Supabase Setup
1. Create a new Supabase project (India/Mumbai region preferred).
2. Run the migration in `supabase/migrations/20240504000000_sprint1_foundation.sql`.
3. Set the following secrets in Supabase Dashboard (Settings > API > Edge Functions):
   - `PHONE_ENCRYPTION_KEY`: A secure 32+ char string.
   - `EXOTEL_SID`, `EXOTEL_API_KEY`, `EXOTEL_API_TOKEN`, `EXOTEL_CALLER_ID`.

### 2. Deploy Edge Functions
```bash
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback
```

### 3. Flutter App
1. Navigate to `flutter_app`.
2. Run `flutter pub get`.
3. Update `lib/main.dart` with your Supabase URL and Anon Key.
4. Run `flutter run -d chrome`.

### 4. Security Scan
Run this before every commit:
```bash
python scripts/security-check.py
```
