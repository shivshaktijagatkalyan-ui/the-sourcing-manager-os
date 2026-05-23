# Feature Specification: Complete Trust Platform

**Feature Branch**: `001-complete-trust-platform`

**Created**: 2026-05-23

**Status**: Draft

**Input**: User description: "Complete the full FutureTrust Real Estate OS / The Sourcing Manager OS project using Spec Kit governance, covering Flutter workflow screens, Supabase trust enforcement, protected Edge Functions, audit proof, release gates, and operational UAT."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Broker Onboards and Uploads Protected Leads (Priority: P1)

A broker signs in, completes server-governed onboarding, uploads a buyer lead,
and receives only metadata-safe confirmation. The system hashes/encrypts
restricted contact data, prevents duplicate submission, assigns attribution,
and records audit proof.

**Why this priority**: Broker lead ingestion is the start of the commercial
trust chain. If this path leaks contact data or misattributes the broker, every
downstream call, visit, lock, and payout decision becomes unreliable.

**Independent Test**: Authenticate as a broker test user, invoke onboarding and
lead upload, confirm the response excludes restricted contact data, confirm a
duplicate upload fails with conflict, and confirm audit events exist.

**Acceptance Scenarios**:

1. **Given** an authenticated broker without a completed profile, **When** they
   submit onboarding data, **Then** the server creates active role, pilot, and
   broker profile records without frontend direct writes.
2. **Given** an active broker with permission to upload leads, **When** they
   submit a valid lead, **Then** public metadata is persisted, restricted
   contact data is encrypted/hashed, `broker_id` references the user id,
   `source_broker_id` references the broker profile id, and the response omits
   contact fields.
3. **Given** the same restricted contact is submitted again, **When** upload is
   attempted, **Then** the system returns a duplicate conflict without exposing
   the restricted value.

---

### User Story 2 - Sourcing Manager Allocates Work and Verifies Visits (Priority: P1)

A sourcing manager sees assigned metadata-only leads, allocates caller access
through data loans, creates or reviews site visit proposals, starts site visits,
and completes GPS/photo/visit-done proof.

**Why this priority**: The sourcing manager is the operational control point
for contact access, field verification, and broker lock proof.

**Independent Test**: Authenticate as a sourcing manager, view only public lead
metadata, allocate a caller data loan, create a site visit, reject wrong GPS,
accept valid GPS, upload proof metadata, and finalize the visit.

**Acceptance Scenarios**:

1. **Given** an assigned sourcing manager, **When** they open the lead queue,
   **Then** they see metadata only and no restricted contact fields.
2. **Given** an eligible lead and active caller, **When** the sourcing manager
   grants a call loan, **Then** an active time-bound data loan is persisted and
   audit proof is written.
3. **Given** a scheduled visit, **When** submitted GPS is outside the project
   geofence or has invalid accuracy, **Then** proof fails closed and the visit
   cannot be marked verified.
4. **Given** valid GPS and accepted proof metadata, **When** visit completion is
   submitted, **Then** the lead moves to `visit_verified` and brokerage moves
   to `locked`.

---

### User Story 3 - Caller Uses Secure Bridge Without Contact Exposure (Priority: P1)

A caller receives an active data loan, initiates a secure provider-mediated
call, updates call outcome, and creates follow-up state without seeing or
storing restricted contact data.

**Why this priority**: Secure calling is the primary controlled use of sensitive
lead data and must be loan-gated, auditable, and provider-safe.

**Independent Test**: Authenticate as a caller, confirm assigned loan visibility,
invoke secure call initiation, reject forged provider callbacks, and update
outcome/follow-up without contact exposure.

**Acceptance Scenarios**:

1. **Given** a caller without an active loan, **When** they request a secure
   call, **Then** the system rejects the action.
2. **Given** a caller with an active loan, **When** they initiate a call,
   **Then** the provider bridge is queued without returning contact data.
3. **Given** a forged provider callback, **When** it reaches the webhook,
   **Then** it cannot mark the call successful.
4. **Given** a valid call outcome update, **When** the caller submits notes or
   follow-up status, **Then** the system persists safe metadata and audit proof.

---

### User Story 4 - Broker Lock and Brokerage Eligibility Are Enforced (Priority: P2)

After proof-backed site visit completion, the system creates or extends a
45-day broker lock, blocks conflicting attribution, and surfaces lock status to
brokers and admins with proof metadata only.

**Why this priority**: Broker trust depends on deterministic commission
protection that cannot be overridden by manual claims.

**Independent Test**: Complete a verified visit from a sourced broker lead and
confirm an active 45-day lock exists, conflict attempts fail, and safe AI/tools
return only lock/proof metadata.

**Acceptance Scenarios**:

1. **Given** a visit is completed with verified proof, **When** lock logic runs,
   **Then** an active broker lock is created or extended for 45 days.
2. **Given** another broker attempts to claim an actively locked lead, **When**
   the claim is processed, **Then** the system blocks the conflict and writes an
   audit event.
3. **Given** a broker or admin requests lock status, **When** the tool responds,
   **Then** it returns status, days remaining, brokerage status, and proof
   status without restricted contact data.

---

### User Story 5 - Super Admin Governs Platform Health and Risk (Priority: P2)

A super admin monitors organizations, roles, permissions, abuse events, risk
notifications, system health, workflow bottlenecks, and release/UAT status from
governed dashboards and protected actions.

**Why this priority**: Production operation requires a control plane that can
prove compliance, detect abuse, and pause or repair unsafe workflows.

**Independent Test**: Authenticate as a platform admin, load dashboard
snapshots, inspect risk/system health metadata, perform an allowed governance
action, and confirm unauthorized actions fail closed.

**Acceptance Scenarios**:

1. **Given** an active platform admin, **When** they open the dashboard, **Then**
   organization, workforce, risk, proof, and health summaries load from
   protected sources.
2. **Given** an inactive, pending, or unauthorized user, **When** they request a
   governance action, **Then** access is rejected without partial state changes.
3. **Given** an abuse/risk event is resolved, **When** the action completes,
   **Then** sanitized audit evidence is persisted.

---

### User Story 6 - Release Operator Verifies and Ships Safely (Priority: P3)

A release operator runs deterministic checks, validates function/config drift,
checks security constraints, dry-runs migrations, builds Flutter web, and
decides whether to run live UAT against the linked remote project.

**Why this priority**: The platform can only be called operational when release
evidence is reproducible and environment-sensitive checks are explicit.

**Independent Test**: Run the documented verification commands and confirm
outputs are recorded in reports without mutating production unless explicitly
approved.

**Acceptance Scenarios**:

1. **Given** code or migrations changed, **When** the release operator runs the
   gates, **Then** build, typecheck, security, drift, and migration dry-run
   results are available.
2. **Given** live UAT is requested, **When** the trust-loop script is run, **Then**
   the operator understands it can mutate the linked remote Supabase project.
3. **Given** a gate fails, **When** completion is reported, **Then** the failure
   and blocked release status are clearly documented.

### Edge Cases

- Supabase URL, anon key, or service role key is absent or points to Preview
  while a Production verification is expected.
- Exotel provider credentials or callback secret are missing, stale, or forged.
- A broker profile exists but `broker_id` and `source_broker_id` are mismapped.
- Remote Postgres lacks optional extensions such as pgvector.
- A site visit receives wrong GPS first, then valid GPS after the visit was
  invalidated.
- Photo proof path or proof hash contains restricted contact-like tokens.
- Role assignment, pilot user, or organization status is inactive mid-workflow.
- UAT scripts create test records in a linked remote project and must not be
  mistaken for read-only checks.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support server-governed onboarding for broker,
  sourcing manager, caller, and admin-relevant roles.
- **FR-002**: System MUST resolve active role from role assignments and legacy
  pilot records with explicit pending/suspended handling.
- **FR-003**: System MUST upload broker leads only through protected server
  actions.
- **FR-004**: System MUST encrypt and hash restricted lead contact data before
  persistence.
- **FR-005**: System MUST reject duplicate leads without returning restricted
  data.
- **FR-006**: System MUST preserve correct broker attribution using auth user id
  for `broker_id` and broker profile id for `source_broker_id`.
- **FR-007**: System MUST allow sourcing managers to view assigned public lead
  metadata without restricted contact fields.
- **FR-008**: System MUST grant caller data access through active, time-bound
  data loans only.
- **FR-009**: System MUST initiate secure provider-mediated calls without
  exposing restricted contact data to callers or frontend clients.
- **FR-010**: System MUST authenticate provider callbacks and reject forged
  call status updates.
- **FR-011**: System MUST persist safe call outcomes and follow-up metadata.
- **FR-012**: System MUST create and review site visit proposals through
  protected actions.
- **FR-013**: System MUST validate GPS proof against project geofence and
  accuracy rules.
- **FR-014**: System MUST accept photo/proof metadata without storing or
  returning restricted contact data.
- **FR-015**: System MUST create or extend broker locks after proof-backed visit
  completion.
- **FR-016**: System MUST block conflicting active broker locks.
- **FR-017**: System MUST update lead lifecycle and brokerage status
  deterministically after verified visits.
- **FR-018**: System MUST provide AI-safe tools that return only approved
  metadata for leads, follow-ups, proof, recommendations, and broker locks.
- **FR-019**: System MUST provide super-admin governance dashboards with
  organization, risk, workforce, proof, and health metadata.
- **FR-020**: System MUST keep release, UAT, security, drift, and build evidence
  in repository docs or reports.
