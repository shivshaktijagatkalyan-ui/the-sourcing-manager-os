# Antigravity Backend Audit Report

Project: The Sourcing Manager OS  
Scope: Sprint 1/Sprint 2 backend, migrations, Edge Functions, Flutter integration, security gate  
Audit type: Manual Codex audit. CodeRabbit CLI was not installed locally, so this is not a CodeRabbit-generated report.  
Status: Sprint 2 may be deployed, but acceptance should remain blocked until the issues below are resolved and live stress tests pass.

## Executive Summary

The project direction is correct: public lead metadata is separated from encrypted sensitive data, calling is routed through Edge Functions, and Sprint 2 adds a GPS/photo evidence workflow.

However, the current local codebase still contains backend blockers that can break production behavior or allow bypass of the Sprint 2 state machine. The most important issues are:

- Linked database lint reports the contact encryption/decryption RPCs cannot resolve `pgp_sym_encrypt` and `pgp_sym_decrypt`.
- Sprint 2 lock trigger references columns that do not exist in the Sprint 1 schema.
- Sprint 2 Edge Functions use the user/anon Supabase client instead of service-role or locked DB RPC transitions, forcing broad RLS update policies.
- `site_visits` direct `UPDATE` policies allow frontend bypass of the verification state machine.
- Several functions/UI paths reference columns or RPCs that do not exist locally.
- Production-looking test-data migrations insert dummy sensitive rows and hard-coded user references.

Do not unlock pilot users or Sprint 3 until the live acceptance result is:

```text
Geofence Shield: PASS
Evidence Chain: PASS
Lock Trigger: PASS
No phone/name in UI/logs/network/storage: PASS
```

## Critical Findings

### P0: Encryption RPCs fail linked database lint

Evidence:

```powershell
npx supabase db lint --linked --schema public --fail-on error
```

Result:

- `public.encrypt_lead_contact`: `function pgp_sym_encrypt(text, text, unknown) does not exist`
- `public.decrypt_lead_contact_for_edge`: `function pgp_sym_decrypt(bytea, text) does not exist`

Affected file:

- `supabase/migrations/20240504000000_sprint1_foundation.sql`

Likely cause:

Supabase commonly installs extension functions in the `extensions` schema, while the RPCs are created with `SET search_path = public`. The RPCs call `pgp_sym_encrypt` and `pgp_sym_decrypt` without schema qualification.

Fix direction:

- Confirm where `pgcrypto` is installed.
- Prefer schema-qualified calls such as `extensions.pgp_sym_encrypt(...)` and `extensions.pgp_sym_decrypt(...)`, or include `extensions` in the function search path.
- Keep AES-256 pgcrypto behavior and do not expose plaintext values.

### P0: Sprint 2 broker lock trigger references invalid schema

Affected file:

- `supabase/migrations/20240504000100_sprint2_verification.sql`

Problem:

The trigger inserts/updates:

- `broker_locks.lock_type`
- `broker_locks.updated_at`
- `audit_events.metadata`

But Sprint 1 defines:

- `broker_locks.source_site_visit_id`, `starts_at`, `expires_at`, `status`, `created_at`
- `audit_events.event_context`

The trigger also uses `ON CONFLICT (lead_id, broker_id)` even though Sprint 1 created a partial unique index for active locks. That conflict target is not guaranteed to match a full unique constraint.

Impact:

Broker approval can fail exactly when the system should create the 45-day commission lock.

Fix direction:

- Insert into `broker_locks (lead_id, broker_id, source_site_visit_id, starts_at, expires_at, status)`.
- Use `event_context`, not `metadata`.
- Use a conflict strategy compatible with the existing partial unique index, or add an explicit constraint/index design for active locks.
- Add a regression test for approving a verified visit.

### P0: Direct frontend updates can bypass Sprint 2 state machine

Affected file:

- `supabase/migrations/20240504000100_sprint2_verification.sql`

Problem:

