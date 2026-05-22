# WORKFLOW STATE MACHINE AUDIT

Generated: 2026-05-22
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- Lead lifecycle, trust state, sales state, call outcome, data loan expiry, site visit state, photo proof state, and broker lock transition behavior.

## What passed
- UAT exercised new lead, assignment, data loan, call outcome, site visit scheduling, GPS verification, photo upload, visit done, and final lead state in the release-gate run.
- Site visit proof state ordering exists in `supabase/functions/verify-site-visit-proof/index.ts:14-21`.

## What failed
- `rpc_update_call_outcome` allows outcome update when `assigned_caller_id = auth.uid()` even without an active data loan at `supabase/migrations/20240516000310_sprint8_rpc_callback_sync.sql:25`.
- The same RPC accepts arbitrary `p_outcome`; unknown outcomes fall through to `loan_active` at `supabase/migrations/20240516000310_sprint8_rpc_callback_sync.sql:35-46`.
- `manage-caller-workflow` passes raw request `outcome` into the RPC at `supabase/functions/manage-caller-workflow/index.ts:74`.
- Photo proof can fail nondeterministically before `visit_done`, blocking the state machine.

## What is dangerous
- Expired assigned callers may still mutate call outcome if assignment is stale.
- Unknown outcomes can keep the lead in an active loan state instead of failing closed.
- State machines are split across Edge Functions and SQL without one canonical transition table.

## What is unproven
- Race handling for simultaneous caller outcome updates.
- Stale follow-up cancellation on inbound reply.
- Atomicity between provider callback status and caller-entered outcome.

## Exact blocker
- Stale assignment/data-loan bypass: `supabase/migrations/20240516000310_sprint8_rpc_callback_sync.sql:25`.
- Unknown outcome fallback: `supabase/migrations/20240516000310_sprint8_rpc_callback_sync.sql:35-46`.

## Exact recommended fix
- Require active data loan for caller outcome updates, not assignment alone.
- Enumerate allowed outcomes in SQL and reject unknown values.
- Centralize state transitions in guarded RPCs and have Edge Functions call those RPCs only.

## Harsh-truth verdict
The lifecycle works in one scripted happy path, but the state machine still has unsafe fallback behavior and stale-assignment risk.

