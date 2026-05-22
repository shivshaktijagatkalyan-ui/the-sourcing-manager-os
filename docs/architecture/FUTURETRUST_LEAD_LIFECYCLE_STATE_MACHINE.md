# FUTURETRUST LEAD LIFECYCLE STATE MACHINE

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Status: Production state-machine specification
Verdict: Required before scaling lead volume

## 1. Executive Summary

FutureTrust must not treat a lead as a CRM contact row. A lead is a protected workflow object.

The lead journey must track four separate realities:

| Axis | Field Family | Meaning |
| --- | --- | --- |
| Trust state | `lead_status`, `data_loans`, `call_attempts`, `site_visits`, `broker_locks` | What the protected workflow has proven. |
| Sales state | `conversion_stage`, `booking_stage` | Where the buyer journey is operationally stuck or moving. |
| Intent state | `lead_temperature`, `lead_quality`, `project_match_status` | How serious and matched the buyer appears. |
| Attribution state | `source_broker_id`, `brokerage_status`, `broker_locks`, `audit_events` | Which broker's work is protected and why. |

Harsh truth: mixing these into one status creates operational lies. A lead can be hot and still uncalled. A lead can be warm and already protected. A lead can be locked but not booked. The system must represent those differences cleanly.

## 2. Core Principle

Nobody owns the contact.

The system owns the workflow.

The broker owns attribution.

The developer gets proof.

The buyer gets coordinated service.

The audit trail protects the truth.

## 3. Current Field Map

FutureTrust already has the required base fields.

### `lead_status`

Trust/workflow spine:

| Value | Meaning |
| --- | --- |
| `new` | Lead accepted into public metadata store. |
| `loan_active` | A temporary data loan exists for approved action. |
| `call_queued` | Lead is ready for secure call. |
| `call_blocked` | Consent, DND, permission, provider, or workflow block. |
| `visit_scheduled` | Site visit is scheduled. |
| `visit_verified` | Visit proof passed. |
| `locked` | Broker lock exists. |
| `revoked` | Workflow access is revoked. |

### `conversion_stage`

Sales operation spine:

| Value | Meaning |
| --- | --- |
| `lead_received` | Metadata accepted and attribution attached. |
| `call_pending` | Lead needs first secure call. |
| `assigned_to_caller` | Caller has responsibility through data loan. |
| `assigned_to_sm` | Sourcing manager owns next coordination step. |
| `called` | Secure call happened; outcome should exist. |
| `interested` | Buyer has signaled real interest. |
| `call_later` | Follow-up is due at a scheduled time. |
| `not_reachable` | Call attempt failed to reach buyer. |
| `visit_scheduled` | Visit is scheduled but not verified. |
| `visit_verified` | Visit proof completed. |
| `booking_discussion` | Price, inventory, or booking conversation started. |
| `token_discussion` | Token amount or booking hold is being discussed. |
| `closed` | Deal converted. |
| `lost` | Deal lost or disqualified. |

### `lead_temperature`

Intent thermometer:

| Value | Meaning |
| --- | --- |
| `cold` | Weak urgency or unclear intent. |
| `warm` | Responsive and potentially matched. |
| `hot` | Action behavior indicates near-term buying intent. |

### `lead_quality`

Qualification descriptor:

| Value | Meaning |
| --- | --- |
| `hot` | High intent. |
| `warm` | Medium intent. |
| `cold` | Low intent. |
| `investor` | ROI-focused buyer. |
| `end_user` | Family/use-focused buyer. |
| `budget_matched` | Budget aligns with project range. |
| `location_matched` | Location preference aligns. |
| `project_matched` | Project preference aligns. |
| `duplicate_risk` | Needs duplicate/abuse review. |
| `low_quality` | Spam, weak, or poor fit. |
| `loan_required` | Financing dependency exists. |
| `family_decision_pending` | Family approval dependency exists. |
| `site_visit_ready` | Ready for visit scheduling. |

### `booking_stage`

Post-visit commercial spine:

| Value | Meaning |
| --- | --- |
| `not_started` | Booking workflow not started. |
| `booking_discussion` | Booking conversation active. |
| `token_discussion` | Token/payment hold being discussed. |
| `token_paid` | Token collected. |
| `booking_confirmed` | Booking confirmed. |
| `loan_legal_started` | Loan/legal process started. |
| `agreement_pending` | Agreement stage pending. |
| `payment_pending` | Payment pending. |
| `closed` | Deal closed. |
| `lost` | Deal lost. |

