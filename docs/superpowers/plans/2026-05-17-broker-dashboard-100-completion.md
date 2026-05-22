# Broker Dashboard 100% Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the broker dashboard production-complete: every visible broker input has a deterministic backend action, every backend action has a visible output/state change, and every flow is covered by local, training, and live Supabase verification.

**Architecture:** Keep the existing Flutter/Supabase architecture. The broker dashboard stays in Flutter, uses Supabase Edge Functions for mutations, reads from RLS-protected public tables, and uses `TrainingRuntime` only for local/training mode. Do not move business rules into generic AI behavior.

**Tech Stack:** Flutter Web, Supabase Auth, Supabase Postgres/RLS, Supabase Edge Functions, Deno TypeScript, Flutter widget tests, root `npm run build`, root `npx tsc --noEmit`.

---

## 100% Complete Definition

The broker dashboard is complete only when all of these are true:

- Broker login resolves to `BrokerDashboardScreen` for `broker`, `broker_owner`, and `broker_agent`.
- Broker profile loads from `brokers_public` by `linked_user_id` and active status.
- Broker dashboard reads only broker-safe data: `brokers_public`, `leads_public`, `broker_followups`, `site_visits`, `site_visit_proposals`, `broker_locks`, `data_loans`, `broker_activity_logs`, `broker_goals`, and safe RPCs.
- Broker lead upload sends sensitive phone data only once to `broker-upload-lead`; dashboard never displays raw phone/contact data.
- Every dashboard action has a deterministic Edge Function or local training-mode equivalent.
- Training mode never invokes live Supabase functions.
- Live mode never silently falls back to demo data.
- Every action creates or updates persistent Supabase state and audit evidence where required.
- The UI shows loading, success, blocked, empty, and error states clearly.
- Desktop and mobile browser passes show no blank screens, no runtime console errors, and no overlapping critical controls.
- Final gates pass: `npm run build`, `npx tsc --noEmit`, `flutter test`, plus targeted browser QA.

---

## Ownership Map

- `flutter_app/lib/screens/broker_dashboard_screen.dart`
  Broker dashboard read model, KPI cards, lead cards, action sheet, secure call, data loan, vault workflow, proposal flow.

- `flutter_app/lib/screens/broker_upload.dart`
  Broker lead upload form, one-time sensitive phone submission, validation, success/failure output.

- `flutter_app/lib/screens/role_dashboard_container.dart`
  Role-to-dashboard routing.

- `flutter_app/lib/utils/role_resolver.dart`
  Broker role resolution from training mode, Supabase `role_assignments`, and legacy `pilot_users`.

- `flutter_app/lib/utils/training_runtime.dart`
  Local simulation for broker dashboard reads and broker action outputs.

- `supabase/functions/broker-upload-lead/index.ts`
  Broker lead intake, duplicate protection, persistence, audit.

- `supabase/functions/broker-self-secure-call/index.ts`
  Broker secure call request, permission checks, provider queueing, call attempt output.

- `supabase/functions/broker-vault-workflow/index.ts`
  Assign caller, set follow-up, update lead quality, raise issue, and related vault mutations.

- `supabase/functions/data-loan-workflow/index.ts`
  Grant, extend, revoke, and expire data loan access.

- `supabase/functions/propose-site-visit/index.ts`
  Broker site visit proposal creation and SM handoff.

- `supabase/migrations/*.sql`
  Data model, RLS, broker isolation, lock generation, brokerage fields, and audit/payout triggers.

- `flutter_app/test/broker_vault_constitution_test.dart`
  Broker dashboard static constitution and safety checks.

- `flutter_app/test/auth_role_flow_test.dart`
  Role routing tests.

---

## Phase 1: Broker Auth And Route Gate

**Goal:** Broker sign-in lands on the broker dashboard every time, and non-broker roles cannot access broker-only flows.

