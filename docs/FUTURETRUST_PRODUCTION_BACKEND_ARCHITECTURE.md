# FutureTrust Production Backend Architecture

Date: 2026-05-19
Project: FutureTrust, The Digital India Real Estate OS
Repository: The Sourcing Manager OS
Status: Production trust-infrastructure blueprint aligned to the current Supabase backend

## Executive Position

FutureTrust is not a CRM. It is a governed real-estate operating system where the backend preserves attribution, workflow memory, proof, privacy, and audit continuity. A lead is not treated as a contact row. A lead is a protected workflow object whose buyer identity is kept in a vault, whose public metadata drives operations, and whose transitions are only accepted through role-governed Edge Functions or service-role RPCs.

The system must fail closed. If permission, data loan, provider validation, proof evidence, encryption, audit writing, or organization state cannot be verified, the backend must reject the action and leave an auditable safe failure event.

## 1. Full Backend Folder Structure

Current production-aligned structure:

```text
supabase/
  config.toml                         # Function registry, JWT posture, auth config
  migrations/
    20240504000000_sprint1_foundation.sql
    20240504000100_sprint2_verification.sql
    20240506000000_sprint3_operations.sql
    20240507000000_sprint4_operational_visibility.sql
    20240508000000_sprint5_scaling.sql
    20240509000000_sprint6_compliance.sql
    20240510000000_sprint7_enterprise.sql
    20240514000000_practical_mvp_crm.sql
    20240516000000_caller_workflow_support.sql
    20240517000200_caller_assignment_security.sql
    20240520000000_duplicate_lead_prevention.sql
    20260507000600_site_visit_proposal_confirmation.sql
    20260509000100_phase3_inventory_erp.sql
    20260510000200_harden_broker_locks.sql
    20260512000100_harden_exotel_callback_replay.sql
    20260512000200_harden_trust_loop_isolation_policies.sql
    20260516000100_ai_data_churn_engine.sql
    20260519000100_scheduled_trust_infrastructure.sql
  functions/
    _shared/
      sprint7.ts                      # Shared auth, permissions, audit, hashing helpers
    accept-invite/
    activate-user/
    assign-role/
    complete-onboarding/
    broker-upload-lead/
    broker-vault-workflow/
    lead-from-broker/
    manage-external-broker/
    manage-caller-workflow/
    data-loan-workflow/
    initiate-call/
    initiate-broker-call/
    broker-self-secure-call/
    exotel-callback/
    propose-site-visit/
    review-site-visit-proposal/
    create-site-visit/
    start-site-visit/
    confirm-site-visit-arrival/
    verify-site-gps/
    upload-site-photo/
    verify-site-visit-proof/
    broker-review-site-visit/
    trust-get-lead-summary/
    trust-get-broker-lock-status/
    trust-get-followup-risk/
    trust-get-site-visit-proof/
    trust-create-followup/
    trust-recommend-next-action/
    check-rate-limit/
    flag-abuse-event/
    resolve-abuse-event/
    incident-response/
    generate-risk-summary/
    calculate-trust-score/
    run-trust-decay/
    run-payout-eligibility/
    generate-payout-statement/
    system-health-check/
    route-incoming-leads/
```

Target next folder split, without redesigning runtime architecture:

```text
supabase/
  migrations/
    domains/
      identity.sql
      lead-vault.sql
      broker-os.sql
      caller-workforce.sql
      site-visits.sql
      audit-risk.sql
      developer-governance.sql
  functions/
    _shared/
      auth.ts
      audit.ts
      permissions.ts
      pii.ts
      provider.ts
      workflow.ts
    lead-vault/
    caller-workforce/
    broker-os/
    site-visits/
    ai-safe-tools/
    risk-abuse/
```

This target split is an organizational roadmap only. Existing deployed function names should remain stable until a versioned migration plan exists.

## 2. Database Schema Architecture

### Identity Layer

Primary tables:

- `organizations`: tenant boundary and operational status.
- `pilot_users`: active user membership, role, org, pilot status.
- `role_definitions`: canonical backend roles.
- `permission_definitions`: canonical backend permissions.
- `role_permissions`: default role-permission map.
- `role_assignments`: assigned user roles where present in later hardening.
- `user_profiles`: non-sensitive user metadata.
- `organization_invites`: governed invite flow.
- `user_suspensions`: fail-closed suspension layer.

Rules:

- Every protected function must resolve user identity from Supabase Auth, then fetch backend role and organization from tables.
- Frontend role claims are advisory only and must never authorize protected actions.
- Paused organizations, inactive pilot users, and suspended users fail closed.

### Organization Layer

`organizations` is the tenant root. Every operational row that can leak workflow or attribution context must carry `organization_id`, either directly or through a lead, broker, visit, or project relation.

Organization state controls:

- `active`: workflows allowed.
- `paused`: user-visible reads may continue by policy, but new protected mutations are blocked.
- `suspended`: protected reads and writes should be denied except platform/compliance investigation actions.

### Broker OS

Primary tables:

- `brokers_public`: safe broker metadata, assignment, category, RERA fields.
- `brokers_sensitive`: encrypted broker phone/email only, no client SELECT.
- `broker_activations`: project activation pipeline.
- `broker_activity_logs`: safe operational history.
- `broker_followups`: broker follow-up queue.
- `broker_goals`: broker performance targets.
- `broker_issues`: broker-raised attribution, proof, or payout issues.
- `broker_locks`: protected attribution window.

Broker-owned data is isolated by broker user linkage, assigned sourcing manager, and organization membership. Broker data never falls into a common pool unless a governance rule explicitly releases it after expiry, revocation, dispute resolution, or broker opt-in.

### Caller Workforce

Primary tables:

- `caller_profiles`: caller identity and operational capability, if enabled by role-specific onboarding.
- `data_loans`: time-bound access grants.
- `call_attempts`: provider-neutral call metadata.
- `call_outcomes`: target domain object; current implementation stores outcomes in `call_attempts` and safe lead fields.
- `caller_goals`: caller productivity targets.

Callers never own lead data. They receive temporary queue visibility and can initiate a secure call only when an active data loan, permission, consent, and workflow state all pass.

### Sourcing Manager Operations

Primary tables:

- `sourcing_managers_public`: role-specific SM metadata where enabled.
- `sourcing_goals`: manager targets.
- `sourcing_tasks`: task queue.
- `broker_activations`: activation pipeline.
- `broker_followups`: follow-up queue.
- `site_visit_proposals`, `site_visits`, `site_visit_confirmations`: visit operations.

The sourcing manager coordinates work but does not receive blanket access to sensitive contact data.

### Lead Vault

Primary tables:

- `leads_public`: metadata, alias, state axes, safe routing fields.
- `leads_sensitive`: phone ciphertext and phone hash.
- `consent_ledger`: consent/DND evidence.

Required split:

- `leads_public` contains alias, area, city, project interest, budget range, routing, workflow state, and attribution references.
- `leads_sensitive` contains encrypted contact data and deterministic private hash only.
- No raw or masked phone value belongs in any public table, audit event, logs, frontend payload, or file path.

### Site Visit Infrastructure

Primary tables:

- `site_visit_proposals`: broker-to-SM proposal.
- `site_visits`: scheduled visit and proof workflow state.
- `site_visit_confirmations`: proof events and metadata.
- Storage bucket for photo evidence: private only, hash/path safe.

Site visit proof must advance through deterministic proof events. No direct manual verification shortcut should create a lock.

### Broker Lock Infrastructure

Primary tables:

- `broker_locks`: 45-day attribution protection.
- `payout_ledger`: eligibility seed.
- `payout_statements`: payout documents.
- `disputes`, `dispute_events`: challenge and resolution.

A broker lock is proof of protected attribution, not proof of payout. Brokerage eligibility is a later governed state.

### Audit and Abuse Layer

Primary tables:

- `audit_events`: append-only safe event ledger.
- `abuse_events`: abuse evidence and investigation state.
- `risk_notifications`: internal risk queue.
- `risk_events`: target domain object; current implementation uses abuse/risk tables and audit events.
- `trust_scores`, `trust_score_snapshots`: explainable trust score history.
- `system_health_events`, `edge_function_failures`: operational diagnostics where present.

Audit rows must include actor, role or resolved permission context, timestamp, event type, lead alias or ID, workflow state, and safe device/IP hashes when needed.

### Developer Governance

Primary tables:

- `projects`: project metadata, coordinates, developer/org relation.
- `inventory_units`: inventory state.
- `unit_bookings`: booking link between inventory and lead.
- `developer_lead_bank`: target domain object; current implementation can model through lead source, project, and organization fields until a dedicated bank is added.

