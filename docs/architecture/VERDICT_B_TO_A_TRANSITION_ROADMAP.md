# VERDICT B TO A TRANSITION ROADMAP

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Current verdict: B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN

## Executive Summary

FutureTrust is close to Verdict A, but it is not there yet.

The latest strict release-gate UAT proves the internal trust state machine much further than before:

- broker lead upload,
- caller assignment,
- data loan creation,
- secure call fail-closed behavior,
- forged callback rejection,
- site visit scheduling,
- bad GPS rejection,
- valid GPS verification,
- photo proof,
- broker lock creation,
- final lead state update,
- PII-safe audit trail.

The remaining blocker is live provider completeness: Exotel provider handoff and valid provider callback are not proven. Simulated signed callbacks are not accepted as release evidence. The release gate still exits 1, so the official verdict remains B.

## Current Evidence

Fresh release gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\release-gate.ps1
```

Result:

```text
FAIL - controlled pilot release gate did not pass.
```

Reason:

- `provider config` is blocked.
- `provider call section` is blocked.

## Proven Internal Trust Loop

| Workflow Section | Status | Meaning |
| --- | --- | --- |
| Broker sign-in | PASS | Broker identity works with anon client. |
| Broker onboarding | PASS | Server-governed onboarding works. |
| Broker lead upload | PASS | Lead created without contact exposure. |
| Sensitive table isolation | PASS | Broker frontend cannot read sensitive contact store. |
| Duplicate prevention | PASS | Repeat contact blocked without contact exposure. |
| Sourcing manager sign-in | PASS | SM identity works. |
| Caller sign-in | PASS | Caller identity works. |
| Caller assignment/data loan | PASS | Temporary call access can be granted. |
| Secure call pre-provider gate | PASS | Consent/DND block fails closed. |
| Fake callback rejection | PASS | Forged callback cannot mark call successful. |
| Call outcome/follow-up | PASS | Outcome update accepted without contact exposure. |
| Site visit scheduling | PASS | Visit created through Edge Function. |
| Wrong GPS rejection | PASS | Bad GPS fails closed. |
| Valid GPS verification | PASS | Correct coordinates verify. |
| Photo proof | PASS | Photo metadata accepted without contact data. |
| Broker lock creation | PASS | Completed visit creates/extends lock. |
| Final lead state | PASS | Lead status and brokerage status update. |
| Audit trail review | PASS | Audit response remains PII-safe. |

## Remaining Verdict A Requirements

Verdict A requires all of these:

| Requirement | Current State | Required Proof |
| --- | --- | --- |
| Exotel secrets configured | Incomplete locally. `EXOTEL_CALLBACK_SECRET` is missing from `.env`. | Provider config row PASS in UAT. |
| Consent/DND path permits one call | Current call stops at `consent_required`. | UAT must reach provider handoff. |
| Provider handoff | BLOCKED. | `initiate-call` returns queued or provider outcome without contact exposure. |
| Valid callback verification | Not proven with real provider attempt. | Signed callback updates a real attempt through allowed transition. |
| Release gate | FAIL. | `scripts/release-gate.ps1` exits 0. |

## Required Operator Actions

1. Set missing local and remote provider secrets:

```text
EXOTEL_SID
EXOTEL_API_KEY
EXOTEL_API_TOKEN
EXOTEL_SUBDOMAIN
EXOTEL_CALLER_ID
EXOTEL_CALLBACK_SECRET
```

2. Set `CALLER_INVITE_CODE` for live caller onboarding.

3. Ensure the UAT lead has call consent granted and DND clear before the provider call step, using only approved backend workflow or a safe UAT fixture.

4. Deploy any local Edge Function changes before claiming the remote environment is fixed.

5. Re-run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\release-gate.ps1
```

6. Promote to Verdict A only if the release gate exits 0.

## Data Loan Hardening Note

The local `data-loan-workflow` function has been corrected so:

- `purpose` is allowlisted to `call` or `site_visit`,
- invalid purpose fails closed,
- `site_visit` loans do not overwrite `assigned_caller_id`,
- call loans remain the only loan type that sets `conversion_stage = assigned_to_caller`,
- audit context includes loan purpose.

This is important because the UAT site-visit self-loan must not corrupt caller assignment semantics.

## UAT Bypass Removal

The release-gate UAT must not:

- write `consent_status = granted` directly through a service-role admin client,
- write `dnd_status = clear` directly through a service-role admin client,
- manually force `call_attempts.call_status = queued`,
- accept `UAT_CALLBACK_SECRET` inside the production callback Edge Function.

Those shortcuts can be useful in a separate unit/simulation proof. They are not valid release evidence for field pilot readiness.

## Final Rule

Do not mark Verdict A while release gate exits nonzero.

Current verdict remains:

B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN
