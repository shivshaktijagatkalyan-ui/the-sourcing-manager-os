# BROKER LOCK AUDIT

Generated: 2026-05-22
Verdict: B. PARTIAL - BLOCKERS REMAIN

## What was tested
- Broker lock creation after visit proof, lock conflict handling, lock visibility migrations, expiry routines, and broker identity linkage.

## What passed
- Release-gate UAT created or extended a broker lock after `visit_done`.
- `verify-site-visit-proof` blocks active lock conflicts at `supabase/functions/verify-site-visit-proof/index.ts:261-285`.
- Scheduled expiry infrastructure exists in `supabase/migrations/20260519000100_scheduled_trust_infrastructure.sql:149-220`.

## What failed
- Broker lock creation depends on the flaky photo proof gate.
- Broker identity semantics are inconsistent. `leads_public.broker_id` is defined as `auth.users(id)` in `supabase/migrations/20240504000000_sprint1_foundation.sql:18`, but `broker-upload-lead` inserts `brokerProfile.id` into both `broker_id` and `source_broker_id` at `supabase/functions/broker-upload-lead/index.ts:142-143`.
- Older and newer broker linkage models conflict: `linked_user_id` is used in `complete-onboarding`, `propose-site-visit`, and `trust-get-broker-lock-status`, while `owner_user_id` is used by newer RLS fixes and broker upload.

## What is dangerous
- Wrong broker identifier can break RLS, attribution, lock visibility, payout eligibility, or foreign-key assumptions.
- A lock can be operationally invisible if identity columns do not align with the policy in force.

## What is unproven
- Admin-created lock visibility across all roles.
- Expired lock cleanup in the actual remote project, because migration drift is unresolved.
- Payout eligibility linkage after migration drift is corrected.

## Exact blocker
- Identity mismatch: `supabase/functions/broker-upload-lead/index.ts:142-143` versus `supabase/migrations/20240504000000_sprint1_foundation.sql:18` and comments in `supabase/migrations/20260510000300_broker_isolation_fix.sql:63-66`.

## Exact recommended fix
- Standardize broker identity: keep `broker_id` as auth user id or migrate it to broker profile id, but do not mix both.
- Backfill and enforce constraints for `source_broker_id`, `owner_user_id`, and `linked_user_id`.
- Add regression tests for broker lock read visibility by broker, SM, and platform admin.

## Harsh-truth verdict
Broker locks work in the happy-path UAT run, but identity drift and proof flakiness make payout-grade trust unproven.