Developers receive operational proof, funnel, and inventory information. They should not receive buyer contact data unless a separate governed legal/customer process is approved.

### Buyer Trust Layer

Buyer trust is represented through:

- consent state,
- DND state,
- secure call records,
- site visit proof,
- follow-up discipline,
- dispute handling,
- no raw contact exposure.

The buyer identity is not an asset to be browsed. The buyer journey is an auditable workflow.

### AI-Safe Metadata Layer

Primary functions:

- `trust-get-lead-summary`
- `trust-get-broker-lock-status`
- `trust-get-followup-risk`
- `trust-get-site-visit-proof`
- `trust-create-followup`
- `trust-recommend-next-action`

AI tools operate only on safe metadata and return stable reason codes. AI must never query sensitive tables, decrypt PII, verify visits, approve locks, or approve payouts.

## 3. RLS Architecture

Default posture:

- Enable RLS on every operational table.
- Force RLS on sensitive and workflow tables.
- Revoke `anon` from operational tables.
- Revoke `authenticated` from sensitive vault tables.
- Allow client SELECT only through narrow policies scoped by organization, assigned actor, linked broker, active data loan, or auditor permission.
- Disallow direct client INSERT/UPDATE/DELETE for protected workflow tables.

Sensitive table policy:

```sql
ALTER TABLE public.leads_sensitive ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads_sensitive FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.leads_sensitive FROM anon, authenticated, public;
```

Workflow table posture:

- `leads_public`: role-safe SELECT only; protected mutations through Edge Functions or service-role RPC.
- `data_loans`: participant or admin read; mutations through `data-loan-workflow` only.
- `call_attempts`: caller/broker/manager/admin scoped read; provider callback update through signed webhook only.
- `site_visits`: assigned SM, linked broker, or governance role read; proof updates through RPC/Edge Function only.
- `broker_locks`: linked broker, assigned SM, finance/compliance/admin read; creation through verified visit flow only.
- `audit_events`: append-only; read scoped to actor, lead owner, or audit permission.

RLS must use backend-resolved helpers such as `has_strict_enterprise_permission`, `is_linked_broker_user`, `has_active_data_loan`, and org membership lookups. It must not trust JWT custom claims alone.

## 4. Edge Function Map

### Onboarding and Identity

- `complete-onboarding`: role-specific onboarding with pilot user, organization, and profile records.
- `accept-invite`: invite acceptance and audit.
- `invite-user`: hashed invite creation.
- `activate-user`, `deactivate-user`, `suspend-user`: user lifecycle.
- `assign-role`, `update-permission-template`: RBAC management.
- `create-organization`, `pause-organization`, `resume-organization`: tenant governance.

### Lead Upload and Duplicate Prevention

- `broker-upload-lead`: broker lead intake, encryption/hash RPC, duplicate check, public/sensitive split, audit.
- `lead-from-broker`: external broker-sourced lead creation and visit linkage.
- `route-incoming-leads`: governed routing from campaign/developer pools.

Required behavior:

1. Validate JWT and role.
2. Validate active org.
3. Validate permission.
4. Normalize and encrypt contact in memory.
5. Hash contact with private salt.
6. Check duplicate by org/pool.
7. Insert public metadata and sensitive ciphertext transactionally.
8. Return only `lead_id` and alias.
9. Write safe audit event.

### Caller Assignment and Data Loan Governance

- `manage-caller-workflow`: assignment and outcome wrapper.
- `data-loan-workflow`: grant, revoke, extend.
- RPC: `assign_lead_to_caller_v1` or `assign_lead_to_caller_v2`.
- RPC: `has_active_data_loan`.
- Scheduled function/RPC: `expire_stale_data_loans`.

### Secure Call Initiation

- `initiate-call`: caller-to-lead Exotel bridge.
- `broker-self-secure-call`: linked broker-to-lead governed call.
- `initiate-broker-call`: SM-to-broker secure call.
- `exotel-callback`: signed provider callback, replay prevention, state update, audit.

Secure call flow:

```text
Caller or broker
-> Edge Function
-> JWT and permission check
-> active org and user check
-> active data loan check
-> consent and DND check
-> decrypt contact in memory
-> Exotel bridge
-> call_attempts queued
-> provider callback validated
-> call_attempts updated
-> audit_events written
```

### Site Visit Governance

- `propose-site-visit`: broker proposes.
- `review-site-visit-proposal`: SM accepts, reschedules, rejects.
- `create-site-visit`: governed schedule creation.
- `start-site-visit`: assigned SM starts visit.
- `confirm-site-visit-arrival`: arrival confirmation.
- `verify-site-gps`: server distance verification.
- `upload-site-photo`: private storage upload and proof hash.
- `verify-site-visit-proof`: unified deterministic proof state machine.
- `broker-review-site-visit`: broker approval/rejection where required.

### Broker Lock and Payout

- Trigger/RPC creates or extends `broker_locks` only after verified visit proof.
- `run-payout-eligibility`: computes eligibility from lock, booking, and trust state.
- `generate-payout-statement`: creates finance document from eligible ledger rows.
- `dispute-engine`: handles attribution and payout disputes.

### Audit, Risk, Abuse, and AI

- `check-rate-limit`: action throttling and abuse events.
- `flag-abuse-event`: safe abuse evidence.
- `resolve-abuse-event`: controlled resolution.
- `incident-response`: org pause and mass loan revocation.
- `generate-risk-summary`, `calculate-trust-score`, `run-trust-decay`: risk/trust analytics.
- AI-safe tool functions: metadata-only access and recommendations.

## 5. RPC Strategy

Use RPCs for deterministic state changes that need database atomicity:

- `ingest_lead_contact_secure(contact, enc_key, hash_salt)`: returns ciphertext and private hash.
- `check_duplicate_lead(phone_hash, org_id)`: finds duplicate without exposing phone.
- `assign_lead_to_caller_v2(...)`: assignment plus audit plus data-loan preservation.
- `verify_site_gps_v2(...)`: geofence check and row-count verification.
- `upload_site_photo_v2(...)`: proof hash/path update and row-count verification.
- `broker_review_site_visit_v2(...)`: broker proof review.
- `record_audit(...)`: safe audit insert helper.
- `record_pilot_abuse(...)`: controlled abuse event creation.
- `expire_stale_data_loans()`: scheduled expiry.
- `expire_stale_broker_locks()`: scheduled attribution expiry.
- `decay_inactive_trust_scores()`: scheduled trust decay.

RPC rules:

- `SECURITY DEFINER` only when required.
- Always set `search_path = public`.
- Revoke public execution.
- Grant mutation RPCs only to `service_role`.
- Return stable JSON reason codes, not raw errors.
- Use row-count checks on protected updates.

## 6. Audit Architecture

`audit_events` is the operational memory of the platform.

Required event envelope:

```json
{
  "actor_id": "uuid-or-null-for-provider",
  "actor_role": "resolved-role",
  "organization_id": "uuid",
  "event_type": "lead_assigned_to_caller",
  "lead_id": "uuid",
  "lead_alias": "L-1042",
  "workflow_state": {
    "trust_state": "loan_active",
    "sales_state": "assigned_to_caller",
    "attribution_state": "tracking",
    "next_action": "secure_call"
  },
  "reason_code": "assignment_created",
  "ip_hash": "optional",
  "user_agent_hash": "optional"
}
```

Forbidden audit content:

- raw phone,
- masked phone,
- email,
- raw provider webhook body,
- free-form notes that may contain contact details,
- public URLs containing personal names or contact values.

Critical audit events:

- `lead_uploaded`
- `duplicate_lead_blocked`
- `lead_assigned_to_sm`
- `lead_assigned_to_caller`
- `data_loan_granted`
- `data_loan_revoked`
- `secure_call_initiated`
- `call_callback_accepted`
- `call_callback_rejected`
- `call_outcome_updated`
- `trust_followup_created`
- `site_visit_proposed`
- `site_visit_scheduled`
- `site_visit_gps_verified`
- `site_visit_gps_rejected`
- `site_photo_uploaded`
- `site_visit_verified`
- `broker_lock_created`
- `brokerage_status_updated`
- `abuse_event_flagged`

Audit write failure on a protected action is a release-blocking defect.

## 7. Lead Lifecycle Engine

A lead must carry separate axes:

- `trust_state`: protected workflow proof.
- `sales_state`: sales journey stage.
- `lead_temperature`: intent signal.
- `attribution_state`: broker protection state.
- `next_action`: deterministic workflow instruction.

Current fields map:

- `lead_status` -> trust state.
- `conversion_stage` -> sales state where present.
- `lead_temperature` and `lead_quality` -> intent classification.
- `brokerage_status`, `source_broker_id`, `broker_locks` -> attribution.
- `next_followup_at`, `assigned_caller_id`, `assigned_manager_id` -> next action derivation.

Canonical flow:

```text
Lead intake
-> encryption
-> hashing
-> duplicate check
-> alias creation
-> broker attribution
-> SM/caller assignment
-> data loan
-> secure call
-> outcome capture
-> follow-up
-> visit proposal
-> GPS verification
-> photo proof
-> visit verification
-> broker lock
-> brokerage eligibility
```

Blocked transitions:

- `new -> locked`
- `new -> visit_verified`
- `called -> locked`
- `visit_scheduled -> locked`
- expired data loan -> secure call
- AI recommendation -> database mutation
- provider callback without valid signature -> call update

## 8. Queue Allocation Engine

Queue engine inputs:

- organization status,
- lead source pool,
- broker attribution state,
- lead temperature,
- consent and DND,
- caller availability,
- caller role permission,
- active workload,
- previous call outcome,
- next follow-up deadline,
- lock/dispute state.

Assignment output:

```json
{
  "lead_id": "uuid",
  "lead_alias": "L-1042",
  "assigned_caller_id": "uuid",
  "assignment_reason": "hot_lead_callback_due",
  "loan_minutes": 240,
  "next_action": "secure_call"
}
```

Hard rules:

- A caller gets only assigned leads.
- Queue visibility requires assignment or active data loan.
- Assignment creates or verifies a data loan.
- Reassignment requires revoking or expiring stale loans.
- Broker-private leads cannot enter shared queues unless governance releases them.

Priority model:

1. Hot lead with due follow-up or site visit intent.
2. Warm lead with callback due.
3. New broker-sourced lead inside SLA.
4. Reactivation pool with no active lock.
5. Developer campaign lead with consent clear.
6. Cold nurture after high-priority queue is clear.

## 9. Data Loan Governance

`data_loans` is the temporary access contract.

Required fields:

- lead,
- broker/source owner,
- grantee user,
- purpose,
- starts_at,
- expires_at,
- status,
- revoked_at,
- revoked_by,
- audit event.

Loan purposes:

- `call`
- `site_visit`
- future: `support`, `dispute_review`, `compliance_review`

Lifecycle:

```text
requested
-> granted
-> active
-> expired
```

or:

```text
active
-> revoked
```

Rules:

- No active loan, no secure call.
- No expired loan extension without permission.
- Revocation must immediately block provider initiation.
- Scheduled expiry must run independently of app clients.
- A new assignment must not leave stale overlapping loans unless explicitly allowed and audited.

## 10. Broker Lock Engine

Lock creation contract:

```text
site_visit.proof_status = verified
AND site_visit.status in ('visit_done', 'completed', 'verified')
AND source_broker_id exists
AND lead belongs to same organization
AND no conflicting active lock exists
-> broker_locks row
-> expires_at = starts_at + 45 days
-> lead attribution state = locked
-> audit event = broker_lock_created
```

Lock states:

- `active`
- `expired`
- `released`
- `disputed`

Brokerage states:

- `tracking`
- `pending_visit`
- `locked`
- `eligible`
- `paid`
- `disputed`
- `blocked`

Lock expiry must not delete history. It only changes eligibility and assignment rules.

## 11. Site Visit Verification Engine

Required progression:

```text
proposal_created
-> proposal_accepted
-> visit_scheduled
-> visit_started
-> client_reached_site
-> gps_verified
-> photo_uploaded
-> proof_verified
-> broker_review_pending
-> completed
-> broker_lock_created
```

GPS verification:

- project coordinates must exist,
- submitted lat/lng must be valid,
- accuracy must be within configured threshold,
- distance must be within geofence,
- result recorded in `site_visit_confirmations`.

Photo proof:

- private bucket only,
- object key must use visit/proof UUIDs or hashes,
- no contact or human-readable buyer data in path,
- hash stored for tamper detection,
- overwrite disallowed or versioned.

No shortcut rule:

- A manager cannot directly set a visit to verified.
- A broker cannot create a lock.
- AI cannot verify proof.

## 12. AI-Safe Tool Layer

AI may:

- summarize safe metadata,
- classify intent from safe fields,
- recommend next action,
- detect stuck workflow,
- prioritize queues,
- create a follow-up only through a governed tool.

AI may not:

- read `leads_sensitive` or `brokers_sensitive`,
- decrypt PII,
- approve visits,
- create broker locks,
- approve payouts,
- bypass role checks,
- mutate state through raw table writes.