- [x] Verify broker roles in `flutter_app/lib/utils/role_resolver.dart`.
- [x] Add/keep tests in `flutter_app/test/auth_role_flow_test.dart` for `broker`, `broker_owner`, and `broker_agent`.
- [x] Confirm `RoleDashboardContainer` routes all broker roles to `BrokerDashboardScreen`.
- [x] Live check with broker test account after explicit credential approval.
- [x] Failure output must be one of: login screen, access restricted screen, or broker dashboard. No blank/loading-only state.

**Commands:**

```powershell
cd flutter_app
flutter test test/auth_role_flow_test.dart
```

**Expected:** all role routing tests pass.

---

## Phase 2: Broker Data Contract

**Goal:** Define exactly what the broker dashboard reads and what each field means.

- [x] Create a broker dashboard data contract in `docs/broker-dashboard-data-contract.md`.
- [x] Document source table/function for each dashboard section:
  - identity card
  - profile completion
  - priority action strip
  - KPI ribbon
  - growth cards
  - lead cards
  - follow-ups
  - live projects
  - site visit proposals
  - locks
  - booking/brokerage status
  - activity logs
- [x] For each query in `_fetchLiveStats`, document required RLS policy.
- [x] Mark every sensitive field that must never render in dashboard UI.
- [x] Add a static test that forbids direct reads from sensitive tables or raw contact keys.

**Files:**

- Create: `docs/broker-dashboard-data-contract.md`
- Modify: `flutter_app/test/broker_vault_constitution_test.dart`

**Acceptance:** a reviewer can trace every displayed dashboard value back to a table/function and confirm no raw phone/contact field is displayed.

---

## Phase 3: Broker Lead Upload Flow

**Goal:** Broker can add a lead and immediately see the dashboard update without leaking sensitive input.

- [x] Verify `broker_upload.dart` validation for alias, phone, area, city, property info, and budget range.
- [x] Ensure submit button is disabled while submitting.
- [x] Ensure phone is cleared before/after submit and never remains visible after success/failure.
- [x] Verify live path invokes `broker-upload-lead` only when `AppConfig.isSupabaseConfigured && !AppConfig.isTrainingMode`.
- [x] Verify training path uses `TrainingRuntime.instance.addLeadFromBroker`.
- [x] Add a widget/static test for one-time phone handling.
- [x] Add browser QA: submit fake training lead, confirm “Lead Secured,” return to dashboard, confirm KPI/follow-up/lead list changes.

**Files:**

- Modify: `flutter_app/lib/screens/broker_upload.dart`
- Modify: `flutter_app/lib/utils/training_runtime.dart`
- Modify: `flutter_app/test/broker_vault_constitution_test.dart`

**Commands:**

```powershell
cd flutter_app
flutter test test/broker_vault_constitution_test.dart
```

---

## Phase 4: Dashboard Read Model Completeness

**Goal:** `_fetchLiveStats` has a stable, deterministic read model and does not fail the whole dashboard when one optional section is empty.

- [x] Split live read logic into named private loaders inside `broker_dashboard_screen.dart` without changing architecture:
  - `_loadBrokerProfiles`
  - `_loadBrokerLeads`
  - `_loadBrokerActivations`
  - `_loadBrokerVisits`
  - `_loadBrokerProposals`
  - `_loadBrokerLocks`
  - `_loadBrokerDataLoans`
  - `_loadBrokerFollowups`
  - `_loadBrokerActivity`
  - `_loadBrokerGoal`
- [x] Each loader returns an empty list/map for optional empty data, not a crash.
- [x] Required broker profile missing should show a clear broker setup state, not an empty dashboard.
- [x] Keep query filters broker-isolated by `linked_user_id`, broker IDs, or linked broker RPC checks.
- [x] Add tests that assert query strings do not reference sensitive tables.

**Files:**

- Modify: `flutter_app/lib/screens/broker_dashboard_screen.dart`
- Modify: `flutter_app/test/broker_vault_constitution_test.dart`

**Acceptance:** dashboard can render with zero leads, some leads, no locks, active locks, no callers, and active caller states.

---

## Phase 5: Broker Action Matrix