Sprint 2 adds broad `UPDATE` policies for `site_visits`:

- managers can update rows where `sourcing_manager_id = auth.uid()`
- brokers can update rows where `broker_id = auth.uid()`

This allows direct client updates to verification-controlled columns, depending on the client and RLS path.

Impact:

A user can potentially bypass Edge Function state transitions and write GPS/photo/review state directly.

Fix direction:

- Remove broad authenticated `UPDATE` policies on `site_visits`.
- Move state changes into service-role Edge Functions or `SECURITY DEFINER` RPCs.
- Make each transition atomic with current-state predicates.
- Keep frontend read-only except for explicit Edge Function calls.

### P0: Sprint 2 Edge Functions are not using the same enforcement pattern as Sprint 1

Affected files:

- `supabase/functions/create-site-visit/index.ts`
- `supabase/functions/start-site-visit/index.ts`
- `supabase/functions/verify-site-gps/index.ts`
- `supabase/functions/upload-site-photo/index.ts`
- `supabase/functions/broker-review-site-visit/index.ts`

Problem:

Sprint 1 sensitive actions authenticate the user, then use service role and manual validation. Sprint 2 functions create Supabase clients with the anon key plus user authorization header.

Impact:

The backend must open RLS write policies to make functions work, which creates a bypass path for the frontend. This conflicts with the system constitution.

Fix direction:

- Authenticate with anon client.
- Perform privileged writes using `SUPABASE_SERVICE_ROLE_KEY`.
- Validate every business rule manually inside Edge Functions or database RPCs.
- Return only safe response codes.

## High-Severity Findings

### P1: `create-site-visit` calls missing RPC and expects wrong return shape

Affected file:

- `supabase/functions/create-site-visit/index.ts`

Problem:

The function calls `check_active_loan`, but Sprint 1 defines `has_active_data_loan(p_lead_id, p_user_id, p_purpose)` returning boolean. The function expects `{ is_active, broker_id }`.

Impact:

Visit creation can fail at runtime. It also does not bind the purpose to `site_visit`.

Fix direction:

- Either implement a safe `check_active_loan` RPC returning `{ is_active, broker_id, loan_id }`, or update the function to use `has_active_data_loan(..., 'site_visit')` and fetch broker ownership safely.
- Fail closed on missing, expired, or revoked loan.

### P1: Missing `site_visits` columns referenced by functions/UI

Affected files:

- `supabase/functions/create-site-visit/index.ts`
- `supabase/functions/start-site-visit/index.ts`
- `supabase/functions/verify-site-gps/index.ts`
- `flutter_app/lib/screens/site_visit_list.dart`
- `flutter_app/lib/screens/broker_review_list.dart`

Problem:

Code references:

- `site_visits.scheduled_at`
- `site_visits.updated_at`

The shown Sprint 1 and Sprint 2 migrations do not define these columns.

Impact:

Flutter lists, sorting, and Edge Function updates can fail.

Fix direction:

- Add `scheduled_at timestamptz` if scheduling is required.
- Add `updated_at timestamptz not null default now()` plus trigger, or stop referencing it.

### P1: `verify-site-gps` has a broken OPTIONS response

Affected file:

- `supabase/functions/verify-site-gps/index.ts`

Problem:

The OPTIONS branch uses `headers`, but only `corsHeaders` is defined.

Impact:

CORS preflight can fail before GPS verification starts.

Fix direction:

- Replace `headers` with `corsHeaders`.

### P1: GPS transition is still race-prone

Affected file:

- `supabase/functions/verify-site-gps/index.ts`

Problem:

The function fetches the visit, validates state, then updates by `id`. A stale request can overwrite a changed row.

Fix direction:

- Update with predicates: `id`, `sourcing_manager_id`, current status, non-revoked loan, and expected project.
- Better: use a `SECURITY DEFINER` DB RPC with row lock and explicit transition rules.

### P1: Production migrations include test/seed data