Tool response contract:

```json
{
  "ok": true,
  "lead_alias": "L-1042",
  "recommended_action": "schedule_visit",
  "reason_code": "hot_lead_visit_intent",
  "risk": "medium",
  "confidence": 0.78
}
```

## 13. Risk Engine

Risk inputs:

- duplicate lead hash,
- repeated provider callback failures,
- expired loan access attempts,
- GPS distance failures,
- photo proof anomalies,
- broker lock conflicts,
- high rejection rates,
- suspicious caller velocity,
- stale hot leads,
- payout dispute frequency.

Risk outputs:

- `risk_notifications` for operators,
- `abuse_events` for investigation,
- trust score updates,
- incident response recommendations,
- dashboard-safe reason codes.

Risk must be explainable. No black-box score should directly block payout or create lock without deterministic supporting events.

## 14. Abuse Detection

Abuse classes:

- `duplicate_claim`
- `data_loan_bypass`
- `expired_loan_call_attempt`
- `provider_callback_replay`
- `gps_spoof_risk`
- `photo_tamper_risk`
- `cross_broker_access_attempt`
- `followup_spam`
- `payout_manipulation`

Abuse handling:

1. Write safe `abuse_events`.
2. Write audit event.
3. Notify permitted operators.
4. Revoke affected data loans when needed.
5. Pause user or organization only through incident-response governance.
6. Preserve all evidence without exposing PII.

## 15. Workflow Orchestration

Backend orchestration model:

```text
Client action
-> Edge Function
-> shared auth and org guard
-> permission guard
-> state-machine guard
-> RPC or table mutation with service role
-> audit write
-> safe response
```

Provider orchestration:

```text
Provider callback
-> public Edge Function with JWT disabled
-> HMAC/signature validation
-> replay check
-> provider event normalization
-> state transition guard
-> metadata update
-> audit write
```

Scheduled orchestration:

- expire stale data loans,
- expire stale broker locks,
- trust score decay,
- stuck workflow scan,
- payout eligibility scan,
- risk summary generation.

## 16. Scaling Strategy

Database scaling:

- Index by `organization_id`, workflow state, assigned actor, due timestamps, and active statuses.
- Keep ciphertext/hash vault tables narrow.
- Use partial indexes for active loans, pending follow-ups, active locks, and open abuse events.
- Partition append-heavy audit tables by month when event volume grows.
- Use materialized or cached reporting views for dashboards, never broad raw SELECT.

Edge Function scaling:

- Keep functions stateless.
- Keep provider integration idempotent by provider event ID.
- Use stable reason-code responses.
- Avoid logging raw payloads.
- Move heavy analytics to scheduled jobs or materialized tables.

Storage scaling:

- Use private buckets for proof.
- Use hash-safe object keys.
- Store metadata in Postgres, binary proof in Storage.
- Enforce signed URL expiry where display is required.

## 17. Multi-Tenant Architecture

Tenant model:

- `organizations.id` is the tenant root.
- User membership is resolved through `pilot_users` and role assignment tables.
- Every lead, broker, visit, follow-up, project, inventory, issue, and risk object must resolve to one organization.

Isolation rules:

- Cross-org reads are denied by default.
- Platform admin access is explicit and audited.
- Developers see only their organization/project scope.
- Brokers see only linked broker records and protected attribution objects.
- Callers see only assigned data-loan records.
- Auditors see safe logs according to audit permission.

## 18. Infrastructure Roadmap

Phase 1: Consolidate contracts

- Document canonical enum values for lead axes.
- Add a shared workflow helper for allowed transitions.
- Add an audit completeness static gate.
- Confirm all protected functions call shared permission helpers.

Phase 2: Dedicated pool architecture

- Add `lead_pools` and `lead_pool_memberships` if current source fields become insufficient.
- Define pool expiry and release rules in SQL constraints/RPCs.
- Add governance events for broker-private to shared-pool transitions.

Phase 3: Reporting hardening

- Move broad reporting views behind Edge Functions.
- Require `security_invoker = true` on safe views where direct read remains.
- Add org/role filters to every reporting surface.

Phase 4: Provider expansion

- Keep Exotel as the model.
- Add WhatsApp only through signed send requests, callbacks, idempotency, and audit.
- No direct WhatsApp links or phone exposure.

Phase 5: AI operations