### `brokerage_status`

Broker attribution/payment spine:

| Value | Meaning |
| --- | --- |
| `tracking` | Attribution is being tracked. |
| `pending_visit` | Visit proof required before lock/eligibility. |
| `locked` | Broker lock exists. |
| `eligible` | Brokerage eligibility achieved. |
| `paid` | Brokerage paid. |
| `disputed` | Broker issue or payout dispute exists. |
| `blocked` | Eligibility blocked by rule or abuse signal. |

## 4. Master Lead Life Journey

```text
Traffic source
-> lead intake
-> sensitive contact encryption
-> contact hash duplicate check
-> lead alias creation
-> broker attribution attached
-> public metadata stored
-> audit event created
-> caller or SM assignment
-> data loan
-> secure call
-> call outcome
-> follow-up/nurture
-> cold/warm/hot classification
-> site visit proposal
-> site visit scheduled
-> GPS verification
-> photo proof
-> visit verified
-> broker lock
-> negotiation
-> booking
-> brokerage eligibility
-> payout tracking
-> audit timeline
-> trust analytics
```

## 5. Lead Source Intake

Allowed sources:

| Source | Operational Treatment |
| --- | --- |
| Broker network | Highest attribution sensitivity. Must attach `source_broker_id`. |
| Meta/Google campaigns | Must attach campaign/source metadata but no contact exposure. |
| Developer referral | Must attach project/developer source. |
| Property portal | Must dedupe aggressively due common repeated inquiries. |
| Walk-in | Must create lead alias and proof trail before broker claim. |
| Existing buyer referral | Must attach referring actor safely. |
| Future AI campaign | Must remain metadata-only and Edge Function governed. |

Required intake rule:

No source can bypass encryption, duplicate detection, lead alias creation, attribution assignment, or audit event creation.

## 6. Lead Creation State

Initial accepted state:

```text
lead_status = new
conversion_stage = lead_received
lead_temperature = warm
lead_quality = warm or provided safe qualifier
booking_stage = not_started
brokerage_status = tracking
```

Required guards:

| Guard | Failure Result |
| --- | --- |
| Missing authenticated user | Reject. |
| Missing role/permission | Reject. |
| Missing organization | Reject. |
| Invalid broker source | Reject. |
| Duplicate contact hash | Block or mark duplicate risk without exposing contact. |
| Encryption failure | Reject. |
| Sensitive write failure | Reject or rollback. |
| Audit write failure for protected action | Treat as release-blocking defect. |

Trust impact:

If creation succeeds without attribution or audit, the lead is operationally unsafe. It should not enter caller or site visit workflows.

## 7. State Axes Must Stay Separate

Correct representation:

```text
lead_status = loan_active
conversion_stage = assigned_to_caller
lead_temperature = warm
lead_quality = loan_required
next_action = secure_call
```

Incorrect representation:

```text
status = warm
```

Why incorrect:

`warm` says intent. It does not say who owns the next action, whether a data loan exists, whether calling is allowed, or whether attribution is protected.

## 8. Temperature Classification

Temperature is not trust proof. It is a sales signal.

### Cold

Signals:

- Weak urgency.
- Asks only for rate.
- Budget unclear.
- Location mismatch.
- No family/decision clarity.
- No site visit interest.
- Repeated non-response.

System action:

```text
lead_temperature = cold
lead_quality = cold or low_quality
conversion_stage = call_later or not_reachable
next_followup_at = scheduled future nurture
```

Allowed next actions:

- create follow-up,
- project match improvement,
- educational nurture,
- mark low quality,
- delay active sales effort.

### Warm

Signals:

- Responds to secure call.
- Asks project questions.
- Budget roughly matches.
- Location roughly matches.
- Needs family or loan clarity.
- Accepts follow-up.

System action:

```text
lead_temperature = warm
lead_quality = budget_matched | location_matched | project_matched | loan_required | family_decision_pending
conversion_stage = interested or call_later
next_followup_at = near-term scheduled follow-up
```

Allowed next actions:

- assign caller,
- create follow-up,
- route to SM,
- recommend project,
- prepare visit proposal if strong interest appears.

### Hot

Signals:

- Requests site visit.
- Discusses payment or token.
- Asks booking amount.
- Shares visit availability.
- Revisits same project.
- Has urgency or deadline.
- Family is aligned enough for visit.

