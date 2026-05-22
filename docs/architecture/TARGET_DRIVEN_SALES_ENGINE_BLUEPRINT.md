# Target-Driven Sales Engine Blueprint

## 1. Executive Summary

The Sourcing Manager OS should move from a CRM-style dashboard to a target-driven Indian real estate sales engine focused on one field-pilot loop:

Vinod activates brokers -> brokers submit leads -> Vinod assigns leads to caller -> caller updates outcome through Secure Call -> interested leads return to Vinod -> Vinod schedules site visit -> GPS/photo verifies walk-in -> broker performance and credit lock update.

This blueprint does not add future AI, loan, payment, legal, possession, WhatsApp, or marketplace modules. The priority is broker -> caller -> site visit execution with daily targets, smart priorities, safe follow-ups, and proof-based reporting.

Current implementation status:

- Premium dashboards: PARTIAL. SM, Broker, Caller dashboards exist and use dark ERP styling, KPI cards, Hinglish helper text, and safe metadata.
- Sourcing goals/tasks: PARTIAL. `sourcing_goals` and `sourcing_tasks` exist for sourcing managers, but they are monthly and not yet role-wide daily target engines.
- Caller workflow: PARTIAL. Protected Edge Function `manage-caller-workflow` supports assignment and call outcome actions.
- Broker workflow: PARTIAL. `manage-external-broker` supports safe broker metadata, follow-ups, and activity logging.
- Site visit proof flow: PARTIAL. Site visit, GPS, photo, and broker review functions exist, but real field-provider verification still needs full gate testing.
- Security posture: STRONG BASELINE. Sensitive tables remain backend-only by design, and current frontend checks show no direct sensitive table query.

Final product goal:

- Every user should open the app and immediately know: today's target, what is pending, what is blocked, what is verified, and the next best action.

## 2. Non-Negotiable Security Constitution

All target, priority, automation, and report surfaces must follow these rules:

- No phone number in UI.
- No masked phone.
- No last four.
- No WhatsApp link.
- No browser `tel:` link.
- No contact export.
- No raw provider payload in logs.
- No phone/contact value in audit events.
- Frontend never queries `leads_sensitive`.
- Frontend never queries `brokers_sensitive`.
- Protected writes go through Edge Functions or RPCs.
- RLS stays enabled on operational and sensitive tables.
- System fails closed when role, organization, permission, assignment, data loan, or consent checks fail.

If phone/contact data appears in UI, browser network response, report, audit event, or public table, stop and report: "This violates the system constitution."

## 3. Goal Engine Design

### 3.1 Goal Objects

Add a role-wide goal layer, not only sourcing-manager monthly goals.

Recommended table: `public.sales_targets`

Safe fields:

- `id uuid primary key`
- `organization_id uuid not null`
- `user_id uuid null`
- `role_id text not null`
- `target_date date not null`
- `period text check in ('daily', 'weekly', 'monthly')`
- `metric_id text not null`
- `target_value integer not null`
- `status text check in ('active', 'completed', 'cancelled')`
- `created_by uuid`
- `created_at timestamptz`
- `updated_at timestamptz`
- `metadata jsonb default '{}'`

No contact fields. No customer names required.

Recommended metric ids:

Sourcing manager:

- `broker_calls_target`
- `leads_received_target`
- `site_visits_target`
- `followup_completion_target`
- `broker_activations_target`

Broker:

- `lead_submission_target`
- `site_visit_target`
- `verified_visit_target`
- `review_completion_target`

Caller:

- `assigned_call_target`
- `connected_call_target`
- `interested_lead_target`
- `call_later_completion_target`

### 3.2 Goal Progress

Progress should be computed from operational tables, not manually stored unless cached.

Recommended view/RPC: `get_role_scorecard(p_user_id, p_target_date)`

Return only safe metadata:

- target metric
- target value
- actual value
- percent complete
- status color
- blocked count
- next action label

Current table mapping:

