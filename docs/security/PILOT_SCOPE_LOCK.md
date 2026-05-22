# PILOT SCOPE LOCK

Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Mode: Infrastructure verification only
Verdict rule: No Verdict A unless real provider trust execution passes

## Purpose

This file locks the controlled pilot scope.

FutureTrust is not in feature expansion mode. It is in trust-loop proof mode.

The current blocker is not UI, AI, analytics, or product polish. The blocker is real provider trust execution:

```text
Caller
-> secure call request
-> encrypted contact access
-> provider handoff
-> real callback
-> signed verification
-> outcome persistence
-> audit trail
-> workflow continuation
```

Until this works with no PII exposure, the project remains:

B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN

## Allowed Work

Only the following work is allowed for the controlled trust-loop pilot:

- secure onboarding verification,
- broker isolation verification,
- secure call preflight,
- Exotel provider handoff,
- signed provider callback verification,
- callback replay rejection,
- invalid callback transition rejection,
- call outcome persistence,
- PII-safe audit integrity,
- site visit proof,
- GPS and photo proof validation,
- broker lock creation,
- second-broker isolation UAT,
- release gate execution.

## Frozen Work

The following work is frozen until the provider-backed trust loop is proven:

- AI calling,
- AI churn engine,
- RAG,
- copilots,
- dashboard redesign,
- new analytics,
- payout expansion,
- automation campaigns,
- developer ROI expansion,
- content engine expansion,
- WhatsApp automation,
- contact export,
- masked contact display,
- `tel:` shortcuts.

## Explicitly Out Of Pilot Scope

The migration below is not part of the controlled trust-loop pilot:

```text
supabase/migrations/20260516000100_ai_data_churn_engine.sql
```

It must not be pushed with the pilot release unless separately approved after threat modeling.

## Required Proof For Verdict A

Verdict A is allowed only if all of the following are true:

1. Real secure call works.
2. Real provider handoff works.
3. Real provider callback is accepted only when signed correctly.
4. Forged callback is rejected.
5. Replay callback is rejected.
6. Invalid state transition is rejected.
7. Valid callback persists outcome.
8. Audit trail remains PII-safe.
9. Broker A cannot see Broker B data.
10. Site visit proof passes.
11. Broker lock is auto-created.
12. Release gate exits 0.
13. No phone number, masked phone, last four digits, WhatsApp link, `tel:` link, or contact export appears anywhere in frontend output.

## Non-Negotiable Rules

- No service-role consent shortcuts in release UAT.
- No manual DB mutation to manufacture trust-loop success.
- No AI access to raw identity.
- No frontend access to sensitive tables.
- No raw provider payload in audit events.
- No production-readiness claim while release gate exits nonzero.

## Next Execution Order

1. Configure real provider secrets.
2. Create a consent-valid UAT lead through approved workflow.
3. Prove Exotel handoff.
4. Prove signed callback acceptance.
5. Prove fake/replay/invalid-transition callback rejection.
6. Prove second-broker isolation.
7. Rerun the full release gate.

## Final Instruction

Build less.

Verify the provider trust loop.

Do not expand scope until the callback path is real.
