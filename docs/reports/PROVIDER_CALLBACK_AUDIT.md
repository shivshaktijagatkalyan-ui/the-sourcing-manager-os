# PROVIDER CALLBACK AUDIT

Generated: 2026-05-22
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- Outbound call setup, callback token generation, Exotel callback auth, replay protection, and UAT callback behavior.

## What passed
- Forged callback rejection passed in UAT.
- `exotel-callback` requires signature, timestamp, replay window, callback token, and valid state transition at `supabase/functions/exotel-callback/index.ts:154-213`.
- Replay-hash storage exists in `supabase/migrations/20260512000100_harden_exotel_callback_replay.sql:1-11`.

## What failed
- Outbound call success is mocked when `ENABLE_PROVIDER_MOCK=true`; `supabase/functions/initiate-call/index.ts:196-203` returns queued without Exotel.
- Real Exotel callback success was not proven. UAT only proves a bad token is rejected at `scripts/uat-trust-loop.mjs:246-250`.
- Provider failure diagnostics expose credential shape and endpoint metadata at `supabase/functions/initiate-call/index.ts:216-245`.

## What is dangerous
- A mocked provider queue event can create false production confidence.
- Diagnostic metadata returned to frontend can assist credential guessing or provider mapping.
- Callback verification exists, but no positive signed-provider fixture proves the accepted path.

## What is unproven
- Real Exotel authentication.
- Real provider call connection.
- Real callback payload mapping to `completed`, `failed`, or other call states.
- Idempotent handling of duplicate real callbacks beyond one stored event hash.

## Exact blocker
- Provider handoff is bypassed at `supabase/functions/initiate-call/index.ts:196-203`.

## Exact recommended fix
- Disable provider mock for controlled pilot.
- Add a signed callback integration test with valid `x-exotel-signature`, timestamp, callback token, replay attempt, and state transition assertions.
- Replace client-returned diagnostics with a server-side incident id.

## Harsh-truth verdict
Callback rejection is strong, but provider success is not proven. This blocks pilot readiness.

