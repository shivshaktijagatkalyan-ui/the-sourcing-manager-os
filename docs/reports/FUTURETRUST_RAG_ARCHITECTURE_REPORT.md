# FUTURETRUST RAG ARCHITECTURE REPORT

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Status: DESIGN ONLY - NOT IMPLEMENTED

## Executive Summary

RAG is useful for FutureTrust only if it improves operational accuracy without weakening trust. It should retrieve project facts, developer policies, brokerage rules, scripts, locality notes, site visit SOPs, and payout rules. It must not become a hidden route to contact data, broker secrets, or uncontrolled AI answers.

Harsh truth: adding RAG before the trust loop is live-proven would be a distraction. The design is ready, but implementation should wait until caller auth, secure call, site proof, and broker lock UAT pass.

## Knowledge Sources

Approved sources:

| Source | Use |
| --- | --- |
| Project inventory docs | Unit mix, availability bands, configuration facts. |
| Developer policies | Cancellation, documentation, handover, and escalation rules. |
| Brokerage rules | Lock duration, payout trigger, payout documentation. |
| RERA and compliance docs | Approved project and compliance facts. |
| Sales scripts | Project-specific and objection-specific talk tracks. |
| Objection handling notes | Deterministic answers for common buyer objections. |
| Locality notes | Transport, schools, hospitals, infrastructure, appreciation context. |
| Pricing sheets | Structured ranges and floor/configuration premiums. |
| Site visit SOPs | Required proof steps, timing, and verification rules. |
| Payout rules | Eligibility, documents, timelines, and dispute checkpoints. |

Excluded sources:

| Excluded | Reason |
| --- | --- |
| Contact numbers or contact identifiers | Violates the Dataless Constitution. |
| Raw customer identities | Not required for operational retrieval. |
| Raw broker-sensitive data | Commercially sensitive and unnecessary. |
| Raw audit logs | Can create identity linkage risk. |
| Service keys, tokens, provider payloads | Security-critical material. |
| Unreviewed uploaded files | Ingestion must fail closed. |

## Ingestion Pipeline

```text
Source document
-> operator review gate
-> PII scrubber
-> structured parser
-> semantic chunking
-> metadata tagging
-> embedding generation
-> vector upsert
-> retrieval eval
-> release approval
```

Mandatory ingestion controls:

- Every document must have `pii_cleared = true`.
- Every document must have a human reviewer.
- Every document must have a source type.
- Every project-specific document must have `project_id`.
- Every rule/policy document must have `valid_from` and optional `valid_until`.
- Documents without required metadata are not retrievable.

## Chunking Strategy

| Document Type | Chunk Unit | Max Tokens | Notes |
| --- | --- | ---: | --- |
| Sales scripts | Objection and answer pair | 300 | Keep question and answer together. |
| Pricing sheets | Configuration or inventory band | 400 | Store numbers as structured metadata where possible. |
| Brokerage rules | Clause | 500 | Preserve rule hierarchy. |
| RERA/compliance | Section | 600 | Keep citation and effective date. |
| Site visit SOPs | Step | 250 | Preserve ordered sequence. |
| Developer policy | Policy paragraph | 500 | Include escalation owner role, not person identity. |
| Locality notes | Locality topic | 400 | Tag locality and project relevance. |

## Metadata Schema

```json
{
  "doc_id": "<uuid>",
  "chunk_id": "<uuid>",
  "source_type": "project_inventory | policy | brokerage_rule | compliance | script | locality | sop | payout_rule",
  "project_id": "<uuid | null>",
  "developer_id": "<uuid | null>",
  "organization_id": "<uuid | null>",
  "language": "en | hi | mr",
  "locality": "<string | null>",
  "valid_from": "2026-05-16T00:00:00Z",
  "valid_until": null,
  "pii_cleared": true,
  "reviewer_user_id": "<uuid>",
  "source_version": 1
}
```

## Retrieval Routes

| Route | User | Query Context | Required Filters |
| --- | --- | --- | --- |
| Project facts | Broker, caller, SM | Project and lead metadata | `project_id`, `source_type in project_inventory/pricing/locality` |
| Script support | Caller | Project, intent band, objection | `project_id`, `source_type = script` |
| Visit SOP | SM | Project, visit state | `source_type = sop`, optional `project_id` |
| Brokerage policy | Broker, SM, developer | Broker lock and payout state | `source_type = brokerage_rule or payout_rule` |
| Compliance lookup | SM, admin | Project and policy question | `source_type = compliance`, `valid_until is null or future` |

## Guardrails

- Retrieval threshold starts at 0.78; below threshold, the assistant must say it lacks verified context.
- All answers that include project, price, brokerage, or compliance facts must include retrieved citation IDs internally.
- AI must not invent pricing, inventory, payout timelines, or RERA status.
- AI must not answer from model memory when verified internal knowledge exists.
- AI cannot write directly to tables. Any workflow change must call an approved Edge Function.
- Retrieved chunks are scrubbed again before model context injection.

## Evaluation Plan

| Eval | Purpose |
| --- | --- |
| PII ingestion eval | Blocks contact data, identity linkage, and keys before vector upsert. |
| Retrieval precision eval | Confirms the right project/policy chunks are returned. |
| Citation coverage eval | Ensures factual claims map to retrieved sources. |
| Refusal eval | Ensures AI declines when retrieval confidence is low. |
| Cross-project leakage eval | Ensures Project A queries do not retrieve Project B facts. |
| Role-context eval | Ensures caller, broker, SM, and developer see only allowed knowledge classes. |

## Implementation Recommendation

Do not implement RAG before Phase 1 UAT passes. The correct sequence is:

1. Finish caller and Exotel blockers.
2. Prove secure call to verified visit to broker lock.
3. Deploy AI-safe tool functions.
4. Add RAG ingestion for one project only.
5. Run RAG evals.
6. Enable copilots in read-only suggestion mode.

## Harsh-Truth Verdict

RAG is the operational brain only after trust infrastructure is proven. Before that, it is another moving part that can create false confidence. Use it for facts and SOPs, not as a trust authority.
