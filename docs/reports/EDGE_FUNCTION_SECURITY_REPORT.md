# EDGE FUNCTION SECURITY REPORT

Generated: 2026-05-22
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- `complete-onboarding`, `broker-upload-lead`, `lead-from-broker`, `data-loan-workflow`, `manage-caller-workflow`, `initiate-call`, `exotel-callback`, site visit proof functions, AI trust functions, and `super-admin-dashboard`.

## What passed
- Core functions consistently call `currentUser(req)` and reject unauthenticated requests in audited paths.
- Many workflows check `pilot_users` and active organization status before mutation.
- `exotel-callback` requires HMAC signature, timestamp, callback token, replay window, and state transition checks at `supabase/functions/exotel-callback/index.ts:154-213`.
- `initiate-call` clears decrypted destination and bridge body in `finally` at the end of the function.

## What failed
- `initiate-call` has a production-risk mock bypass at `supabase/functions/initiate-call/index.ts:196-203`.
- Provider failure responses return operational credential metadata in diagnostics: `sidLen`, `sidFirstLast`, `apiKeyLen`, `apiKeyFirstLast`, `apiTokenLen`, `apiTokenFirstLast`, `callerId`, and `endpoint` at `supabase/functions/initiate-call/index.ts:216-245`.
- `complete-onboarding` assigns the first active organization globally at `supabase/functions/complete-onboarding/index.ts:54-64`, which is unsafe for a multi-org platform.
- `data-loan-workflow` allows `grant_access` after the broad `leadAccess` helper accepts a linked broker or lead owner at `supabase/functions/data-loan-workflow/index.ts:31-53` and `:80-110`.

## What is dangerous
- Mock provider success can be mistaken for production Exotel readiness.
- Returning credential structure and provider endpoint details to clients increases incident blast radius.
- First-active-org onboarding can silently attach a user to the wrong tenant.

## What is unproven
- Valid provider-signed callback success with real Exotel headers.
- Provider timeout/retry behavior under partial Exotel outage.
- Multi-org onboarding correctness.

## Exact blocker
- `supabase/functions/initiate-call/index.ts:196-203` returns queued without contacting Exotel when `ENABLE_PROVIDER_MOCK=true`.

## Exact recommended fix
- Gate provider mock by project ref/environment and fail if enabled in production/pilot.
- Return only `provider_failed` plus a server-side correlation id to clients; keep diagnostics server-only.
- Replace first-active-org onboarding with invite-bound org resolution.
- Split data-loan permission checks by action so broker-visible lead access does not imply grant authority.

## Harsh-truth verdict
Edge functions are stronger than the frontend API layer, but outbound calling is not production-proven and mock success currently masks the provider boundary.