System action:

```text
lead_temperature = hot
lead_quality = hot or site_visit_ready
conversion_stage = interested
brokerage_status = pending_visit
```

Allowed next actions:

- schedule visit,
- assign SM,
- high-priority follow-up,
- protect broker attribution,
- prepare site visit proof workflow.

## 9. Temperature Upgrade Rules

Cold -> Warm allowed when:

| Evidence | Requirement |
| --- | --- |
| Response | Buyer responds to secure call or follow-up. |
| Fit | Budget or location is at least partially matched. |
| Intent | Buyer asks meaningful project question. |
| Next step | Buyer accepts callback, details, or project comparison. |

Warm -> Hot allowed when:

| Evidence | Requirement |
| --- | --- |
| Visit intent | Buyer asks for visit or accepts visit proposal. |
| Money signal | Buyer discusses payment, token, loan, or booking cost. |
| Timeline | Buyer has purchase timing pressure. |
| Decision clarity | Family/decision-maker availability is known. |

Hot -> Warm downgrade allowed when:

| Evidence | Meaning |
| --- | --- |
| Missed follow-ups | Intent cooling. |
| Visit postponed repeatedly | Timing risk. |
| Loan issue appears | Financing blocker. |
| Family objection appears | Emotional blocker. |

Warm/Hot -> Lost allowed when:

| Evidence | Meaning |
| --- | --- |
| Buyer clearly declines | Not interested. |
| Budget impossible | Cannot match. |
| Location impossible | Cannot match. |
| Duplicate abuse confirmed | Unsafe lead. |

AI may recommend these changes. Edge Functions must apply them.

## 10. Protected Workflow Transitions

### Intake to Assignment

```text
lead_received
-> assigned_to_sm
-> assigned_to_caller
```

Required guards:

- user has assignment permission,
- same organization,
- broker attribution exists,
- lead not revoked,
- no active lock conflict,
- audit event written.

### Assignment to Secure Call

```text
assigned_to_caller
-> loan_active
-> call_queued
-> called
```

Required guards:

- caller identity active,
- data loan active,
- consent/DND passes,
- provider config exists,
- sensitive contact decrypted only in memory,
- call attempt created without contact exposure.

Blocked transition:

No caller should move a lead to called without a valid secure call attempt.

### Call to Nurture

```text
called
-> interested
-> call_later
-> not_reachable
-> lost
```

Outcome mapping:

| Outcome | Conversion Stage | Temperature Bias |
| --- | --- | --- |
| interested | `interested` | warm or hot |
| call_later | `call_later` | cold or warm |
| not_reachable | `not_reachable` | cold |
| not_interested | `lost` | cold/lost |
| site_visit_requested | `interested` | hot |

Required guards:

- outcome must come from approved caller workflow,
- notes must be contact-scrubbed,
- follow-up date required for call-later,
- audit event written.

### Nurture to Site Visit

```text
interested
-> visit_scheduled
-> visit_verified
```

Required guards:

- source lead exists,
- source broker exists,
- SM is assigned or permitted,
- project exists,
- schedule timestamp valid,
- broker attribution is preserved,
- audit event written.

Blocked transition:

No site visit should be verified from a call outcome alone.

### Site Visit to Broker Lock

```text
visit_scheduled
-> started
-> gps_verified
-> photo_uploaded
-> visit_verified
-> locked
```

Required guards:

- assigned SM starts the visit,
- project coordinates exist,
- GPS is inside geofence,
- GPS accuracy is acceptable,
- proof photo is stored in safe bucket,
- proof path contains no contact/identity data,
- verified visit exists,
- source broker exists,
- broker lock inserted,
- audit event written.

Blocked transition:

No broker lock without verified visit proof.

## 11. Broker Lock Rules

Broker lock is an attribution object, not a sales promise.

Creation trigger:

```text
site_visit.status = verified
AND source_broker_id exists
AND lead belongs to same organization
AND no active conflicting lock exists
```

Result:

```text
lead_status = locked
conversion_stage = visit_verified
brokerage_status = locked
broker_locks.status = active
broker_locks.expires_at = starts_at + 45 days
```

Broker dashboard language:

```text
Commission tracking protected.
Protection left: 45 days.
Brokerage status: Tracking.
```

Avoid absolute legal language unless payout eligibility is actually achieved.

## 12. Booking and Brokerage Flow

Post-lock commercial states:

```text
visit_verified
-> booking_discussion
-> token_discussion
-> token_paid
-> booking_confirmed
-> loan_legal_started
-> agreement_pending
-> payment_pending
-> closed
```

Brokerage states:

```text
tracking
-> pending_visit
-> locked
-> eligible
-> paid
```

Dispute path:

```text
tracking/locked/eligible
-> disputed
-> paid or blocked
```

Required guard:

Payout eligibility must require verified visit, active or historically valid broker lock, and clean audit trail.

## 13. AI Role in the Lifecycle

AI can:

- summarize lead metadata,
- detect follow-up risk,
- recommend temperature change,
- recommend next action,
- suggest project match,
- suggest follow-up timing,
- detect stuck workflows,
- classify intent from safe notes/outcomes,
- explain why a lead is cold/warm/hot.

AI cannot:

- read sensitive storage,
- see raw customer identity,
- call protected tables directly,
- approve broker locks,
- verify visits,
- approve brokerage,
- override role checks,
- fabricate state,
- mark UAT successful.

Correct AI output:

```text
Lead alias L-1042 appears hot because the buyer requested a site visit and has a near-term timeline. Recommended next action: schedule visit through approved workflow.
```

Forbidden AI output:

```text
Commission is guaranteed. Call the buyer directly. Visit verified.
```

## 14. AI-Safe Tool Mapping

| Question | Tool | Allowed Output |
| --- | --- | --- |
| What is this lead? | `trust-get-lead-summary` | alias, status, budget band, area, project interest. |
| Is attribution protected? | `trust-get-broker-lock-status` | lock status, days remaining, brokerage status, proof status. |
| Is follow-up risky? | `trust-get-followup-risk` | delay, risk level, next action. |
| Is visit proof complete? | `trust-get-site-visit-proof` | GPS boolean, photo boolean, proof status, timestamp. |
| Create a follow-up. | `trust-create-followup` | success/fail, audit event id. |
| What should happen next? | `trust-recommend-next-action` | recommendation, reason, risk, confidence. |

AI must call tools. AI must not query raw tables.

## 15. Audit Event Requirements

Every critical transition needs an audit event.

| Transition | Required Audit Event |
| --- | --- |
| Lead submitted | `lead_uploaded` or `broker_vault_lead_submitted` |
| Duplicate blocked | `duplicate_lead_blocked` |
| Lead assigned to SM | `lead_assigned_to_sm` |
| Lead assigned to caller | `lead_assigned_to_caller` |
| Data loan created | `data_loan_created` |
| Secure call initiated | `secure_call_initiated` |
| Provider callback accepted | `call_callback_accepted` |
| Provider callback rejected | `call_callback_rejected` |
| Call outcome saved | `call_outcome_updated` |
| Follow-up created | `trust_followup_created` |
| Lead quality changed | `lead_quality_updated` |
| Site visit proposed | `site_visit_proposed` |
| Site visit scheduled | `site_visit_scheduled` |
| GPS verified | `site_visit_gps_verified` |
| GPS rejected | `site_visit_gps_rejected` |
| Photo proof uploaded | `site_photo_uploaded` |
| Visit verified | `site_visit_verified` |
| Broker lock created | `broker_lock_created` |
| Booking stage changed | `booking_stage_updated` |
| Brokerage status changed | `brokerage_status_updated` |
| Issue raised | `broker_issue_raised` |

Audit event context must be PII-safe. It may include IDs, statuses, timestamps, proof booleans, reason codes, and workflow metadata. It must not include contact data or raw provider payloads.

## 16. Dashboard Interpretation

### Broker Dashboard

Broker needs:

- protected lead alias,
- next action,
- follow-up due time,
- visit status,
- lock status,
- brokerage status,
- issue/dispute state.

Broker must not see:

- contact number,
- masked contact,
- last digits,
- direct messaging/calling links,
- other broker leads.

### Sourcing Manager Dashboard

SM needs:

- stuck workflows,
- hot leads needing visits,
- caller assignment gaps,
- proof pending visits,
- active broker locks,
- duplicate/abuse signals.

SM does not need raw contact exposure.

### Caller Dashboard

Caller needs:

- assigned lead alias,
- project/area/budget metadata,
- secure call button,
- script/context,
- outcome buttons,
- follow-up form.

Caller must not see contact data or expired loan leads.

### Developer Dashboard

Developer needs:

- verified walk-ins,
- broker ROI,
- lock count,
- conversion funnel,
- campaign waste,
- dispute queue.

Developer does not need buyer contact data.

## 17. Allowed Next Actions

Allowed next-action enum:

| Action | When |
| --- | --- |
| `assign_sm` | New lead has broker attribution but no SM owner. |
| `assign_caller` | Lead needs first secure call. |
| `secure_call` | Active data loan exists and caller owns action. |
| `create_followup` | Call later, not reachable, warm nurture, or delayed response. |
| `schedule_visit` | Lead is hot or site-visit ready. |
| `verify_site_visit` | Visit started but proof incomplete. |
| `monitor_lock` | Active lock exists. |
| `update_booking_stage` | Visit verified and booking conversation begins. |
| `raise_issue` | Attribution, proof, or brokerage risk exists. |
| `mark_lost` | Buyer clearly disqualified or declined. |
| `wait` | No immediate action required. |

No free-form AI action should mutate workflow state.

## 18. Blocked Transitions

These transitions must never be allowed:

| Blocked Transition | Reason |
| --- | --- |
| `new -> locked` | No verified effort. |
| `new -> visit_verified` | Site proof missing. |
| `assigned_to_caller -> called` without call attempt | Fake calling risk. |
| `called -> locked` | Call is not visit proof. |
| `visit_scheduled -> locked` | Scheduled visit is not verified visit. |
| `cold -> broker_lock` | Intent is not proof. |
| AI recommendation -> database write without Edge Function | Bypasses trust governance. |
| Frontend -> sensitive table read | Dataless Constitution violation. |
| Expired data loan -> secure call | Temporary access expired. |
| Provider callback without valid signature -> call update | Callback abuse risk. |

## 19. Operational Risk Map

| Risk | Impact | Control |
| --- | --- | --- |
| Duplicate broker claim | Commission dispute. | Contact hash duplicate detection and broker lock. |
| Fake call | False nurture data. | Secure call provider callback and state machine. |
| Fake site visit | Developer ROI waste. | GPS and photo proof. |
| Stale hot lead | Lost booking. | Follow-up risk and overdue queue. |
| AI hallucination | Wrong action or false confidence. | Tool-only metadata and low temperature. |
| Cross-broker leakage | Broker trust collapse. | RLS, Edge Function checks, `is_linked_broker_user`. |
| Missing audit event | Dispute cannot be resolved. | Release gate and audit completeness checks. |
| Provider config missing | Secure call impossible. | Fail closed and block pilot readiness. |

## 20. Current Implementation Gaps

This state machine is the target discipline. The current system is not fully proven against it.

Known blockers:

- Caller credentials are invalid in UAT.
- Exotel provider secrets are missing locally.
- Callback secret is missing for live provider proof.
- Secure-call UAT is incomplete.
- Site-visit proof is not live-verified in current UAT.
- Broker lock is not live-proven in current UAT.
- AI-safe tools are implemented locally but not live-deployed and role-matrix tested.

Do not call the lead lifecycle production-proven until these blockers are cleared.

## 21. Minimal Implementation Plan

Phase 1: enforce current fields

- Document canonical values in app and backend.
- Ensure every Edge Function writes one of the allowed values.
- Block direct frontend mutation of lifecycle fields.
- Add audit completeness checks for all protected transitions.

Phase 2: deterministic transition service

- Add a shared transition helper or RPC for lead lifecycle updates.
- Require from-state and to-state validation.
- Return stable reason codes on blocked transitions.
- Emit audit events in one place.

Phase 3: AI recommendation layer

- Use AI-safe tools to recommend next action only.
- Use deterministic scoring for cold/warm/hot.
- Require human confirmation for state changes.
- Log AI recommendation metadata without PII.

Phase 4: observability

- Build stuck lead dashboard.
- Track temperature drift.
- Track hot-lead follow-up delay.
- Track visit proof failure.
- Track lock creation rate.
- Track audit completeness.

## 22. Final Harsh Truth

Most CRMs store contacts and activities.

FutureTrust must store verified operational truth.

A lead is not valuable because it exists. A lead becomes valuable when the system can prove:

- who brought it,
- how it was protected,
- who worked it,
- what happened next,
- whether the buyer showed intent,
- whether the visit was verified,
- whether the broker lock was created,
- whether the audit trail can survive a dispute.

Until one real lead completes that full journey live, FutureTrust remains B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN.