Affected files:

- `supabase/migrations/20240504999999_final_test_data.sql`
- `supabase/migrations/20240505000000_verify_data.sql`

Problem:

These migrations insert fixed projects, leads, sensitive rows, and site visits. They include dummy sensitive ciphertext and hard-coded user references.

Impact:

Production migrations should not create fake business records. Hard-coded auth user references can fail FK checks or pollute live data.

Fix direction:

- Move test data to local-only seed files, not production migrations.
- Never insert dummy contact ciphertext into `leads_sensitive` in production.
- If a test lead is needed, create it through `broker-upload-lead` so pgcrypto encryption is actually exercised.

## Medium-Severity Findings

### P2: Security scanner does not cover migrations or schema drift

Affected files:

- `scripts/security-check.py`
- `scripts/security-check.mjs`

Problem:

The scanners only inspect `flutter_app/lib` and `supabase/functions`. They do not scan migrations, docs, storage path builders, schema references, or dangerous RLS patterns.

Fix direction:

- Add migration scanning for forbidden sensitive terms and schema-smell patterns.
- Add checks for `metadata` vs `event_context`, `lock_type`, broad `FOR UPDATE TO authenticated`, `error.message`, and direct client update policies.

### P2: Photo evidence is not immutable enough

Affected file:

- `supabase/functions/upload-site-photo/index.ts`

Problem:

The storage upload uses `upsert: true`, and the file is uploaded before the DB transition is confirmed.

Impact:

Evidence files can be overwritten or orphaned if the DB update fails.

Fix direction:

- Use `upsert: false`.
- If DB update fails after upload, delete the uploaded object or move upload/update into a transactional backend design where possible.

### P2: Browser GPS is not a complete anti-spoof guarantee

Affected file:

- `supabase/functions/verify-site-gps/index.ts`

Problem:

The server validates submitted latitude/longitude/accuracy, but the values still originate from the client.

Fix direction:

- For pilot, document this as a limitation.
- Later, add anti-spoof checks: timestamp freshness, impossible travel detection, repeated coordinate pattern checks, device attestation where available, and photo/GPS correlation.

## Verification Commands Run

```powershell
npm run security
```

Result: Passed.

```powershell
npx supabase --version
```

Result: `2.98.0`.

```powershell
npx supabase functions list
```

Result: all 8 functions are active in the linked Supabase project.

```powershell
npx supabase migration list
```

Result: Sprint 1, Sprint 2, and `20240504999999` are applied remotely. `20240505000000` is local-only/pending.

```powershell
npx supabase db lint --linked --schema public --fail-on error
```

Result: Failed on unresolved pgcrypto functions in encryption/decryption RPCs.

```powershell
npm run build
```

Result: Failed because `package.json` has no `build` script.

```powershell
npx tsc --noEmit
```

Result: Failed because TypeScript is not installed/configured in the root project.

```powershell
flutter --version
```

Result: Failed in this local agent environment because `flutter` is not in PATH.

## Recommended Fix Order

1. Fix pgcrypto RPC resolution on linked database.
2. Remove production test-data migrations or make them local-only.
3. Fix Sprint 2 schema mismatch: lock trigger, `event_context`, `scheduled_at`, `updated_at`.
4. Replace broad `site_visits` update RLS with service-role Edge Function transitions or `SECURITY DEFINER` RPCs.
5. Fix missing `check_active_loan` contract or replace usage with a purpose-bound loan RPC.
6. Fix `verify-site-gps` CORS header reference and atomic transition predicates.
7. Harden photo upload immutability and orphan cleanup.
8. Expand security scanner to include migrations and backend policy smells.
9. Re-run linked DB lint and live Sprint 2 stress tests.

## Acceptance Gate Remains

Do not authorize pilot users until the live result is:

```text
Geofence Shield: PASS
Evidence Chain: PASS
Lock Trigger: PASS
No phone/name in UI/logs/network/storage: PASS
```