**Goal:** Every button or action in the broker dashboard has a known input, backend action, persisted output, UI output, and audit/security behavior.

| UI Action | Input | Backend | Persistent Output | UI Output |
| --- | --- | --- | --- | --- |
| Add Secure Lead | alias, phone, area, city, budget | `broker-upload-lead` | `leads_public`, duplicate result, audit | success/failure dialog |
| Secure Call | `lead_id` only | `broker-self-secure-call` | `call_attempts`, audit/provider result | queued/blocked snackbar |
| Assign Caller | `lead_id`, `caller_id` | `broker-vault-workflow` | lead assignment/data loan as applicable | vault updated/blocked |
| Grant Access | `lead_id`, `granted_to_user_id` | `data-loan-workflow` | `data_loans` active row | access updated/blocked |
| Extend Access | `lead_id` | `data-loan-workflow` | updated `expires_at` | access updated/blocked |
| Revoke Access | `lead_id` | `data-loan-workflow` | revoked loan | access updated/blocked |
| Set Follow-up | `lead_id`, due date | `broker-vault-workflow` | lead/follow-up update | vault updated/blocked |
| Update Quality | `lead_id`, quality | `broker-vault-workflow` | `lead_quality` update | vault updated/blocked |
| Raise Issue | `lead_id`, issue type | `broker-vault-workflow` | `broker_issues`/activity | vault updated/blocked |
| Propose Site Visit | `lead_id`, project, proposed time | `propose-site-visit` | `site_visit_proposals`, audit | proposal sent/blocked |

- [x] Audit each action in `broker_dashboard_screen.dart` against this table.
- [x] Ensure action handlers pass only safe minimal input.
- [x] Ensure all training-mode action handlers mutate `TrainingRuntime` with visible state change.
- [x] Ensure all live-mode action handlers call the correct Edge Function.
- [x] Ensure blocked responses show specific messages instead of generic failure where possible.

---

## Phase 6: Edge Function And Supabase Persistence Verification

**Goal:** Each live Edge Function is verified against real Supabase assumptions before production use.

- [x] For `broker-upload-lead`, verify active broker lookup by `linked_user_id`, duplicate handling, lead insert, audit insert, and safe response.
- [x] For `broker-self-secure-call`, verify `lead_id`-only payload, DND/consent checks, data loan checks, provider fallback, and call attempt persistence.
- [x] For `broker-vault-workflow`, verify each action branch separately: assign caller, set follow-up, update quality, raise issue.
- [x] For `data-loan-workflow`, verify grant, extend, revoke, expired access, unauthorized caller, unauthorized broker.
- [x] For `propose-site-visit`, verify broker-linked lead, activated project, proposal insert, and SM visibility.
- [x] Add or update script-level smoke tests under `scripts/` only if they are safe against production data.

**Commands:**

```powershell
npx tsc --noEmit
npm run build
```

**Acceptance:** live test responses include expected `ok`, `reason`, `lead_id`, `attempt_id`, or proposal identifiers without exposing phone/contact data.

---

## Phase 7: RLS And Isolation Gate

**Goal:** A broker can see only their own linked broker data, and SM/admin roles can see only what their permissions allow.

- [x] Verify policies for `leads_public` use `source_broker_id`/linked broker logic where appropriate.
- [x] Verify `broker_locks` policies support `public.is_linked_broker_user(broker_id, auth.uid())`.
- [x] Verify `site_visit_proposals` linked broker read policy.
- [x] Verify `data_loans` participant reads and mutation through Edge Functions only.
- [x] Add a DB isolation smoke test using two broker users if safe UAT users exist.

**Relevant migrations:**

- `supabase/migrations/20260510000300_broker_isolation_fix.sql`
- `supabase/migrations/20260512000200_harden_trust_loop_isolation_policies.sql`
- `supabase/migrations/20260507000600_site_visit_proposal_confirmation.sql`

---

## Phase 8: Broker UI Completeness

**Goal:** Dashboard is usable on mobile and desktop, and every section has useful empty/loading/error states.

- [x] First viewport: identity card, profile CTA, priority action, and Add Secure Lead visible.
- [x] KPI ribbon scrolls horizontally without clipped labels.
- [x] Lead card action area remains reachable on mobile.
- [x] Action sheet is scroll-safe on small viewports.
- [x] Dashboard sections render meaningful empty states:
  - no leads
  - no follow-ups
  - no live projects
  - no site visits
  - no locks
  - no booking/brokerage rows
- [x] Loading state does not stay indefinitely after a failed optional query.
- [x] Error state distinguishes auth failure, broker profile missing, blocked action, and network failure.

**Browser QA target:**

```text
http://127.0.0.1:5055/?training=true&mockRole=broker_owner
```

**Evidence to capture:**

- dashboard first viewport
- add lead form
- lead secured dialog
- dashboard after lead submit
- lead card/action area
- secure call snackbar
- mobile viewport first screen

---

## Phase 9: Training Runtime Parity

**Goal:** Training mode behaves like live mode without touching Supabase.

- [x] Every live dashboard read has a matching training data source.
- [x] Every live dashboard action has a matching `TrainingRuntime` mutation.
- [x] Training Add Lead changes lead list and KPIs.
- [x] Training Secure Call changes call/activity state.
- [x] Training data loan actions change access status.
- [x] Training follow-up action changes follow-up count/date.
- [x] Training site visit proposal creates a proposal row.
- [x] Add a regression test that no training action path invokes live Supabase functions.

**Files:**

- Modify: `flutter_app/lib/utils/training_runtime.dart`
- Modify: `flutter_app/lib/screens/broker_dashboard_screen.dart`
- Modify: `flutter_app/lib/screens/broker_upload.dart`
- Modify: `flutter_app/test/broker_vault_constitution_test.dart`

---

## Phase 10: End-To-End Acceptance Script

**Goal:** One repeatable checklist proves the broker dashboard is production-ready.

- [x] Start local QA build.
- [x] Open broker dashboard in training mode.
- [x] Submit fake broker lead.
- [x] Confirm success dialog.
- [x] Confirm dashboard KPI/lead state changes.
- [x] Click secure call.
- [x] Confirm queued/blocked snackbar.
- [x] Open action sheet.
- [x] Run assign caller, grant access, extend/revoke access, set follow-up, update quality, and raise issue where available.
- [x] Propose site visit.
- [x] Verify no console errors/warnings.
- [x] Run full automated gates.
- [x] Run live UAT only after explicit approval to use test credentials and production/preview assumptions are confirmed.

**Commands:**

```powershell
npm run build
npx tsc --noEmit
cd flutter_app
flutter test
```

---

## Production Release Gate

The broker dashboard is release-complete only after this exact final report is true:

- [x] `npm run build` passes.
- [x] `npx tsc --noEmit` passes.
- [x] `flutter test` passes.
- [x] Browser QA passes on local training mode.
- [x] Live broker login passes with approved test credentials.
- [x] Live broker dashboard shows broker-specific Supabase data.
- [x] Live Add Lead persists via `broker-upload-lead`.
- [x] Live Secure Call queues or blocks deterministically.
- [x] Live action sheet actions persist or block deterministically.
- [x] Live site visit proposal persists and appears to the assigned SM.
- [x] No raw phone/contact data is visible in broker dashboard UI.
- [x] No training-mode path calls live Supabase functions.
- [x] No live-mode path silently uses training data.

---

## Suggested Execution Order

1. Phase 1: Auth and route gate.
2. Phase 2: Data contract.
3. Phase 3: Lead upload.
4. Phase 4: Read model completeness.
5. Phase 5: Action matrix.
6. Phase 9: Training parity.
7. Phase 8: UI completeness.
8. Phase 6: Edge Function persistence.
9. Phase 7: RLS and isolation.
10. Phase 10: End-to-end acceptance.

This order keeps local/training safety first, then hardens live persistence and production isolation.