- Deploy AI-safe tools.
- Role-test tools across broker, SM, caller, admin, and auditor.
- Add evaluation suite for PII leakage and illegal workflow mutations.

## 19. Security Architecture

Security constitution:

- No raw phone exposure.
- No unrestricted SELECT on sensitive data.
- No frontend direct trust mutations.
- All trust actions audited.
- All PII encrypted.
- Data loans required for calls.
- AI receives metadata only.
- Broker attribution protected.
- Site visits require proof.
- Workflows are role-governed.

Secrets:

- `SUPABASE_SERVICE_ROLE_KEY`: Edge Functions only.
- `LEAD_ENCRYPTION_KEY`: Edge Functions/RPC only.
- `LEAD_HASH_SALT`: Edge Functions/RPC only.
- `EXOTEL_*`: provider connector only.
- Callback secrets: required for every public webhook.

Failure posture:

- Missing secret -> `provider_config_missing` or `server_error`, no partial mutation.
- Missing audit -> block release.
- Missing data loan -> deny call.
- Missing proof -> deny lock.
- Missing permission -> deny action.
- Missing organization -> deny action.

## 20. Production Deployment Strategy

Deployment order:

1. Backup database and confirm rollback plan.
2. Apply migrations with `supabase db push`.
3. Deploy Edge Functions with `supabase functions deploy <name>`.
4. Verify `supabase/config.toml` has `verify_jwt = true` for all non-webhook functions.
5. Confirm webhook functions have signature validation and replay protection.
6. Configure secrets in production, not preview only.
7. Run static security scan.
8. Run AI-safe tool scan.
9. Run Flutter build.
10. Run role-based UAT.
11. Run provider callback UAT.
12. Run storage proof UAT.
13. Run broker lock and payout eligibility UAT.

Repo-specific verification gates:

```powershell
npm run build
npx tsc --noEmit
```

Project-specific deployment gates:

```powershell
supabase db push
supabase functions deploy broker-upload-lead
supabase functions deploy initiate-call
supabase functions deploy exotel-callback
supabase functions deploy verify-site-visit-proof
cd flutter_app
flutter build web --release
```

Production vs preview assumptions:

- Provider secrets must be verified in Production and Preview independently.
- Callback URLs must point to the intended Supabase project ref.
- Production callback HMAC secrets must not be reused in local test logs.
- WhatsApp or call send failures should be checked for provider environment mismatch before changing state-machine logic.

## Data Pool Architecture

### Broker Private Pool

- Owner: source broker.
- Permissions: linked broker read of safe metadata; SM/caller only through assignment and data loan.
- Assignment: only assigned SM or governed routing may assign.
- Expiry: does not become common pool automatically; release requires governance event.

### Developer Lead Bank

- Owner: developer organization/project.
- Permissions: developer admin and assigned operations roles.
- Assignment: routed by project, budget, location, capacity, and consent.
- Expiry: campaign-specific SLA and reactivation rules.

### Reactivation Pool

- Owner: organization.
- Permissions: SM/caller access through queue assignment.
- Assignment: based on stale follow-up, no active lock, consent clear, and risk score.
- Expiry: returns to dormant state or suppression list.

### Walk-In Pool

- Owner: site/project organization.
- Permissions: site team and assigned SM.
- Assignment: immediate SM or caller action with proof-of-origin metadata.
- Expiry: short SLA; unresolved walk-ins move to reactivation only after duplicate and attribution check.

### Shared Campaign Pool

- Owner: organization campaign.
- Permissions: campaign operators, assigned callers, compliance.
- Assignment: priority queue by budget, area, consent, and caller load.
- Expiry: campaign-defined; stale leads move to reactivation or suppression.

## Production Acceptance Criteria

The backend is production-ready for a trust-first real estate OS only when these are true:

- Broker upload returns only lead ID and alias.
- No public table contains raw contact values.
- Sensitive vault SELECT is denied to authenticated users.
- Caller without active data loan cannot call.
- Caller with active loan can call only through Exotel Edge Function.
- Provider callback rejects invalid signatures and replays.
- GPS outside geofence is rejected.
- Photo proof path is PII-safe.
- Verified visit creates a 45-day broker lock.
- Broker lock starts payout tracking but does not guarantee payout.
- AI-safe tools pass metadata-only static scan and role UAT.
- Every protected transition has a safe audit event.
- Production secrets and callback URLs are verified in the production Supabase project.

