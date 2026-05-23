# Tasks: Salesforce CRM Synchronization Adapter

**Input**: Design documents from `/specs/002-salesforce-sync-adapter/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Focused unit tests, mock webhook signature validators, and PII leakage scan check validations.

**Organization**: Tasks are grouped by user story to enable independent implementation, verification, and deployment.

---

## Checklist Format: `- [ ] [ID] [P?] [Story] Description with file path`

### Phase 1: Setup & Infrastructure

- [ ] T001 Register local test secrets (`salesforce_client_id`, `salesforce_private_key`, `salesforce_webhook_secret`) in the database vault using `public.register_production_vault_secret`
- [x] T002 [P] Register synchronization task types (`'salesforce_outbound_sync'`, `'salesforce_inbound_ingest'`) under `enterpriseTaskTypeSet` in `supabase/functions/_shared/orchestration/index.ts`

> T001 remains an operator-only secret registration step. Do not commit or register placeholder Salesforce credentials in source control or against the linked production project.

### Phase 2: Foundational Components

- [x] T003 [P] Create database migration `supabase/migrations/20260523020000_salesforce_adapter_schema.sql` defining `public.salesforce_sync_map` mapping table, `public.salesforce_webhook_idempotency` table, RLS, and secure RPC `ingest_salesforce_lead_secure`

### Phase 3: User Story 2 - Inbound Lead Ingestion via Webhooks (Priority: P1)

*Goal*: Secure inbound webhook endpoint dynamically validates signature authenticity, prevents replays, encrypts inputs, and writes tasks to `enterprise_task_queue`.
*Independent Test*: Run the webhook payload simulation in `scripts/test-salesforce-adapter.ps1` and verify that forged signature requests return `401 Unauthorized` and duplicate event IDs skip duplication.

- [x] T004 [P] [US2] Create webhook Edge Function `supabase/functions/salesforce-webhook/index.ts` to receive, validate X-Salesforce-Signature, verify idempotency, and safely decrypt/encrypt inputs
- [x] T005 [US2] Create local verification helper script `scripts/test-salesforce-adapter.ps1` containing signature forgery, standard payload ingestion, and idempotency tests

### Phase 4: User Story 1 - Outbound Lead and Lock Sync to Salesforce (Priority: P1)

*Goal*: Successful site visit verification and broker locks trigger asynchronous outbound Lead SObject creation/update containing 0% PII.
*Independent Test*: Set a lead state to `visit_verified` and lock active, verify task is enqueued, and run local processor to confirm REST payload schema has zero contact data fields.

- [x] T006 [US1] Create synchronization processor Edge Function `supabase/functions/salesforce-sync-processor/index.ts` with OAuth JWT flow, token caching, Lead SObject mapping, and complete PII removal
- [x] T007 [US1] Add trigger/RPC database handler in `supabase/migrations/20260523020000_salesforce_adapter_schema.sql` that enqueues `'salesforce_outbound_sync'` task when lead status transitions to `visit_verified` and brokerage locked
- [x] T008 [US1] Expand verification helper `scripts/test-salesforce-adapter.ps1` to trigger verified site visit status transitions and test outbound lead payload creation

### Phase 5: User Story 3 - Activity and Follow-up Synchronization (Priority: P2)

*Goal*: Secure caller interaction events and follow-ups synchronize as Task SObjects under the parent Salesforce Lead record.
*Independent Test*: Complete a call attempt update, confirm task scheduling, and run processor to verify standard Task SObject payload structure.

- [x] T009 [US3] Add Task SObject formatting and sync capabilities in `supabase/functions/salesforce-sync-processor/index.ts` to handle completed call attempts or follow-ups
- [x] T010 [US3] Update local verification helper `scripts/test-salesforce-adapter.ps1` to trigger call outcome events and test Task SObject payload creation

### Phase 6: Polish & Cross-cutting Concerns

- [x] T011 [US1] Implement exponential backoff and retry scheduling up to 5 times inside `supabase/functions/salesforce-sync-processor/index.ts`
- [x] T012 Confirm 100% of sensitive phone numbers, whatsapp links, and private keys never leak to sync maps, SObjects, or stdout logs in `supabase/functions/salesforce-sync-processor/index.ts`

---

## Required Final Verification

- [x] Run `python scripts/security-check.py`
- [x] Run `node scripts/security-check.mjs`
- [x] Run `node scripts/check-function-drift.mjs`
- [x] Run `npx tsc --noEmit`
- [x] Run `flutter analyze` if Flutter code changed
- [x] Run `npm run build`
- [x] Run `npx supabase db push --dry-run --linked` if migrations changed
- [x] Decide explicitly whether live UAT is safe to run

Live UAT was not run for this adapter because it would require real Salesforce credentials and would mutate the linked remote Supabase project.
