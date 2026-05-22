# TRUST LOOP UAT REPORT

Generated: 2026-05-22
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- Lead upload -> encryption -> duplicate check -> broker attribution -> caller assignment -> data loan -> secure call -> provider callback rejection -> call outcome -> follow-up -> site visit -> GPS -> photo proof -> broker lock -> final lead state.

## What passed
- Broker sign-in, onboarding, lead upload, AI metadata tools, sensitive table denial, duplicate prevention, SM visibility, caller assignment, data loan creation, secure-call invocation, forged callback rejection, call outcome, site visit creation, wrong GPS rejection, valid GPS, and audit trail review passed in the latest release-gate UAT run.
- AI tool outputs were PII-safe in sampled checks.

## What failed
- A standalone `node scripts/uat-trust-loop.mjs` run failed at photo proof with `{"ok":false,"reason":"invalid_proof_path"}`.
- The failure comes from `scripts/uat-trust-loop.mjs:369` placing a generated UUID in `photo_storage_path`, while `supabase/functions/verify-site-visit-proof/index.ts:28` scans the entire path for phone-like tokens and rejects at `:233-234`.
- The later release-gate UAT run passed only because the generated UUID/path did not hit the phone regex. That makes the test flaky.

## What is dangerous
- A verified visit can be blocked by a random UUID segment that resembles an Indian phone number.
- Broker lock creation depends on photo proof. A flaky photo proof gate can deny brokerage eligibility.
- The secure call UAT pass is not real provider proof because `ENABLE_PROVIDER_MOCK=true` bypasses Exotel in `supabase/functions/initiate-call/index.ts:196-203`.

## What is unproven
- Real Exotel outbound call handoff.
- Valid signed callback success from Exotel.
- Deterministic photo proof acceptance.
- Production remote schema alignment because release gate failed migration dry run.

## Exact blocker
- Flaky proof path validation: `supabase/functions/verify-site-visit-proof/index.ts:28`, `:233-234`, and UAT path construction at `scripts/uat-trust-loop.mjs:369`.
- Provider mock bypass: `.env:38`, `provider.env:11`, and `supabase/functions/initiate-call/index.ts:196`.

## Exact recommended fix
- Validate storage paths structurally instead of scanning full paths for phone-looking substrings.
- Verify the uploaded storage object exists in the private evidence bucket before accepting photo proof.
- Run UAT once with `ENABLE_PROVIDER_MOCK=false` against real Exotel credentials and a valid signed callback fixture.

## Harsh-truth verdict
The mocked internal trust loop can pass, but the production trust loop is blocked by provider mock dependence, release-gate migration drift, and flaky photo proof validation.

