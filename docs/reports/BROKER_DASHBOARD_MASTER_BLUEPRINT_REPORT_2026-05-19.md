# Broker Dashboard Master Blueprint Report

Date: 2026-05-19
Project: FutureTrust - The Digital India Real Estate OS
Scope: Broker dashboard vision, backend contract, frontend logic, data resources, user flow, UX direction, and completion roadmap.

## 1. Executive Verdict

The broker dashboard must be built as a broker protection and business operating cockpit, not as a normal CRM screen.

Its main job is simple:

```text
Help the broker grow business while proving that every lead, call, visit, lock, and brokerage claim is protected.
```

For a broker like Jitu Gupta from JSN Enterprise, the dashboard should answer these questions in under 10 seconds:

- Are my leads protected?
- Which buyer needs action today?
- Who is handling my lead?
- Is call access active or expired?
- Has the site visit been proposed, scheduled, verified, or disputed?
- Is my 45-day broker lock active?
- Which brokerage is tracking, eligible, paid, blocked, or disputed?
- What should I do next to close more business?

The existing Flutter broker dashboard is the main production PWA surface. The Next.js `web-dashboard` broker page is currently a visual/prototype dashboard and should not be treated as the canonical production app until it is connected to the same live data contract.

## 2. Source Material Reviewed

Primary product and architecture sources:

- `docs/architecture/broker-dashboard-data-contract.md`
- `docs/reports/BROKER_DASHBOARD_COMPLETION_REPORT_2026-05-17.md`
- `docs/reports/A_Z_BROKER_DASHBOARD_STATUS_REPORT.md`
- `docs/reports/BROKER_DASHBOARD_LOGIC_REPORT.md`
- `docs/reports/BROKER_BUSINESS_VAULT_PREMIUM_REPORT.md`
- `docs/reports/FUTURETRUST_MASTER_BLUEPRINT_STRATEGY_SYNTHESIS_2026-05-19.md`
- `docs/reports/RLS_EXECUTION_SUMMARY.md`
- `docs/reports/ROLE_DASHBOARD_FINAL_VERIFICATION.md`

Primary frontend/runtime sources:

- `flutter_app/lib/screens/broker_dashboard_screen.dart`
- `flutter_app/lib/screens/broker_upload.dart`
- `flutter_app/lib/utils/training_runtime.dart`
- `web-dashboard/src/app/broker/page.tsx`
- `web-dashboard/src/components/BrokerDashboardFutureTrust.tsx`
- `web-dashboard/src/components/SecureLeadCard.tsx`
- `web-dashboard/src/components/LeadActionBottomSheet.tsx`
- `web-dashboard/src/components/ProposeSiteVisitSheet.tsx`

Primary backend sources:

- `supabase/functions/broker-upload-lead/index.ts`
- `supabase/functions/broker-vault-workflow/index.ts`
- `supabase/functions/data-loan-workflow/index.ts`
- `supabase/functions/broker-self-secure-call/index.ts`
- `supabase/migrations/20260519000000_broker_dashboard_hardening.sql`
- `supabase/migrations/20260518000000_fix_authenticated_broker_rls.sql`
- `supabase/migrations/20240518000000_broker_dashboard_access.sql`

## 3. Product Vision

The broker dashboard is the broker-facing trust vault of FutureTrust.

It should feel like a premium, simple, mobile-first business command center for Indian real estate brokers. It should protect the broker from attribution theft, reduce confusion with sourcing managers and callers, and turn every operational action into proof.

It is not:

- a lead marketplace,
- a phone-number list,
- a generic CRM table,
- a telecaller control panel,
- a developer sales dashboard,
- an AI chat screen.

It is:

- a broker business vault,
- a protected lead ledger,
- a site-visit proof tracker,
- a data-loan control panel,
- a brokerage attribution tracker,
- a daily action engine,
- a trust score and professional reputation surface.

## 4. Broker Jobs To Be Done

The dashboard must support these broker jobs:

1. Register a buyer lead without fear that the lead will be stolen.
2. See safe lead progress without seeing or exposing raw buyer contact data.
3. Know whether the caller or sourcing manager is acting on the lead.
4. Grant, extend, or revoke call access through governed data loans.
5. Propose a site visit and track approval.
6. Review visit proof where broker approval is required.
7. See when a verified visit creates a broker lock.
8. Track booking and brokerage status without chasing people on WhatsApp.
9. Raise an issue when attribution, proof, or payout looks wrong.
10. Build visible professional reputation through trust score, rank, verified visits, and performance history.

## 5. Core Promise To Broker

The dashboard should communicate this promise through the actual workflow, not just text:

```text
Your lead is not public property.
Your work is recorded.
Your attribution is protected.
Your payout claim has proof.
```

This is why the dashboard must never expose raw phone numbers, masked numbers, last digits, WhatsApp links, `tel:` links, or export buttons.

## 6. Current Implementation Reality

### 6.1 Flutter PWA Dashboard

The Flutter dashboard is the richer production surface. It already includes:

- broker identity card,
- trust score and rank,
- profile completion card,
- next action strip,
- KPI ribbon,
- growth cards,
- vault summary,
- lead cards,
- follow-ups,
- live projects,
- data loan/access status,
- visit and lock pipeline,
- booking/brokerage status,
- performance section,
- tips,
- recent safe activity,
- lead action sheets,
- site visit proposal sheet,
- quality picker,
- follow-up picker,
- booking stage sheet,
- brokerage status sheet,
- broker site visit review sheet.

It supports training mode through `TrainingRuntime` and live mode through Supabase reads and Edge Function mutations.

### 6.2 Next.js Web Dashboard

The Next.js dashboard is a visual prototype. It currently has:

- sticky trust header,
- KPI ribbon,
- broker identity card,
- growth insight card,
- secure lead cards,
- lead action bottom sheet,
- site visit proposal sheet.

It uses mock data in `BrokerDashboardFutureTrust.tsx`. It should be used for UI exploration, not final production logic, until it reads from the same data contract as Flutter.

### 6.3 Backend

The backend foundation exists:

- protected lead upload via `broker-upload-lead`,
- broker action routing via `broker-vault-workflow`,
- data loan governance via `data-loan-workflow`,
- secure call initiation via `broker-self-secure-call`,
- broker RLS hardening migrations,
- training runtime parity for key broker actions.

Exotel/provider details are intentionally deferred for this report per current instruction.

## 7. Critical Identity Mapping Issue

There is an important inconsistency that must be resolved before final live completion:

- Some current code uses `brokers_public.linked_user_id`.
- Some newer authenticated broker RLS work uses `brokers_public.owner_user_id`.
- `complete-onboarding` currently creates/looks up broker profiles using `linked_user_id`.
- `broker-upload-lead` currently looks up broker profiles using `owner_user_id`.
- Flutter live dashboard currently reads `brokers_public` using `linked_user_id`.

Final dashboard build must choose one canonical mapping or support a safe transitional mapping.

Recommended final decision:

```text
Canonical broker auth mapping: brokers_public.linked_user_id
Transitional compatibility: backfill owner_user_id = linked_user_id where needed, then remove new feature dependence on owner_user_id.
```

Reason: most broker dashboard contract, onboarding, role routing, and existing RLS helpers already use `linked_user_id`. If `owner_user_id` is kept, then onboarding, dashboard reads, RLS helper functions, and upload functions must all be changed together.

Do not complete the dashboard until this is normalized.

## 8. Backend Data Resources

The dashboard should read only safe metadata.

| Resource | Purpose | Broker-safe fields |
| --- | --- | --- |
| `brokers_public` | Broker identity | broker code, name/alias, company, area, city, RERA, trust score, rank, verified status |
| `broker_activations` | Broker-project relationship | project id, activation stage, assigned sourcing manager |
| `projects` | Project context | project name, area, city, status |
| `leads_public` | Protected lead metadata | alias, area, city, project/property, budget band, quality, lifecycle states, assignment ids |
| `leads_sensitive` | Encrypted PII vault | never queried by frontend |
| `data_loans` | Temporary call/site access | status, purpose, expiry, grantee id |
| `call_attempts` | Secure call metadata | provider, call status, outcome, timestamp |
| `broker_followups` | Broker follow-up queue | due date, priority, reason, status |
| `site_visit_proposals` | Visit proposal workflow | proposed time, status, project, safe notes, lead alias |
| `site_visits` | Visit proof workflow | status, scheduled time, broker review status, proof states |
| `site_visit_proofs` / confirmations | GPS/photo proof | proof status, storage path/hash metadata only |
| `broker_locks` | Attribution protection | lock status, start, expiry, brokerage status, lead alias |
| `broker_activity_logs` | Safe activity timeline | activity type, outcome, next follow-up, created time |
| `broker_goals` | Targets | target leads, target visits, active goal status |
| `audit_events` | Operational memory | event type, actor, safe IDs, timestamp |
| `abuse_events` | Duplicate/abuse evidence | event type, severity, safe evidence refs |

## 9. Frontend Data Contract

The dashboard should load one broker snapshot with these sections:

```text
BrokerDashboardSnapshot
  profile
  missing_profile_fields
  stats
  priority_actions
  growth_insights
  leads
  followups
  live_projects
  data_loans
  visit_proposals
  site_visits
  broker_locks
  booking_brokerage_rows
  activity
  permissions
```

Today, Flutter performs multiple table queries and isolates failures so one broken optional table does not crash the full dashboard. That is good for resilience.

Future recommendation:

```text
Create RPC: get_broker_dashboard_snapshot()
```

The RPC should return a single safe JSON object for the logged-in broker. It should:

- enforce `auth.uid()` inside SQL,
- use the canonical broker-user mapping,
- never include sensitive fields,
- return empty arrays for missing optional sections,
- include permission flags for actions,
- include stale/blocked reasons,
- simplify frontend code and improve speed.

## 10. Core Workflow Flow

### 10.1 Broker Login And Routing

```text
Supabase Auth login
-> role_assignments lookup
-> pilot_users fallback only if needed
-> broker_owner / broker_agent / broker routes to BrokerDashboardScreen
-> unknown or inactive routes to Access Restricted
```

Dashboard must fail closed:

- no auth user: no broker data,
- no broker profile: setup/blocked state,
- inactive broker: blocked state,
- missing permission: show disabled actions with reason,
- table query failure: section-level empty/error state, not PII fallback.

### 10.2 Secure Lead Upload

```text
Broker enters one-time phone + safe metadata
-> phone controller clears before/after submit
-> broker-upload-lead Edge Function
-> JWT user validation
-> broker role and permission validation
-> one-time contact encryption/hash
-> duplicate check
-> leads_public insert
-> leads_sensitive insert
-> audit event
-> safe response: lead_id + alias only
```

The dashboard must show the new lead as alias and metadata only. The raw phone must never come back into UI state.

### 10.3 Data Loan And Caller Assignment

```text
Broker selects lead
-> Assign Caller / Grant Access
-> data-loan-workflow or broker-vault-workflow
-> verify broker can use lead
-> verify grantee is active in same org
-> revoke existing active loan if needed
-> create time-bound data_loans row
-> update lead assignment state
-> audit data_loan_granted
```

Data loan states shown to broker:

- Active,
- Expired,
- Revoked,
- Inactive,
- Blocked.

### 10.4 Secure Call

```text
Broker or caller clicks Secure Call
-> Edge Function validates JWT, role, organization, lead access
-> validates active data loan, consent, DND
-> decrypts contact only in memory
-> creates call_attempts row
-> queues provider call
-> wipes memory reference
-> returns safe status
```

Exotel details are deferred here, but the dashboard should still represent the call state:

- queued,
- connecting,
- answered,
- missed,
- failed,
- blocked,
- expired,
- revoked,
- consent required.

### 10.5 Follow-Up

```text
Broker sets follow-up
-> broker-vault-workflow set_followup
-> leads_public.next_followup_at updated
-> conversion_stage = call_later
-> broker activity/audit row
-> priority strip updates
```

Follow-ups must be visible as a daily action queue, not buried in a table.

### 10.6 Site Visit Proposal

```text
Broker chooses lead + project + date/time + safe notes
-> propose-site-visit
-> site_visit_proposals row
-> assigned sourcing manager sees proposal
-> sourcing manager accepts/rejects/reschedules
-> accepted proposal creates scheduled site visit
```

Broker dashboard must show:

- proposed,
- accepted,
- scheduled,
- rescheduled,
- rejected,
- no-show,
- proof pending,
- verified,
- disputed.

### 10.7 Site Visit Proof And Review

```text
scheduled visit
-> start visit
-> GPS verification
-> photo proof
-> proof verification
-> broker review when required
-> visit_done / completed
```

Broker should not approve proof blindly. The dashboard should show proof status, timestamp, project, and lead alias. It should not show buyer contact details.

### 10.8 Broker Lock

```text
verified visit
-> broker_locks row
-> 45-day active attribution window
-> countdown visible to broker
-> brokerage status updates
```

The dashboard must make active locks highly visible because this is the core trust product.

### 10.9 Booking And Brokerage

Booking state and brokerage state are separate.

Recommended visible states:

```text
booking_stage:
  not_started
  booking_discussion
  token_discussion
  token_paid
  booking_confirmed
  loan_legal_started
  agreement_pending
  payment_pending
  closed
  lost

brokerage_status:
  tracking
  pending_visit
  locked
  eligible
  paid
  disputed
  blocked
```

Broker should always understand:

- what stage the buyer is in,
- what proof is missing,
- what blocks brokerage,
- what action can unblock it.

## 11. Dashboard Information Architecture

Recommended final dashboard order:

1. Trust header
2. Broker identity and profile completion
3. Today priority actions
4. KPI ribbon
5. Protected lead command center
6. Data loan / call access panel
7. Site visit proposal and proof pipeline
8. Broker lock ledger
9. Booking and brokerage tracker
10. Live projects and connected sourcing managers
11. Growth goals and business tips
12. Recent safe activity

This order matches broker urgency:

```text
Who am I? -> What needs action? -> Are my leads safe? -> Is my money protected?
```

## 12. Section Design Specification

### 12.1 Trust Header

Purpose:

- show broker name/company,
- show verified status,
- show trust score and rank,
- reassure that data is protected.

Must include:

- broker code,
- verified active badge,
- rank,
- trust score,
- profile status.

Avoid:

- marketing copy,
- large hero sections,
- generic greeting-only header.

### 12.2 Priority Action Strip

Purpose:

- make the dashboard deterministic.

Examples:

- "2 hot leads untouched for 24h."
- "3 call access windows expired."
- "1 verified visit pending your review."
- "1 booking discussion silent for 48h."

Each action should have:

- reason,
- affected count,
- recommended action,
- safe CTA.

### 12.3 KPI Ribbon

Core KPIs:

- Total Leads,
- Hot Leads,
- Warm Leads,
- Follow-ups Due,
- Calls Attempted,
- Interested Leads,
- Visits Proposed,
- Visits Scheduled,
- Verified Visits,
- Active Broker Locks,
- Booking Discussions,
- Brokerage Tracking,
- Data Loans Active.

KPIs must be counts only. They must not expose buyer identity.

### 12.4 Protected Lead Cards

Each lead card should show:

- lead alias,
- project/property,
- area/city,
- budget band,
- lead quality,
- buyer type,
- assigned to,
- data loan status,
- call status,
- follow-up,
- visit status,
- lock status,
- booking stage,
- brokerage status,
- next action.

Actions:

- Secure Call,
- Assign Caller,
- Assign Sourcing Manager,
- Grant Access,
- Extend Access,
- Revoke Access,
- Set Follow-up,
- Update Quality,
- Propose Visit,
- Review Visit,
- Update Booking Stage,
- Update Brokerage Status,
- Raise Issue.

### 12.5 Site Visit Pipeline

Show as a timeline:

```text
Proposed -> Accepted -> Scheduled -> GPS Verified -> Photo Uploaded -> Broker Review -> Verified -> Lock Active
```

Each row should show:

- lead alias,
- project,
- proposed/scheduled time,
- proof status,
- broker review status,
- lock outcome.

### 12.6 Broker Lock Ledger

Show:

- lead alias,
- project,
- lock status,
- start date,
- days remaining,
- expiry date,
- brokerage status.

Broker lock cards should be calm and clear. Active locks should be one of the first things a broker can find.

### 12.7 Booking And Brokerage Tracker

Show each booking row with:

- lead alias,
- booking stage,
- brokerage status,
- required next proof,
- last updated,
- safe action.

This protects the broker from "site visit done but no payout clarity" confusion.

### 12.8 Recent Safe Activity

Activity should be an audit-style timeline:

- lead submitted,
- caller assigned,
- access granted,
- call queued,
- follow-up set,
- visit proposed,
- proof uploaded,
- lock activated,
- issue raised.

No phone, no contact, no raw notes with PII.

## 13. UX Direction

The final dashboard should feel:

- smooth,
- premium,
- fast,
- mobile-first,
- easy for non-technical brokers,
- action-driven,
- trustworthy,
- not overloaded.

Design rules:

- Use clear cards for individual leads and locks.
- Use compact sections, not giant hero blocks.
- Use readable Hindi/English microcopy where it helps field users.
- Use bottom sheets for complex actions on mobile.
- Use icons for repeated actions.
- Use tabs or segmented controls for lead filters.
- Use status chips consistently.
- Keep every CTA tied to a workflow action.
- Never show "AI magic" as primary UI.
- Never show hidden implementation text inside the app.

Recommended tone:

```text
Protected, clear, business-first.
```

Avoid:

- cluttered CRM tables on mobile,
- raw database labels,
- long paragraphs,
- vague AI recommendations,
- dark UI with low contrast,
- single-color dashboard theme,
- hidden failed states,
- fake completion language.

## 14. Broker-Friendly Microcopy

Good examples:

- "Lead protected in vault."
- "Call access active until 5:00 PM."
- "Visit proof pending."
- "Broker lock active: 32 days left."
- "Brokerage tracking."
- "Action needed: renew call access."
- "No phone is shown. Calls use secure bridge."

Avoid:

- "CRM status updated."
- "Mutation succeeded."
- "LLM recommendation."
- "Data row unavailable."
- "User not authorized" without a human reason.

## 15. Security Constitution For Dashboard

The broker dashboard must never render:

- raw phone,
- masked phone,
- last four digits,
- email,
- WhatsApp link,
- `tel:` link,
- contact export,
- `leads_sensitive`,
- `brokers_sensitive`,
- provider callback payloads,
- secret keys,
- raw internal errors.

All protected actions must go through:

```text
Frontend CTA
-> Edge Function
-> JWT user
-> active org/user check
-> broker/role permission check
-> workflow state check
-> service-role write
-> audit event
-> safe response
```

## 16. RLS And Permission Model

Broker dashboard reads must be isolated by linked broker identity.

Required policies:

- broker reads only own `brokers_public` row,
- broker reads only `leads_public` where source broker matches broker id,
- broker reads only own `site_visit_proposals`,
- broker reads only own `site_visits`,
- broker reads only own `broker_locks`,
- broker reads only data loans attached to broker-visible lead ids,
- broker reads only own `broker_followups`,
- broker reads only own `broker_activity_logs`,
- broker reads only own active `broker_goals`.

Frontend must not trust role claims from the client. Role and permission decisions must come from Supabase auth, role assignment tables, RLS, and Edge Functions.

## 17. Audit Architecture

Every sensitive dashboard action must write audit/activity memory.

Required audit event examples:

- `broker_vault_lead_submitted`
- `lead_uploaded`
- `data_loan_granted`
- `data_loan_revoked`
- `data_loan_extended`
- `broker_self_call_queued`
- `broker_self_call_blocked`
- `lead_assigned_to_caller`
- `lead_assigned_to_sm`
- `broker_followup_set`
- `site_visit_proposed`
- `site_visit_accepted`
- `site_photo_uploaded`
- `visit_done`
- `broker_lock_activated`
- `booking_stage_updated`
- `brokerage_status_updated`
- `broker_issue_raised`

Audit payloads should contain IDs, aliases, statuses, and workflow metadata only.

## 18. AI-Safe Future Layer

AI can support the broker dashboard only as a metadata assistant.

Allowed:

- summarize safe lead metadata,
- recommend next action,
- explain why access is blocked,
- prioritize follow-ups,
- classify lead quality from safe metadata,
- surface stale work,
- draft safe call scripts.

Not allowed:

- read/decrypt phone,
- approve visit proof,
- create broker lock,
- approve brokerage payout,
- bypass RLS,
- mutate workflow state directly,
- generate spam outreach.

Recommended future UI:

```text
Smart Tip Card
Next Action Reason
Follow-Up Risk Card
Broker Lock Explanation
Lead Quality Explanation
```

## 19. What The Dashboard Can Do For Broker

The dashboard helps the broker in practical ways:

1. Protects attribution by recording lead source and visit proof.
2. Reduces lead theft fear because the buyer contact is not exposed to open users.
3. Gives a daily work plan instead of random CRM browsing.
4. Shows which caller or sourcing manager is responsible.
5. Controls who can call the buyer and for how long.
6. Proves site visit progress with status and audit records.
7. Shows active broker locks and countdown.
8. Builds broker reputation through score, rank, verified visits, and activity.
9. Reduces WhatsApp chasing by showing booking/brokerage state.
10. Gives a dispute path when credit or proof is unclear.

## 20. Final Build Roadmap

### Phase 0 - Normalize Backend Identity

Goal: remove `linked_user_id` vs `owner_user_id` confusion.

Tasks:

- choose canonical broker-user column,
- update `complete-onboarding`,
- update `broker-upload-lead`,
- update Flutter dashboard live queries,
- update RLS helper `is_linked_broker_user`,
- backfill existing broker rows,
- update dashboard data contract.

Exit criteria:

- real broker signup creates the same linked field the dashboard reads,
- lead upload finds the same broker profile,
- RLS helper returns true for the real broker user.

### Phase 1 - Create Snapshot Read Layer

Goal: make dashboard fast and deterministic.

Tasks:

- create `get_broker_dashboard_snapshot()` RPC or Edge Function,
- return all safe dashboard sections in one JSON payload,
- include permission flags and blocked reasons,
- add tests that snapshot contains no PII,
- keep section-level empty states.

Exit criteria:

- Flutter dashboard can render from one safe snapshot,
- no direct frontend sensitive table reads,
- empty optional sections do not crash.

### Phase 2 - Smooth Mobile UI

Goal: make dashboard easy for brokers on phone.

Tasks:

- polish identity card,
- make priority strip sticky or first visible,
- simplify KPI ribbon,
- make lead cards compact and scannable,
- improve bottom sheets,
- add filters: Hot, Follow-up, Visit, Lock, Booking,
- ensure no horizontal overflow,
- improve empty/blocked states.

Exit criteria:

- broker can find next action in under 10 seconds,
- all buttons are reachable on small screens,
- no text overflow on mobile,
- no confusing technical labels.

### Phase 3 - Complete Action Matrix

Goal: every dashboard CTA either works or fails closed with clear reason.

Tasks:

- Secure Call,
- Assign Caller,
- Assign SM,
- Grant Access,
- Extend Access,
- Revoke Access,
- Set Follow-up,
- Update Lead Quality,
- Propose Visit,
- Review Visit,
- Update Booking Stage,
- Update Brokerage Status,
- Raise Issue.

Exit criteria:

- each action has training parity,
- each live action uses Edge Function,
- each action writes audit/activity,
- UI refreshes state after success.

### Phase 4 - Broker Lock And Brokerage UX

Goal: make attribution protection obvious.

Tasks:

- build lock ledger,
- show 45-day countdown,
- show proof chain that created lock,
- show brokerage blockers,
- show dispute status,
- show payout eligibility only when backend says eligible.

Exit criteria:

- broker understands why a lock exists,
- broker understands why brokerage is not yet eligible,
- no lock can be displayed as active without verified proof data.

### Phase 5 - Final UAT And Release Gate

Goal: prove real broker dashboard works in target environment.

Tasks:

- broker login UAT,
- RLS isolation UAT,
- secure lead upload UAT,
- data loan UAT,
- site visit proposal UAT,
- proof/lock UAT,
- audit review,
- mobile layout screenshots,
- build/typecheck/security gates.

Exit criteria:

- real broker sees only own safe rows,
- no PII appears in dashboard,
- all protected actions audited,
- release gate passes.

## 21. Acceptance Checklist

Dashboard can be called complete only when:

- broker owner and broker agent roles route correctly,
- broker profile missing shows setup/blocked state,
- broker can add a secure lead,
- phone is encrypted and cleared from UI,
- dashboard shows alias/metadata only,
- data loan actions work,
- secure call action fails closed when loan/consent/provider config is missing,
- follow-up action works,
- site visit proposal works,
- broker can review verified visit where required,
- broker lock ledger shows active/expired locks,
- booking and brokerage states are visible,
- issue raising works,
- audit/activity rows are written,
- no direct sensitive table reads exist,
- no phone/WhatsApp/tel/export appears,
- mobile layout has no overflow,
- training mode and live mode do not silently mix,
- `npm run build` passes,
- `npx tsc --noEmit` passes or is documented as not applicable by repo rules,
- security scan passes.

## 22. Recommended Immediate Next Build Tasks

1. Fix the broker identity mapping inconsistency.
2. Update `broker-dashboard-data-contract.md` after identity decision.
3. Build a safe broker dashboard snapshot function or RPC.
4. Refactor Flutter dashboard reads toward the snapshot.
5. Keep the current Flutter section set, but simplify the top mobile experience.
6. Wire all action buttons to deterministic Edge Function responses.
7. Add mobile/browser checks for no PII, no overflow, and key action sheets.
8. Keep Next.js broker dashboard as prototype unless explicitly selected as the new production web dashboard.

## 23. Final Product Definition

The finished broker dashboard should be described as:

```text
A mobile-first broker business vault that protects lead attribution, governs call access, tracks site-visit proof, shows broker locks, and gives brokers a simple daily action plan without exposing buyer contact data.
```

That is the correct north star for completing the dashboard.