- **FR-021**: System MUST include a seed-test-users script that defaults to
  dry-run and requires service-role credentials only for apply mode.
- **FR-022**: System MUST maintain required documentation entrypoints for PRD,
  TRD, app flow, architecture, schema, RLS, state machine, release gate, and
  runbook.
- **FR-023**: System MUST keep Flutter workflow screens, service clients,
  models, widgets, and state-machine entrypoints present and analyzable.
- **FR-024**: System MUST declare all required database tables in Supabase
  migrations.
- **FR-025**: System MUST preserve WhatsApp/Exotel call flow and Supabase
  persistence when follow-up, webhook, or state machine logic changes.

### Security, Privacy, and Audit Requirements

- **SR-001**: Protected actions MUST execute through Supabase Edge Functions.
- **SR-002**: Restricted contact data MUST remain encrypted/hashed and never be
  returned to frontend clients or AI tools.
- **SR-003**: Protected state changes MUST write PII-safe audit events.
- **SR-004**: Invalid auth, organization status, role status, provider callback,
  GPS proof, photo proof, or data loan state MUST fail closed.
- **SR-005**: Security scans MUST block direct call links, masked contact
  fragments, runtime logs in protected code, hardcoded secrets, and raw internal
  error leakage.
- **SR-006**: Function/config drift MUST fail when a Supabase function exists
  without a matching config declaration.

### Key Entities *(include if feature involves data)*

- **Organization**: Operating tenant with status and governance controls.
- **Pilot User**: Legacy role/status membership used for compatibility and
  operational gating.
- **Role Assignment**: Current role, permission template, and organization
  binding for authenticated users.
- **Permission Template**: Organization-specific permission bundle used by
  protected action checks.
- **Broker Public Profile**: Broker metadata and sourcing-manager assignment.
- **Broker Sensitive Profile**: Encrypted broker contact fields.
- **Sourcing Manager Public Profile**: Safe manager metadata.
- **Caller Profile**: Safe caller identity and operational status.
- **Lead Public**: Metadata-only lead record used by dashboards and state flow.
- **Lead Sensitive**: Encrypted/hash restricted contact storage.
- **Data Loan**: Time-bound permission for a caller or actor to use restricted
  data through protected actions.
- **Call Attempt**: Provider-mediated call state and callback metadata.
- **Broker Follow-up**: Safe next-action queue item for broker or lead workflow.
- **Site Visit Proposal**: Broker-to-SM proposed visit metadata.
- **Site Visit**: Scheduled/verified field workflow state.
- **Site Visit Proof**: GPS/photo/QR/visit proof metadata mirrored from
  confirmations.
- **Broker Lock**: Commission attribution lock with expiration and proof status.
- **Project and Inventory Unit**: Developer project and available unit metadata.
- **Developer Lead Bank**: Developer-side safe lead bank and attribution state.
- **Audit Event**: Append-only proof of protected actions.
- **Abuse Event and Risk Notification**: Operational risk and abuse workflow.
- **Trust Score**: Trust metric for actors/entities.
- **System Health Event**: Operational status and reliability evidence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Full trust-loop UAT can pass from onboarding through broker lock
  creation with every assertion green.
- **SC-002**: Duplicate lead upload returns conflict without contact exposure.
- **SC-003**: Frontend authenticated clients cannot read restricted sensitive
  lead rows.
- **SC-004**: Forged provider callbacks cannot mark calls successful.
- **SC-005**: Wrong GPS proof is rejected and valid GPS proof is accepted within
  the configured geofence.
- **SC-006**: Verified visit completion creates or extends a 45-day broker lock.
- **SC-007**: Audit review returns only PII-safe events.
- **SC-008**: Function/config drift check passes for all declared Edge
  Functions.
- **SC-009**: Security scans pass in both Python and JavaScript implementations.
- **SC-010**: `npm run build`, `npx tsc --noEmit`, and Flutter analysis pass
  for local release verification.

## Assumptions

- The project remains a Flutter/Supabase hybrid application.
- Supabase remote access, secrets, and provider keys are supplied through local
  environment files and are not committed.
- Production deployment uses Supabase migrations, Supabase Edge Function deploys,
  and Flutter web release builds.
- Root Node.js tooling is verification glue and script execution, not the
  primary app runtime.
- Live UAT may mutate linked remote test data and requires explicit operator
  intent.

## Verification Expectations *(mandatory)*

- `npm run build`
- `npx tsc --noEmit`
- `python scripts/security-check.py`
- `node scripts/security-check.mjs`
- `node scripts/check-function-drift.mjs`
- `node scripts/ai-safe-tool-check.mjs`
- `flutter analyze` when Flutter code changes
- `npx supabase db push --dry-run --linked` when migrations change
- Live `node scripts/uat-trust-loop.mjs` only when explicitly approved because
  it can mutate the linked remote Supabase project
