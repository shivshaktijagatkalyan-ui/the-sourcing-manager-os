# Tasks: Complete Trust Platform

**Input**: Design documents from `/specs/001-complete-trust-platform/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md),
[research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Focused checks are included for every workflow/state area. Live UAT
is listed as an explicit operator decision because it can mutate the linked
remote Supabase project.

**Organization**: Tasks are grouped by user story to enable independent
implementation, verification, and deployment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no
  dependency on incomplete tasks.
- **[Story]**: Required for user-story tasks, for example `[US1]`.
- Each task includes exact repository-relative file paths.

## Phase 1: Setup (Shared Spec Kit and Project Baseline)

**Purpose**: Make the project governable through Spec Kit and stable docs.

- [x] T001 Verify Spec Kit initialization files in `.specify/init-options.json`, `.specify/integration.json`, and `.agents/skills/speckit-constitution/SKILL.md`
- [x] T002 Update production rules and active plan reference in `AGENTS.md`
- [x] T003 [P] Finalize project constitution in `.specify/memory/constitution.md`
- [x] T004 [P] Add project-specific Spec Kit template overrides in `.specify/templates/overrides/spec-template.md`, `.specify/templates/overrides/plan-template.md`, and `.specify/templates/overrides/tasks-template.md`
- [x] T005 [P] Maintain stable reviewer doc entrypoints in `docs/PRD.md`, `docs/TRD.md`, `docs/APP_FLOW.md`, `docs/BACKEND_ARCHITECTURE.md`, `docs/FRONTEND_ARCHITECTURE.md`, `docs/DATABASE_SCHEMA.md`, `docs/RLS_SECURITY.md`, `docs/SUPER_ADMIN_DASHBOARD.md`, `docs/LEAD_LIFECYCLE_STATE_MACHINE.md`, `docs/RELEASE_GATE_REPORT.md`, and `docs/PRODUCTION_RUNBOOK.md`
- [x] T006 [P] Keep generated verification walkthrough links portable in `walkthrough.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared source/schema/script structure that all user stories depend on.

- [x] T007 Declare missing required profile/proof/bank tables in `supabase/migrations/20260523010000_add_required_public_profile_tables.sql`
- [x] T008 Update `.env.example` with `SUPABASE_SERVICE_ROLE_KEY` for apply-mode UAT tooling
- [x] T009 Add dry-run-first UAT seed script in `scripts/seed-test-users.mjs`
- [x] T010 [P] Add Flutter auth compatibility exports in `flutter_app/lib/auth/auth_service.dart` and `flutter_app/lib/auth/role_resolver.dart`
- [x] T011 [P] Add Flutter service entrypoints in `flutter_app/lib/services/edge_function_client.dart`, `flutter_app/lib/services/lead_service.dart`, `flutter_app/lib/services/caller_service.dart`, `flutter_app/lib/services/broker_service.dart`, `flutter_app/lib/services/site_visit_service.dart`, and `flutter_app/lib/services/admin_service.dart`
- [x] T012 [P] Add metadata-only Flutter models in `flutter_app/lib/models/lead.dart`, `flutter_app/lib/models/broker.dart`, `flutter_app/lib/models/caller.dart`, `flutter_app/lib/models/site_visit.dart`, `flutter_app/lib/models/broker_lock.dart`, and `flutter_app/lib/models/dashboard_snapshot.dart`
- [x] T013 [P] Add reusable metadata widgets in `flutter_app/lib/widgets/lead_card.dart`, `flutter_app/lib/widgets/followup_card.dart`, `flutter_app/lib/widgets/broker_lock_card.dart`, `flutter_app/lib/widgets/site_visit_card.dart`, and `flutter_app/lib/widgets/trust_badge.dart`
- [x] T014 Add deterministic client-side lead state helper in `flutter_app/lib/state/lead_state_machine.dart`
- [x] T015 [P] Add app state holder in `flutter_app/lib/state/app_state.dart`
- [x] T016 [P] Add developer dashboard compatibility export in `flutter_app/lib/screens/developer_dashboard.dart`
- [x] T017 Run migration dry-run for schema additions with `npx supabase db push --dry-run --linked`

**Checkpoint**: Foundation ready; user story verification can proceed.

---

## Phase 3: User Story 1 - Broker Onboards and Uploads Protected Leads (Priority: P1) MVP

**Goal**: Broker onboarding and lead upload work without contact exposure and with correct attribution.

**Independent Test**: Complete broker onboarding/upload flow and duplicate check using `scripts/uat-trust-loop.mjs` or focused broker upload scripts when live mutation is approved.

### Tests for User Story 1

