# Enterprise Architecture Task List

Generated: 2026-05-23
Project: The Sourcing Manager OS / FutureTrust Real Estate OS

## Phase 0: Security Hardening

- [x] Add local `.env` secret audit script: `scripts/audit-env-secrets.mjs`
- [x] Harden `supabase/functions/_shared/sprint7.ts` for safe input, webhook signature validation, MIME/magic-number checks, and secret environment gating
- [x] Enforce JWT and `currentUser` validation on all client endpoints
- [x] Add API versioning and header-based version checks on new orchestrator entrypoints
- [x] Harden `upload-site-photo` to allow only JPEG/PNG, maximum 5MB
- [x] Review `.github/workflows/dependency-scan.yml` and `.github/dependabot.yml` schedules

## Phase 1: Foundation and Data Model

- [x] Create enterprise task queue migration in `supabase/migrations/20260523000000_enterprise_task_queue.sql`
- [x] Add task workflow, task history, and human review queue tables
- [x] Add `pgvector` support where needed for semantic guardrails
- [x] Add audit helper functions for task orchestration events

## Phase 2: Orchestrator and Agent Layer

- [x] Scaffold `supabase/functions/enterprise-orchestrator/index.ts`
- [x] Add shared orchestration helpers in `supabase/functions/_shared/orchestration/index.ts`
- [x] Add shared guardrail helpers in `supabase/functions/_shared/guardrails/index.ts`
- [x] Implement task ingestion, state transition, and audit logging stubs

## Phase 3: Human Review and Compliance

- [x] Add human review queue processing and status flow
- [x] Create review Edge Functions for approve/reject workflows
- [x] Add safe read views and audit metadata fields for reviewers

## Phase 4: Enterprise Connectors

- [x] Define enterprise connector contracts for SAP, Salesforce, CDC, storage, SMTP, and LDAP
- [x] Add connector scaffold directories in `supabase/functions/enterprise-connectors/`
- [x] Keep enterprise adapters isolated from core orchestrator logic

## Phase 5: Validation and Release Gate

- [x] Add smoke tests for orchestrator flow, task queue, and review escalation
- [x] Add release gate support in scripts for enterprise orchestration checks
- [x] Document implementation and verification details in `docs/architecture/`

## Notes

- Prefer additive changes and preserve current privacy controls.
- Ensure all new endpoints are service-role protected and audit-safe.
- Keep all file uploads and external integrations strictly validated.
