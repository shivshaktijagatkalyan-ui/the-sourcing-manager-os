# TRUST OBSERVABILITY DASHBOARD SPEC

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Status: SPECIFICATION - IMPLEMENTATION PENDING

## Purpose

This dashboard is not for vanity analytics. It exists to answer one operational question: is the trust loop working without leaks, stale work, fake proof, or attribution disputes?

If a metric does not help protect work, verify effort, reduce chaos, or build trust, it does not belong here.

## Primary Metrics

| Metric | Definition | Warning Trigger | Source |
| --- | --- | --- | --- |
| Lead response time | Upload to first valid assignment. | More than 24 hours. | `audit_events`, `leads_public`. |
| Follow-up delay | Current time minus due follow-up time. | More than 6 hours overdue. | `leads_public`, `broker_followups`. |
| Caller outcome rate | Calls that produce useful next state. | Below 30 percent. | `call_attempts`. |
| Site visit conversion | Scheduled visits that become verified visits. | Below 50 percent. | `site_visits`. |
| Broker lock creation rate | Verified visits that create active locks. | Below 70 percent. | `broker_locks`, `site_visits`. |
| Duplicate attempts | Same protected contact fingerprint attempted again. | Any occurrence. | `abuse_events`. |
| GPS failures | Visit attempts rejected by geofence/accuracy checks. | More than 10 percent. | `site_visits`, proof events. |
| Callback failures | Provider callbacks rejected by security/state rules. | Any spike. | `call_attempts`, `audit_events`. |
| Data loan expiry | Loans that expire without valid action. | More than 20 percent. | `data_loans`. |
| Stuck workflows | Active leads with no progress in 7 days. | More than 5 percent. | `leads_public`, `audit_events`. |
| Audit completeness | Protected workflows missing required audit events. | Any missing required event. | `audit_events`. |

## Dashboard Layout

Top band: trust-loop health

| Tile | Shows |
| --- | --- |
| Active leads | Count and change since yesterday. |
| Stuck workflows | Count, oldest age, top reason. |
| Calls today | Secure calls attempted and completed. |
| Verified visits | GPS and photo proof completion. |
| Active locks | Count and expiring soon. |
| Abuse signals | Duplicate, replay, GPS, and permission denial events. |

Second band: action queue

| Queue | Owner |
| --- | --- |
| Calls overdue | Caller/SM. |
| Follow-ups overdue | Broker/caller/SM. |
| Visits proof pending | SM. |
| Locks expiring | Broker/SM. |
| Callback failures | Admin/operator. |
| Duplicate attempts | Admin/operator. |

Third band: funnel

```text
Lead uploaded
-> caller assigned
-> secure call completed
-> follow-up created
-> visit scheduled
-> GPS verified
-> photo proof uploaded
-> visit verified
-> broker lock created
```

Every stage should show count, conversion percent, median time, and failure reason.

## Alert Rules

| Alert | Severity | Required Response |
| --- | --- | --- |
| Sensitive table access denied spike | High | Review frontend queries and role policies. |
| Provider callback auth failures | High | Rotate callback secret if malicious pattern appears. |
| Duplicate upload between brokers | High | Create abuse event and preserve attribution evidence. |
| GPS failure cluster at one project | Medium | Check project coordinates and field SOP. |
| Data loans expiring unused | Medium | Review caller capacity and assignment logic. |
| Audit event missing after protected action | Critical | Block pilot readiness until repaired. |

## Required Views

Broker view:

- My protected leads.
- Follow-ups overdue.
- Locks active and expiring.
- Site visits verified.
- Brokerage stuck points.

Sourcing manager view:

- Team action queue.
- Leads without caller assignment.
- Visits scheduled today.
- Proof pending.
- Broker locks requiring attention.

Caller view:

- Assigned call queue.
- Calls overdue.
- Follow-up due now.
- Outcome completion quality.

Developer/admin view:

- Verified walk-ins.
- Broker ROI.
- Campaign waste.
- Lock and payout status.
- Trust violations.

Platform admin view:

- Security alerts.
- RLS denials.
- callback failures.
- duplicate abuse.
- audit completeness.
- release gate history.

## Harsh-Truth Verdict

Observability is not optional for a trust infrastructure product. Without this dashboard, the system can look functional while attribution quietly fails. Build it after the trust loop passes, but before expanding beyond the first controlled pilot.