- broker calls: `call_attempts` where call target is broker call attempts or broker activity logs with secure call event
- leads received: `leads_public` by `assigned_sourcing_manager_id` or `source_broker_id`
- site visits scheduled: `site_visits` status in scheduled states
- verified visits: `site_visits` verified/completed states
- follow-up completion: `broker_followups`
- caller assigned calls: `leads_public.assigned_caller_id`
- caller connected calls: `call_attempts.call_status`
- interested leads: `leads_public.last_call_outcome = 'interested'`

### 3.3 UI Pattern

Each dashboard should show a "Today Target" section at the top:

- 3 to 4 large progress cards.
- Progress bar and percent.
- "Pending", "Blocked", and "Verified" counters.
- One primary action per card.
- Hinglish helper copy, for example: "Aaj ka target yahin se clear karo. Number screen par kabhi nahi dikhega."

## 4. Smart Priority Engine

### 4.1 Priority Model

Add a generated priority queue that converts operational gaps into next actions.

Recommended table or materialized view: `public.safe_priority_items`

Fields:

- `id uuid`
- `organization_id uuid`
- `role_id text`
- `assigned_to uuid`
- `priority_type text`
- `entity_type text`
- `entity_id uuid`
- `safe_title text`
- `safe_subtitle text`
- `reason_code text`
- `urgency_score integer`
- `due_at timestamptz`
- `status text`
- `created_at timestamptz`
- `metadata jsonb`

No contact fields. Use aliases, statuses, project, area, and safe notes only.

Writes should happen through Edge Function `run-priority-engine` or database scheduled job with service context. Frontend should read a safe view scoped by RLS.

### 4.2 Sourcing Manager Priorities

Priority rules:

- Hot brokers needing follow-up:
  - broker category = `hot`
  - no completed activity since last follow-up
  - due follow-up exists or next follow-up overdue
- Brokers with pending leads:
  - activation stage = `lead_expected`
  - no lead received in 2 days
- Interested leads without site visits:
  - last outcome = `interested`
  - no scheduled site visit in 24 hours
- Visits pending confirmation:
  - site visit scheduled/arrived/GPS verified/photo verified but not completed

Expected SM priority card:

- safe broker/lead alias
- project
- area
- due time
- reason
- action button: Secure Call, Assign Caller, Schedule Visit, Review Proof

### 4.3 Broker Priorities

Priority rules:

- Leads needing call access:
  - broker lead created but no active data loan
- Data loans expired:
  - data loan expired or revoked and lead still actionable
- Visits pending:
  - source broker has scheduled or proof-pending site visits
- Broker review pending:
  - photo verified visit waiting for broker approval

Expected broker priority card:

- lead alias
- project
- visit/call status
- permission status
- action: Grant Call Access, Renew Loan, Review Visit, Raise Issue

### 4.4 Caller Priorities

Priority rules:

- Hot leads first:
  - call priority urgent/high
  - source broker or SM priority high
- Call-later leads due:
  - last outcome = `call_later`
  - next follow-up at or before now
- Interested leads needing second call:
  - interested outcome but no site visit scheduled and SM has not acted

Expected caller priority card:

- lead alias
- source broker safe alias/company
- project and area
- budget band
- suggested call reason
- outcome shortcuts
- Secure Call button sends `lead_id` only

## 5. Follow-Up Automation

Follow-up automation must create safe work items, not messages or contact links.

### 5.1 Broker Follow-Up

Rule:

- If broker stage is `interested` or `lead_expected`
- and no lead received in 2 days
- create broker follow-up: "Call broker for lead update"

Backend:

- Edge Function: `run-followup-engine`
- Writes: `broker_followups`, `safe_priority_items`, `audit_events`
- Idempotency key: `broker_id + rule_id + due_date`

### 5.2 Caller Follow-Up

Rule:

- If outcome = `call_later`
- and `next_followup_at` exists
- show lead in caller queue at due time

Backend:

- Source: `leads_public.last_call_outcome`, `broker_activity_logs.next_followup_at`, or dedicated `lead_followups`
- Caller sees lead alias only.

### 5.3 Interested Lead Reminder

Rule:

- If lead status/outcome = `interested`
- and no site visit scheduled in 24 hours
- create reminder: "Schedule site visit"

Backend:

- Writes SM priority item.
- Optional `sourcing_tasks` row for Vinod.

### 5.4 Site Visit Reminder

Rule:

- If site visit scheduled and visit time is within next 24 hours
- show SM/caller/broker safe reminder based on assignment and role.

No location or photo path should be public beyond safe status.

### 5.5 Broker Review Reminder

Rule:

- If visit status = `photo_verified`
- and broker review status is pending
- create reminder: "Broker approval required"

### 5.6 Data Loan Expiry Reminder

Rule:

- If data loan expires
- secure call is blocked
- SM or broker can renew only if permission allows

Frontend:

- Show "Call access expired" or "Renew access"
- Never show contact details.

## 6. Business Improvement Tips

Tips must be deterministic and based on safe aggregated metadata. Do not use future AI yet.

### 6.1 Broker Dashboard Tips

Show:

- strongest area
- best project
- lead-to-visit conversion
- pending leads
- improvement suggestion

Deterministic examples:

- "Mira Road is your strongest area this month."
- "Wadhwa Wise City is producing the most verified visits."
- "3 leads are waiting for caller access. Grant access to move faster."
- "Your lead-to-visit conversion is below target. Submit cleaner budget and area notes."

Backend:

- Safe view: `broker_safe_performance_summary`
- Inputs: `leads_public`, `site_visits`, `broker_locks`, `data_loans`, `broker_activity_logs`
- Outputs: counts, ratios, statuses, aliases only.

### 6.2 Sourcing Manager Dashboard Tips

Show:

- daily target
- priority brokers
- bottlenecks
- top brokers
- monthly achievement

Deterministic examples:

- "2 hot brokers have no follow-up today."
- "Interested leads are waiting for site visit scheduling."
- "Top broker this month: Jitu Gupta / JSN Enterprise."
- "Monthly verified visits are below target."

### 6.3 Caller Dashboard Tips

Show:

- priority queue
- suggested call reason
- outcome shortcuts
- follow-up reminders

Deterministic examples:

- "Call hot leads first."
- "This lead asked for call later. Follow-up is due."
- "Mark outcome immediately after call."

## 7. Dashboard Changes

### 7.1 Sourcing Manager Dashboard

Add first-screen sections:

- Today Target
- Priority Brokers
- Interested Leads Without Visit
- Visit Proof Pending
- Bottlenecks
- Top Brokers
- Monthly Achievement

KPI cards:

- Broker Calls Today
- Leads Received Today
- Site Visits Scheduled
- Follow-ups Completed
- Hot Brokers
- Interested Leads Pending Visit
- Verified Visits This Month
- Top Broker

Primary actions:

- Secure Call Broker
- Add Lead From Broker
- Assign Lead To Caller
- Schedule Site Visit
- Review Visit Proof

### 7.2 Broker Dashboard

Add first-screen sections:

- My Target
- Pending Lead Actions
- Data Loan / Call Access
- Visit Status
- Broker Lock / Credit Status
- Improvement Tips

KPI cards:

- Leads Submitted
- Calls Attempted On My Leads
- Interested Leads
- Site Visits Scheduled
- Verified Visits
- Active Locks
- Trust Score
- Lead-to-Visit Conversion

Primary actions:

- Submit Lead
- Grant Call Access
- Renew Call Access
- Review Visit
- Raise Issue

### 7.3 Caller Dashboard

Add first-screen sections:

- Today Target
- Priority Queue
- Call Later Due
- Interested Leads Needing Follow-up
- Outcome Shortcuts

KPI cards:

- Assigned Calls
- Pending Calls
- Connected Calls
- Interested Leads
- Follow-ups Due
- Visit Scheduled Leads

Primary actions:

- Secure Call
- Mark Interested
- Mark Not Interested
- Mark Call Later
- Mark Not Reachable
- Handoff To SM

### 7.4 Admin / Developer Dashboard

Add first-screen sections:

- Organization Target Health
- Project-wise Walk-ins
- Broker ROI
- Caller Productivity
- Risk Alerts
- System Health

Counts only. No contact data.

## 8. Premium UI Requirements

Use the existing dark ERP language and extend it consistently.

UI requirements:

- dark charcoal background
- gold/orange primary accents
- green verified/completed
- orange pending/follow-up
- red blocked/expired
- blue scheduled/assigned
- grey inactive/dead
- purple hot/high potential
- progress bars for targets
- priority action cards
- Kanban for broker activation
- dense but readable tables
- 48-56 px primary buttons
- 44-48 px card buttons
- mobile-first spacing
- no nested cards
- no phone/contact labels except protected input forms where required

Every screen must answer:

- What is my target today?
- What should I do next?
- What is pending?
- What is blocked?
- What is verified?
- Who is performing?

## 9. Report System

Reports should be generated from safe views/RPCs.

### 9.1 Sourcing Manager Report

Inputs:

- broker follow-ups
- broker activations
- leads received
- assigned caller outcomes
- site visits scheduled/verified
- broker locks

Outputs:

- target achievement
- broker activation rate
- lead-to-visit rate
- pending actions
- top brokers
- bottlenecks

### 9.2 Broker Report

Inputs:

- broker-sourced leads
- call attempts count
- data loan status
- site visit status
- broker locks
- trust score

Outputs:

- leads submitted
- calls attempted on broker leads
- verified visits
- active locks
- strongest area
- best project
- improvement suggestion

### 9.3 Caller Report

Inputs:

- assigned leads
- call attempts
- outcomes
- call-later follow-ups
- visit scheduled handoffs

Outputs:

- target achievement
- connected calls
- interested leads
- pending calls
- follow-up misses
- productivity trend

### 9.4 Developer / Admin Report

Inputs:

- organizations
- projects
- brokers_public
- leads_public
- call_attempts
- site_visits
- broker_locks
- safe audit events

Outputs:

- project-wise walk-ins
- verified broker ROI
- sourcing manager performance
- caller productivity
- risk alerts
- system health

## 10. Backend Data Requirements

### 10.1 Tables To Add Or Extend

Add:

- `sales_targets`
- `safe_priority_items`
- `lead_followups` if current lead follow-up state cannot be modeled safely from `leads_public`
- `daily_role_scorecards` as optional cached aggregate
- `safe_report_snapshots` for immutable generated reports

Extend:

- `sourcing_goals` or migrate it into `sales_targets`
- `sourcing_tasks` to include `source_rule_id`, `entity_type`, `entity_id`, `completed_at`
- `broker_followups` to include rule/idempotency metadata
- `leads_public` to normalize `next_followup_at` if lead followups remain on lead rows

Do not add phone/contact columns to public tables.

### 10.2 Edge Functions / RPCs

Add:

- `get-role-scorecard`
- `run-priority-engine`
- `run-followup-engine`
- `complete-priority-item`
- `generate-safe-role-report`

Harden existing:

- `manage-caller-workflow`
- `manage-external-broker`
- `lead-from-broker`
- `create-site-visit`
- `initiate-call`
- `initiate-broker-call`
- `verify-site-gps`
- `upload-site-photo`
- `broker-review-site-visit`

All writes must require:

- authenticated user
- active user status
- active organization
- role permission
- assignment check
- idempotency key where duplicate actions can happen
- safe audit event

### 10.3 Indexes

Recommended indexes:

- `sales_targets(organization_id, role_id, target_date, status)`
- `sales_targets(user_id, target_date, metric_id)`
- `safe_priority_items(assigned_to, status, urgency_score desc, due_at asc)`
- `safe_priority_items(organization_id, role_id, status, due_at)`
- `broker_followups(assigned_to, status, due_at)`
- `leads_public(assigned_caller_id, lead_status, last_call_outcome)`
- `leads_public(assigned_sourcing_manager_id, created_at desc)`
- `site_visits(sourcing_manager_id, status, scheduled_at)`
- `site_visits(source_broker_id, status, scheduled_at)`
- `data_loans(granted_to_user_id, lead_id, status, expires_at)`

### 10.4 RLS Requirements

Use default deny.

RLS pattern:

- users read their own targets and priorities
- managers read assigned broker/lead/site-visit safe metadata
- brokers read only their own broker-sourced safe metadata
- callers read only assigned leads and active loan safe metadata
- admins read org-level safe aggregates

Use `SECURITY DEFINER` helpers carefully to avoid recursive RLS policies. Do not query a table from inside its own policy unless through a proven non-recursive helper.

## 11. Security Risks And Controls

Risk: target dashboards accidentally expose operational contact data.

Control:

- reports read safe views only
- frontend grep blocks sensitive table names
- no public contact columns

Risk: priority engine creates duplicate reminders.

Control:

- deterministic idempotency key per rule/entity/date
- unique constraint on active generated work item

Risk: stale data loans allow calls.

Control:

- secure call function checks active loan at call time
- expired/revoked loans return blocked state

Risk: audit events receive contact text through notes.

Control:

- sanitize notes in Edge Functions
- reject or scrub phone-like patterns
- write only ids, aliases, statuses, reason codes

Risk: frontend bypasses protected actions.

Control:

- RLS denies direct protected writes
- Edge Functions/RPCs enforce permission and assignment checks

Risk: Training Mode confuses production state.

Control:

- default Training Mode OFF for configured Supabase builds
- persist user training preference locally
- show training banner only when dashboard is demo/mock

## 12. Critical Flow Gate

Do not mark field pilot ready until these pass against the live Supabase project and real provider configuration:

- Assign Lead To Caller: PARTIAL. Existing smoke test and Edge Function path exist; live role/org/idempotency path needs full real-data test.
- Caller Outcome Update: PARTIAL. Existing smoke test and Edge Function path exist; live terminal status and loan revocation behavior need verification.
- Schedule Site Visit: PARTIAL. Existing code path exists; live workflow must prove broker/source attribution.
- Exotel Real Broker Call: NOT VERIFIED in this blueprint. Requires configured provider secrets and real bridge test without logging contact data.
- Exotel Real Customer Call: NOT VERIFIED in this blueprint. Requires active data loan and provider bridge test.
- GPS Verification: PARTIAL. Functions exist; live geofence test still required.
- Photo Upload: PARTIAL. Functions exist; private bucket and safe path checks still required.
- Broker Lock: PARTIAL. Triggers/functions exist; live verified visit to lock creation test still required.
- No Phone Exposure: MUST PASS in every UI, network, audit, and public table test.

## 13. Implementation Phases

### Phase 1 - Target Engine MVP

- Add `sales_targets`.
- Add `safe_priority_items`.
- Add target scorecard RPC.
- Add deterministic follow-up engine.
- Add first-screen target cards to SM, Broker, Caller dashboards.

### Phase 2 - Priority Workflows

- Add role-specific priority lists.
- Add complete/dismiss/defer actions through Edge Functions.
- Add idempotency for generated priorities.
- Add bottleneck section to SM dashboard.

### Phase 3 - Safe Reports

- Add safe report views/RPCs.
- Add report screens for SM, Broker, Caller, Admin.
- Add CSV/PDF only if export contains safe aggregate metadata and no contact data.

### Phase 4 - Field Gate Verification

- Live assign lead to caller.
- Live secure call attempt with active loan.
- Live caller outcome.
- Live site visit schedule.
- Live GPS/photo proof.
- Live broker review.
- Live broker lock.
- Browser/network/audit public-table no-contact scan.

## 14. Build/Test Status

Fresh verification from this work session:

- `python scripts/security-check.py`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build web --release`: PASS
- `flutter build apk --release`: PASS
- `npm run build`: PASS
- `npx tsc --noEmit`: NOT APPLICABLE / FAILS because TypeScript is not installed at the repo root. This repository is Flutter plus Supabase Edge Functions, and the project guidance states Edge Functions are Deno/Supabase CLI managed rather than root `tsc` managed.

Fix applied during verification:

- Restored missing `_interestedLeads` state in `SourcingManagerDashboard`.
- Updated the task priority dropdown from deprecated `value` to `initialValue`.
- Added a `context.mounted` guard before popping the task dialog after an async insert.

## 15. Final Verdict

C. PARTIAL - FIX LIST REQUIRED

Reason:

The target-driven sales engine design is ready, and the app has strong MVP foundations. It is not field-pilot complete until the role-wide goal engine, priority engine, follow-up automation, safe reports, and live protected flow gate are implemented and verified end to end.
