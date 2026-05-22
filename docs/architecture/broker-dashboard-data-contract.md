# Broker Dashboard Data Contract

This contract defines the broker dashboard input/output surface. It is intentionally deterministic: UI sections read broker-safe public data, mutations go through Edge Functions, and training mode uses `TrainingRuntime` without touching Supabase.

## Runtime Modes

| Mode | Read Source | Mutation Source | Requirement |
| --- | --- | --- | --- |
| Training/local | `TrainingRuntime` | `TrainingRuntime` methods | Must never invoke Supabase functions. |
| Live Supabase | Supabase public tables/RPCs | Supabase Edge Functions | Must never fall back to demo data silently. |

The Flutter guard for live mutation paths is:

```dart
AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode
```

## Dashboard Sections

| UI Section | Live Source | Training Source | Safe Output |
| --- | --- | --- | --- |
| Identity card | `brokers_public` filtered by `linked_user_id = auth.uid()` and `status = active` | `brokerDashboardProfile()` | Broker code, alias/name, company, focus area, rank, trust score, verified status. |
| Profile completion | Local role-aware widget state | Static role input | Completion CTA only; no sensitive buyer data. |
| Priority action strip | Derived from safe lead rows, follow-ups, visits, data loans | `brokerDashboardStats()` and lead rows | Next deterministic action such as follow-up, renew access, review visit. |
| KPI ribbon | Derived from `leads_public`, `site_visits`, `site_visit_proposals`, `broker_locks`, `data_loans`, `call_attempts` | `brokerDashboardStats()` | Counts only. |
| Growth cards | Derived from broker profile, lead rows, and `broker_goals` active goal | `brokerDashboardStats()` and profile | Area, project, conversion, pending leads, access expiry, suggested focus. |
| Lead cards | `leads_public` joined only through safe metadata and related safe status maps | `brokerLeadRows()` | Alias, area, project, budget band, quality, buyer type, assigned role label, permission status, visit status, broker lock status, booking/brokerage status. |
| Follow-ups | `broker_followups` by broker IDs | `brokerFollowupRows()` | Status, due date, priority, reason. |
| Live projects | `broker_activations` joined to `projects` | `brokerLiveProjects()` | Project name, area/city, activation stage, lead/visit counts. |
| Site visit proposals | `site_visit_proposals` filtered by `source_broker_id` | `brokerSiteVisitProposalRows()` | Proposal status, proposed time, safe notes, project/lead alias. |
| Broker locks | `broker_locks` joined to `leads_public(alias, project_id)` | `brokerLockRows()` | Lock status, expiry countdown, brokerage status, lead alias. |
| Booking/brokerage | Derived from `leads_public.booking_stage` and `leads_public.brokerage_status` | `brokerLeadRows()` | Stage labels and counts. |
| Activity logs | `broker_activity_logs` by broker IDs | `brokerActivityRows()` | Activity type, outcome, next follow-up, created time. |

## Mutation Contract

| UI Action | Accepted Input | Live Edge Function | Training Equivalent | Persisted Output |
| --- | --- | --- | --- | --- |
| Add Secure Lead | Alias, one-time phone, area, city, property, budget | `broker-upload-lead` | `TrainingRuntime.addLeadFromBroker()` | `leads_public`, audit result, duplicate result. |
| Secure Call | `lead_id` only | `broker-self-secure-call` | `TrainingRuntime.initiateCall()` | `call_attempts`, audit/provider status. |
| Assign Caller | `lead_id`, selected caller ID | `broker-vault-workflow` with `assign_to_caller` | `TrainingRuntime.assignLeadToCaller()` | Lead assignment and activity. |
| Grant Access | `lead_id`, caller ID, duration | `data-loan-workflow` with `grant_access` | `TrainingRuntime.updateDataLoanStatus()` | Active `data_loans` row. |
| Extend Access | `lead_id`, duration | `data-loan-workflow` with `extend_access` | `TrainingRuntime.updateDataLoanStatus()` | Extended `expires_at`. |
| Revoke Access | `lead_id` | `data-loan-workflow` with `revoke_access` | `TrainingRuntime.updateDataLoanStatus()` | Revoked `data_loans` row. |
| Set Follow-up | `lead_id`, due date | `broker-vault-workflow` with `set_followup` | `TrainingRuntime.setBrokerLeadFollowup()` | Lead/follow-up date update. |
| Update Quality | `lead_id`, quality | `broker-vault-workflow` with `update_lead_quality` | `TrainingRuntime.updateBrokerLeadQuality()` | Safe quality update. |
| Raise Issue | `lead_id`, issue type | `broker-vault-workflow` with `raise_issue` | `TrainingRuntime.raiseBrokerIssue()` | Issue/activity row. |
| Propose Site Visit | `lead_id`, `project_id`, proposed time, safe notes | `propose-site-visit` | `TrainingRuntime.proposeSiteVisitFromLead()` | `site_visit_proposals` row and audit. |

## Sensitive Data Rules

The broker dashboard must not render or directly query:

- `leads_sensitive`
- `brokers_sensitive`
- raw phone fields
- raw mobile fields
- raw customer contact fields
- WhatsApp links
- direct `tel:` links

`broker_upload.dart` may collect a phone value only as one-time input. It must clear the controller before/after submit and must not pass that value back into dashboard state.

## RLS And Isolation Requirements

| Data Surface | Isolation Requirement |
| --- | --- |
| `brokers_public` | Broker row must be active and linked to `auth.uid()` through `linked_user_id`. |
| `leads_public` | Broker dashboard reads only rows whose `source_broker_id` is in the linked broker IDs. |
| `site_visits` | Broker dashboard reads only source-broker visits for linked broker IDs. |
| `site_visit_proposals` | Broker dashboard reads only source-broker proposals for linked broker IDs. |
| `broker_locks` | Broker dashboard reads only locks for linked broker IDs. |
| `data_loans` | Broker dashboard reads only loans attached to broker-visible lead IDs. |
| `broker_followups` | Broker dashboard reads only follow-ups for linked broker IDs. |
| `broker_activity_logs` | Broker dashboard reads only activity for linked broker IDs. |
| `broker_goals` | Broker dashboard reads only active goals for linked broker IDs. |

Relevant RLS hardening migrations:

- `supabase/migrations/20260510000300_broker_isolation_fix.sql`
- `supabase/migrations/20260512000200_harden_trust_loop_isolation_policies.sql`
- `supabase/migrations/20260507000600_site_visit_proposal_confirmation.sql`

## Acceptance Checklist

- Broker profile missing shows a deterministic setup/blocked state.
- Empty optional sections render empty states, not a permanent spinner.
- Training mode and live mode choose different paths explicitly.
- Every mutation shows success, blocked, or failed output.
- Every persisted live mutation can be traced to a table row or audit/provider result.
- Automated tests prevent sensitive table/contact regressions.
