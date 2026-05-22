# DB ISOLATION VERIFICATION REPORT

Date: 2026-05-12

## Result

PARTIAL PASS.

The production database has the latest isolation migration state, including `20260510000300_broker_isolation_fix.sql`, plus the new hardening migrations applied in this pass:

- `20260512000100_harden_exotel_callback_replay.sql`
- `20260512000200_harden_trust_loop_isolation_policies.sql`

`npx supabase db push --dry-run --linked` reports the remote database is up to date.

## Verified

- `call_attempts` now has callback replay/audit support columns:
  - `callback_event_hash`
  - `callback_received_at`
  - `callback_failure_reason`
- `leads_public_assigned_sourcing_manager_read` policy exists.
- `broker_locks_assigned_sourcing_manager_read` policy exists.
- Local function directories now match `supabase/config.toml`: 47 configured functions.
- Broker UAT account can upload a lead without receiving contact data back.
- Broker anon client cannot read `leads_sensitive`.
- Duplicate upload attempt is blocked.
- Assigned sourcing manager can read the uploaded public lead metadata.
- Broker audit trail read returned PII-safe events.

## Still Not Fully Proven

- Broker A versus Broker B cross-read denial was not live-tested because only one broker test account was available in this UAT.
- Broker lock RLS was policy-verified but not live-tested because the trust loop stopped before site visit proof and lock creation.
- Caller-side RLS was not tested because the configured caller test credentials are invalid.

## Hard Truth

Isolation architecture is materially stronger after this pass, but this is not a full isolation proof until a second broker and a valid caller test identity are available.
