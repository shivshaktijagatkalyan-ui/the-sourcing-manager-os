# AI SAFE TOOL LAYER REPORT

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Verdict: IMPLEMENTED LOCALLY - DEPLOYMENT STILL REQUIRED

## Executive Summary

The AI-safe tool layer has been added as a metadata-only Edge Function surface. The goal is to let future copilots ask operational questions and request safe workflow actions without querying raw tables, reading sensitive stores, or seeing contact data.

Harsh truth: this is not "AI intelligence" yet. It is the minimum safe control plane required before any AI copilot should be allowed near the trust workflow. The value is the tool boundary, permission checks, and auditability, not the model.

## Implemented Functions

| Tool | Purpose | Status |
| --- | --- | --- |
| `trust-get-lead-summary` | Returns public lead metadata for permitted actors. | Added locally and registered in `supabase/config.toml`. |
| `trust-get-broker-lock-status` | Returns broker lock status and days remaining. | Added locally and registered in `supabase/config.toml`. |
| `trust-get-followup-risk` | Returns deterministic follow-up delay, risk, and next action. | Added locally and registered in `supabase/config.toml`. |
| `trust-get-site-visit-proof` | Returns proof status as booleans and timestamp only. | Added locally and registered in `supabase/config.toml`. |
| `trust-create-followup` | Creates a follow-up through a permission-gated Edge Function and writes an audit event. | Added locally and registered in `supabase/config.toml`. |
| `trust-recommend-next-action` | Returns deterministic workflow recommendation from metadata. | Added locally and registered in `supabase/config.toml`. |

## Security Model

All tools follow this pattern:

```text
AI or app client
-> Edge Function with JWT
-> active pilot user check
-> organization and role/permission check
-> metadata-only query
-> sanitized JSON response
```

The tools are not allowed to:

- Query `leads_sensitive`.
- Query `brokers_sensitive`.
- Decrypt contact data.
- Return contact fields, partial contact fields, or contact links.
- Return raw database errors.
- Log request payloads.
- Use frontend service-role keys.

## Verification Added

New static gate:

```bash
node scripts/ai-safe-tool-check.mjs
```

This gate checks:

- All six required tool directories exist.
- All six tools are registered in `supabase/config.toml`.
- `verify_jwt = true` is enabled for each tool.
- Tool source does not reference sensitive tables.
- Tool source does not contain decryption paths.
- Tool source does not contain service-role key literals.
- Tool source does not contain direct calling or messaging links.
- Tool source does not contain blocked contact wording.
- Required metadata output fields are present.

Latest result: PASS.

## Tool Contracts

### `trust-get-lead-summary`

Input:

```json
{ "lead_id": "<uuid>" }
```

Output:

```json
{
  "ok": true,
  "lead_alias": "lead-alias",
  "status": "new",
  "budget_range": "metadata-only",
  "area": "metadata-only",
  "project_interest": "metadata-only",
  "source_broker_id": "<uuid>"
}
```

### `trust-get-broker-lock-status`

Input:

```json
{ "lead_id": "<uuid>" }
```

or:

```json
{ "broker_id": "<uuid>" }
```

Output:

```json
{
  "ok": true,
  "lock_status": "active",
  "days_remaining": 30,
  "brokerage_status": "pending",
  "proof_status": "verified"
}
```

### `trust-get-followup-risk`

Input:

```json
{ "lead_id": "<uuid>" }
```

Output:

```json
{
  "ok": true,
  "followup_delay_hours": 4,
  "risk_level": "medium",
  "next_action": "call_now"
}
```

### `trust-get-site-visit-proof`

Input:

```json
{ "site_visit_id": "<uuid>" }
```

Output:

```json
{
  "ok": true,
  "gps_verified": true,
  "photo_uploaded": true,
  "timestamp": "2026-05-16T00:00:00Z",
  "proof_status": "verified"
}
```

### `trust-create-followup`

Input:

```json
{
  "lead_id": "<uuid>",
  "followup_type": "call",
  "due_at": "2026-05-17T10:00:00Z",
  "reason": "safe operational reason"
}
```

Output:

```json
{
  "ok": true,
  "success": true,
  "audit_event_id": "<uuid>"
}
```

### `trust-recommend-next-action`

Input:

```json
{ "lead_id": "<uuid>" }
```

Output:

```json
{
  "ok": true,
  "recommended_action": "schedule_visit",
  "reason": "status and follow-up metadata indicate site visit is next",
  "risk": "medium",
  "confidence": 0.78
}
```

## Production Gaps

- These functions were added locally; deployment to the remote Supabase project still needs to be performed by the operator.
- No live AI copilot should call these tools until deployed functions pass role-based UAT with broker, sourcing manager, caller, and admin identities.
- `trust-create-followup` creates operational state, so it needs explicit abuse testing for repeated calls and stale lead states before field use.

## Harsh-Truth Verdict

The AI-safe tool layer is the correct architecture because it makes AI subordinate to workflow permissions. It is not enough by itself. The next proof point is not a demo chat. The next proof point is: can a caller, broker, and sourcing manager each receive only the metadata their role is allowed to see while every tool call produces a clean audit trail?