- [x] T018 [P] [US1] Verify onboarding profile targets in `supabase/functions/complete-onboarding/index.ts`
- [x] T019 [P] [US1] Verify broker attribution insert fields in `supabase/functions/broker-upload-lead/index.ts`
- [x] T020 [P] [US1] Verify duplicate lead prevention migration coverage in `supabase/migrations/20240520000000_duplicate_lead_prevention.sql` and `supabase/migrations/20260520000300_harden_broker_upload_encryption.sql`

### Implementation for User Story 1

- [x] T021 [US1] Ensure caller profile upsert is handled without affecting broker and sourcing manager onboarding in `supabase/functions/complete-onboarding/index.ts`
- [x] T022 [US1] Ensure `broker_id` uses auth user id and `source_broker_id` uses broker profile id in `supabase/functions/broker-upload-lead/index.ts`
- [x] T023 [US1] Confirm broker upload response remains metadata-only in `supabase/functions/broker-upload-lead/index.ts`
- [x] T024 [US1] Run broker-related security checks with `python scripts/security-check.py` and `node scripts/security-check.mjs`

**Checkpoint**: Broker can onboard/upload and duplicates fail closed.

---

## Phase 4: User Story 2 - Sourcing Manager Allocates Work and Verifies Visits (Priority: P1)

**Goal**: Sourcing managers allocate safe caller work and complete proof-backed site visits.

**Independent Test**: Use the trust-loop UAT or focused Edge Function invokes to allocate a data loan, reject wrong GPS, accept valid GPS, submit proof, and complete a visit.

### Tests for User Story 2

- [x] T025 [P] [US2] Verify data loan action paths in `supabase/functions/manage-caller-workflow/index.ts`
- [x] T026 [P] [US2] Verify GPS verification state rules in `supabase/functions/verify-site-gps/index.ts` and `supabase/functions/verify-site-visit-proof/index.ts`
- [x] T027 [P] [US2] Verify site visit proposal flow in `supabase/functions/propose-site-visit/index.ts` and `supabase/functions/review-site-visit-proposal/index.ts`

### Implementation for User Story 2

- [x] T028 [US2] Confirm `site_visit_proofs` mirror trigger persists proof metadata in `supabase/migrations/20260523010000_add_required_public_profile_tables.sql`
- [x] T029 [US2] Confirm Flutter site visit service calls protected functions in `flutter_app/lib/services/site_visit_service.dart`
- [x] T030 [US2] Confirm sourcing manager dashboard does not render restricted contact fields in `flutter_app/lib/screens/sourcing_manager_dashboard.dart`

**Checkpoint**: Sourcing manager proof flow remains deterministic and metadata-only.

---

## Phase 5: User Story 3 - Caller Uses Secure Bridge Without Contact Exposure (Priority: P1)

**Goal**: Callers use active data loans and secure provider bridge without direct contact access.

**Independent Test**: With active caller loan, initiate secure call and verify forged callback rejection.

### Tests for User Story 3

- [x] T031 [P] [US3] Verify loan-gated call initiation in `supabase/functions/initiate-call/index.ts`
- [x] T032 [P] [US3] Verify callback signature/replay hardening in `supabase/functions/exotel-callback/index.ts` and `supabase/migrations/20260512000100_harden_exotel_callback_replay.sql`
- [x] T033 [P] [US3] Verify caller dashboard avoids restricted contact rendering in `flutter_app/lib/screens/caller_dashboard_screen.dart` and `flutter_app/lib/screens/caller_lead_queue_screen.dart`

### Implementation for User Story 3

- [x] T034 [US3] Confirm caller profile table exists and is RLS-protected in `supabase/migrations/20260523010000_add_required_public_profile_tables.sql`
- [x] T035 [US3] Confirm caller service invokes only protected actions in `flutter_app/lib/services/caller_service.dart`
- [x] T036 [US3] Run AI-safe and security scans with `node scripts/ai-safe-tool-check.mjs`, `python scripts/security-check.py`, and `node scripts/security-check.mjs`

**Checkpoint**: Caller flow is loan-gated, provider-safe, and contactless.

---

## Phase 6: User Story 4 - Broker Lock and Brokerage Eligibility Are Enforced (Priority: P2)

**Goal**: Verified visits create/extend 45-day broker locks and block conflicts.

**Independent Test**: Complete a verified visit and inspect broker lock metadata and final lead state.

### Tests for User Story 4

- [x] T037 [P] [US4] Verify broker lock creation logic in `supabase/functions/verify-site-visit-proof/index.ts`
- [x] T038 [P] [US4] Verify broker lock hardening migrations in `supabase/migrations/20260510000200_harden_broker_locks.sql` and `supabase/migrations/20260519000100_scheduled_trust_infrastructure.sql`
- [x] T039 [P] [US4] Verify lock metadata tool response in `supabase/functions/trust-get-broker-lock-status/index.ts`

### Implementation for User Story 4

- [x] T040 [US4] Confirm final visit state updates lead lifecycle and brokerage status in `supabase/functions/verify-site-visit-proof/index.ts`
- [x] T041 [US4] Confirm broker lock card renders metadata only in `flutter_app/lib/widgets/broker_lock_card.dart`

**Checkpoint**: Broker lock enforcement is deterministic and auditable.

---

## Phase 7: User Story 5 - Super Admin Governs Platform Health and Risk (Priority: P2)

**Goal**: Super admins can inspect governed metadata and protected operational controls.

**Independent Test**: Load the super admin dashboard and verify risk/health/workforce summaries through protected functions.

### Tests for User Story 5

- [x] T042 [P] [US5] Verify dashboard protected function registration in `supabase/config.toml` and `supabase/functions/super-admin-dashboard/index.ts`
- [x] T043 [P] [US5] Verify risk and system health tables in `supabase/migrations/20240507000000_sprint4_operational_visibility.sql` and `supabase/migrations/20240511000000_sprint9_reliability.sql`

### Implementation for User Story 5

- [x] T044 [US5] Confirm admin service dashboard contract in `flutter_app/lib/services/admin_service.dart`
- [x] T045 [US5] Run function/config drift check with `node scripts/check-function-drift.mjs`

**Checkpoint**: Super admin governance surface remains protected and drift-free.

---

## Phase 8: User Story 6 - Release Operator Verifies and Ships Safely (Priority: P3)

**Goal**: Release evidence is reproducible and environment-sensitive checks are explicit.

**Independent Test**: Run local gates and migration dry-run; decide whether live UAT should run.

### Tests for User Story 6

- [x] T046 [P] [US6] Verify local release commands in `specs/001-complete-trust-platform/contracts/verification-gates.md`
- [x] T047 [P] [US6] Verify quickstart commands in `specs/001-complete-trust-platform/quickstart.md`
- [x] T048 [P] [US6] Verify seed script dry-run output in `scripts/seed-test-users.mjs`

### Implementation for User Story 6

- [x] T049 [US6] Run `python scripts/security-check.py`
- [x] T050 [US6] Run `node scripts/security-check.mjs`
- [x] T051 [US6] Run `node scripts/check-function-drift.mjs`
- [x] T052 [US6] Run `node scripts/ai-safe-tool-check.mjs`
- [x] T053 [US6] Run `npx tsc --noEmit`
- [x] T054 [US6] Run `flutter analyze` from `flutter_app/`
- [x] T055 [US6] Run `npm run build`
- [x] T056 [US6] Run `npx supabase db push --dry-run --linked`
- [x] T057 [US6] Run `node scripts/seed-test-users.mjs`
- [x] T058 [US6] Decide whether to run live `node scripts/uat-trust-loop.mjs` and document the decision in `walkthrough.md`

**Checkpoint**: Release gate evidence is current and live UAT decision is explicit.

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: Keep artifacts aligned and ready for future implementation.

- [x] T059 [P] Update Spec Kit analysis findings in `specs/001-complete-trust-platform/analysis.md`
- [x] T060 [P] Ensure `docs/PROJECT_FILE_INDEX.md` references root doc entrypoints and Spec Kit artifacts
- [x] T061 Review `git status --short` and separate existing user changes from Spec Kit/project-completion changes before staging

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; blocks story validation.
- **US1, US2, US3**: depend on Foundational and form the MVP trust loop.
- **US4**: depends on US2 proof completion and US1 broker attribution.
- **US5**: depends on Foundational and can run alongside US4 after MVP.
- **US6**: depends on the desired implementation scope being complete.
- **Final Phase**: depends on generated artifacts and verification results.

### Parallel Opportunities

- T003-T006 can run in parallel.
- T010-T013, T015, and T016 can run in parallel after T007-T009.
- Story verification tasks marked [P] can run in parallel within their phase.
- US4 and US5 can proceed in parallel after the MVP trust loop is stable.

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational tasks.
2. Complete US1, US2, and US3.
3. Run local gates.
4. Decide whether live trust-loop UAT is safe.

### Incremental Delivery

1. Add broker onboarding/upload guarantees.
2. Add SM allocation and site visit proof guarantees.
3. Add caller secure bridge guarantees.
4. Add broker lock guarantees.
5. Add super-admin governance and release evidence.

### Notes

- Do not run live UAT without explicitly accepting remote data mutation.
- Do not stage unrelated dirty worktree changes with this feature.
- Do not weaken security scanners to make a gate pass; fix the underlying
  source or document a narrow allow-list reason.
