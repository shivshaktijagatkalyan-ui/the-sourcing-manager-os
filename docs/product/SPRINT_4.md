# Sprint 4: Operational Visibility & Abuse Monitoring

Status: BUILT / DEPLOYMENT PENDING
Target: v0.4.0-ops
Scope: control-room visibility for pilot operations.

## Objective

Sprint 4 adds an operational risk layer for pilot admins. It does not add CRM convenience features, lead sharing, marketplace behavior, or customer identity views.

The goal is to detect abuse early:

- repeated GPS failures
- photo overwrite attempts
- access after expired or revoked data loans
- duplicate commission lock attempts
- broker rejection spikes
- dispute frequency spikes
- inactive enabled users
- unusual activity windows
- disabled user access attempts
- paused organization access attempts

## Security Boundary

Sprint 1, Sprint 2, and Sprint 3 remain frozen. Sprint 4 reads sanitized operational events and writes risk records through Edge Functions only.

The dashboards never display phone numbers, partial phone numbers, customer names, provider payloads, raw call metadata, WhatsApp links, or direct call links. Risk records use IDs, event types, status codes, reason codes, and score components only.

## Database Additions

- `abuse_events`
- `risk_notifications`
- `trust_score_snapshots`
- `pilot_activity_daily`
- `org_risk_summary`
- `user_risk_summary`

All new tables have RLS enabled and forced. Direct frontend mutation is denied by the absence of insert, update, and delete policies. Reads are limited to active pilot admins in the same active organization, with a narrow self-read policy for safe trust history.

## Edge Functions

- `flag-abuse-event`
- `resolve-abuse-event`
- `generate-risk-summary`
- `create-risk-notification`
- `acknowledge-risk-notification`
- `run-trust-decay`

Every function authenticates the caller, validates pilot status, validates active organization status, returns generic safe reasons, and avoids raw request/provider logging.

Disabled pilot users and paused organizations are recorded as critical abuse events when they attempt Sprint 4 actions.

## Acceptance Gate

Sprint 4 is accepted only after live smoke tests prove:

- abuse dashboard works
- critical risk events are generated
- trust decay is explainable
- admin notifications work
- non-admin access is blocked
- paused org access is blocked
- disabled user access is blocked
- repeated GPS failures trigger risk
- duplicate lock attempts trigger risk
- no customer identity data appears in UI, logs, network traffic, or risk tables
- security scan passes

Until those pass, status remains:

Sprint 4: BUILT / DEPLOYMENT PENDING
Pilot users: ACTIVE / CONTROLLED
Sprint 5: LOCKED
