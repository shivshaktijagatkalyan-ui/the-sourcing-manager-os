# Abuse Monitoring

Sprint 4 introduces a control-room model for operational risk. Abuse monitoring is not a CRM activity feed. It is a sanitized enforcement layer for pilot admins.

## Abuse Event Ledger

Table: `public.abuse_events`

Fields are limited to operational identifiers and reason codes:

- `actor_id`
- `organization_id`
- `lead_id`
- `site_visit_id`
- `event_type`
- `severity`
- `risk_score_delta`
- `evidence_ref`
- `status`
- resolution timestamps and actor IDs

`evidence_ref` must never contain phone numbers, names, provider payloads, files with identity-bearing paths, or free-form customer details. Edge Functions sanitize evidence references before insert.

## Event Types

- `gps_outside_geofence_repeated`
- `gps_accuracy_failure_repeated`
- `photo_overwrite_attempt`
- `call_after_loan_expiry`
- `revoked_loan_access_attempt`
- `duplicate_lock_attempt`
- `broker_rejection_spike`
- `dispute_frequency_spike`
- `inactive_enabled_user`
- `unusual_activity_window`
- `disabled_user_access_attempt`
- `paused_org_access_attempt`

## Severity

- `low`: informational risk signal
- `medium`: operator review recommended
- `high`: trust impact and active review needed
- `critical`: freeze recommendation path available

Critical events write audit events for `user_freeze_recommended` or `org_freeze_recommended` when the scope is known.

## Write Path

Only service-role Edge Functions write abuse records. The frontend has no insert, update, or delete policy on `abuse_events`.

Allowed actions:

- `flag-abuse-event`: admin-created or system-forwarded event
- `resolve-abuse-event`: admin resolution/dismissal
- `record_pilot_abuse`: service-role-only database RPC used by protected Edge Functions

Every mutation writes an `audit_events` row without sensitive data.

## Admin Dashboard

The Flutter Ops Control Room reads:

- recent abuse events
- risk notifications
- organization risk summary
- user risk summary
- trust score snapshots
- pilot activity aggregates

If RLS blocks a user, the dashboard fails closed with no records.
