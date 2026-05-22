# AI COPILOT PRODUCT SPEC

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Status: DESIGN ONLY - DO NOT OVER-AUTOMATE

## Product Position

The copilots are not a chatbot layer. They are workflow assistants that call approved metadata tools, explain operational risk, and help humans complete protected work.

AI must never become a source of trust. Trust comes from verified workflow events: upload, assignment, secure call, follow-up, site proof, broker lock, payout eligibility, and audit trail.

## Shared Rules

All copilots must follow these rules:

- Use approved Edge Function tools only.
- Never query raw tables.
- Never request or reveal contact data.
- Never suggest off-platform outreach.
- Never approve a broker lock or payout.
- Never override RLS, role checks, or audit requirements.
- Never fabricate pricing, policy, RERA, or payout facts.
- Require human confirmation before any state-changing action.
- Create a PII-safe audit event for every AI-assisted protected action.

Model settings:

| Workflow | Temperature | Reason |
| --- | ---: | --- |
| Compliance summaries | 0.0 to 0.1 | Deterministic language required. |
| Caller scripts | 0.05 | No creative improvisation in protected workflows. |
| Next-action reasoning | 0.0 | Prefer deterministic decision tree. |
| Broker coaching | 0.1 | Slight language flexibility, no factual invention. |
| Developer insights | 0.1 | Aggregate explanations only. |

## Broker Copilot

Primary job: help the broker understand protected work and take the next revenue-protecting action.

Core use cases:

| Question | Tool Path | Output |
| --- | --- | --- |
| What is happening with this lead? | `trust-get-lead-summary` | Lead alias, status, area, budget band, project interest. |
| Is my work protected? | `trust-get-broker-lock-status` | Lock status, days remaining, proof status. |
| What should I do next? | `trust-recommend-next-action` | One recommended action, reason, risk, confidence. |
| When should I follow up? | `trust-get-followup-risk` | Delay, risk, and next action. |
| Create a follow-up. | `trust-create-followup` after confirmation | Follow-up created, audit event returned. |

UX pattern:

- One action card at the top.
- Protected lock state visible without legal language.
- Lead alias only.
- No contact shortcuts.
- Bottom sheet for follow-up creation.

Hard stop:

If the broker asks for a contact, the copilot refuses and routes to secure workflow.

## Sourcing Manager Copilot

Primary job: help the SM identify stuck workflows and protect broker attribution while moving visits forward.

Core use cases:

| Question | Tool Path | Output |
| --- | --- | --- |
| Which leads are at risk today? | Batch `trust-get-followup-risk` | Priority queue. |
| Which visit needs proof? | `trust-get-site-visit-proof` | GPS/photo/proof state. |
| Which broker locks are active? | `trust-get-broker-lock-status` | Lock state and days remaining. |
| What should I move next? | `trust-recommend-next-action` | Workflow next step. |
| Create a follow-up for the caller. | `trust-create-followup` after confirmation | Follow-up and audit event. |

UX pattern:

- Today queue.
- Blocked workflow strip.
- Visit proof cards.
- Broker lock health panel.
- One primary action per lead.

Hard stop:

The SM copilot must not manually approve brokerage without verified visit proof and lock status.

## Caller Copilot

Primary job: help the caller perform consistent secure calls without ever seeing contact data.

Core use cases:

| Moment | Tool Path | Output |
| --- | --- | --- |
| Before secure call | `trust-get-lead-summary` plus future RAG | Project brief and safe script. |
| During call | Future RAG script retrieval | Objection handling and policy facts. |
| After call | Existing caller workflow function | Outcome capture through enum. |
| Next follow-up | `trust-recommend-next-action` | Follow-up suggestion. |

Allowed outcomes:

- `interested`
- `follow_up`
- `not_interested`
- `wrong_contact`
- `budget_mismatch`
- `site_visit_requested`

Hard stop:

The caller copilot must not expose provider payloads, contact identifiers, or raw call routing details.

## Developer Copilot

Primary job: give developer operations a verified view of broker ROI and marketing waste.

Core use cases:

| Question | Data Path | Output |
| --- | --- | --- |
| How many verified walk-ins happened? | Aggregated site visit proof | Count by project and period. |
| Which brokers produce verified visits? | Aggregated broker locks and visits | Broker ROI ranking. |
| Where is the funnel leaking? | Public workflow metadata | Upload to call to visit to lock funnel. |
| Which payouts are eligible? | Future payout eligibility tool | Eligibility, blockers, missing proof. |

UX pattern:

- Aggregate first.
- Drill down only into PII-safe workflow records.
- No buyer identity or contact data.
- No unverifiable revenue claims.

Hard stop:

The developer copilot cannot use AI to deny broker payout. It can only surface proof status and policy requirements.

## Implementation Sequence

1. Deploy and UAT the six AI-safe tools.
2. Add read-only Broker Copilot card using `trust-recommend-next-action`.
3. Add SM stuck-workflow queue using `trust-get-followup-risk`.
4. Add Caller pre-call brief only after secure-call UAT passes.
5. Add RAG for one pilot project after documents are PII-cleared.
6. Add Developer Copilot only after verified walk-ins and locks exist in production.

## Harsh-Truth Verdict

The copilots should be boring at first. If the AI feels impressive but cannot prove attribution, it is harmful. The first useful copilot is the one that prevents a missed follow-up, protects a lock, and leaves a clean audit trail.
