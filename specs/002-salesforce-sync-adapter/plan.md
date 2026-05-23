# Implementation Plan: Salesforce CRM Synchronization Adapter

**Branch**: `002-salesforce-sync-adapter` | **Date**: 2026-05-23 | **Spec**: [spec.md](file:///c:/Users/iBUGG3D/Desktop/The%20Sourcing%20MAnager%20OS/specs/002-salesforce-sync-adapter/spec.md)

**Input**: Feature specification from `specs/002-salesforce-sync-adapter/spec.md`

## Summary

Implement a bi-directional Salesforce CRM synchronization adapter that handles secure, asynchronous data flows between the Sourcing Manager OS and Salesforce. The architecture leverages OAuth 2.0 JWT Bearer authentication, secure storage of API credentials and webhook secrets in the Supabase Vault registry, inbound webhook ingestion via signature validation (HMAC hex checks), and queue-based outbound task scheduling for Lead metadata, Lock states, and secure call outcome Activities. Outbound payloads are strictly stripped of PII fields (contact numbers, caller names) to fully conform to the Dataless Constitution.

---

## Technical Context

**Language/Version**: Dart/Flutter 3.x, TypeScript/Deno for Edge Functions, SQL/PLpgSQL for migrations
**Primary Dependencies**: Supabase CLI, Supabase Vault, Postgres PG Crypto, Deno std/crypto for signature verification, Salesforce REST API (JWT Bearer flow)
**Storage**: Supabase PostgreSQL with `enterprise_task_queue` queue processing, `audit_events` for secure append-only audit tracking.
**Testing**: `supabase functions serve` local payload simulation, webhook replay tests, forged signature rejection checks, type and lint checks (`npx tsc --noEmit`), and dry-run migration pushes.
**Target Platform**: Supabase Edge Functions, Supabase PostgreSQL, local Windows PowerShell dev tools.
**Project Type**: Serverless-driven sync adapter backed by secure database orchestration.
**Performance Goals**: Inbound ingestion responds in <100ms; outbound queue jobs execute asynchronously with up to 5 retries using backoff, logging all execution history.
**Constraints**: Zero PII (contact numbers, caller IDs, WhatsApp links) in outbound REST payloads or sync history. Webhooks must enforce signature verification and fail-closed security.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Deterministic Trust Flow**: Explicit status transitions (`visit_verified` -> queue sync) trigger the Salesforce integration. No AI-driven bypass of these statuses exists.
- **Supabase Source of Truth**: The `enterprise_task_queue` and associated `enterprise_task_workflow` serve as the authoritative queue for syncing.
- **Protected Actions only via Edge Functions**: OAuth handshakes, webhook verification, and Salesforce API transactions run entirely within secure Edge Functions with JWT and permission verification.
- **Audit, Privacy, and Fail-Closed**: Signature verification failure, OAuth handshake failures, or credential expiration immediately trigger a fail-closed response, log to `audit_events`, and trigger retry queues. Outbound sync strips all PII fields (contact phone, caller identity).
- **Verification Before Completion**: Automated tests, lint scans, and manual UAT validations are fully documented in the Verification Plan.

---

## User Review Required

> [!IMPORTANT]
> The integration utilizes the standard **Salesforce OAuth 2.0 JWT Bearer Flow** using a digital certificate. The private key and OAuth client ID must be uploaded to the Supabase Vault via the secure helper `register_production_vault_secret` to enable token generation. This keeps credentials out of the repository codebase.

> [!WARNING]
> To enable Salesforce task creation, the shared `_shared/orchestration/index.ts` file must be expanded to register `salesforce_outbound_sync` and `salesforce_inbound_ingest` as valid task types.

---

## Open Questions

- *None.* All ambiguities regarding OAuth flow and payload design have been resolved using standard client-server adapter design principles.

---

## Proposed Changes

### Database Tier

Summary: Add helper schemas and configs for Salesforce synchronization. This includes tables for tracking Salesforce mappings, sync logs, and webhook replay signatures.

#### [NEW] [20260523020000_salesforce_adapter_schema.sql](file:///c:/Users/iBUGG3D/Desktop/The%20Sourcing%20MAnager%20OS/supabase/migrations/20260523020000_salesforce_adapter_schema.sql)
- Creates `public.salesforce_sync_map` to link Sourcing Manager OS leads/opportunities to Salesforce SObject IDs.
- Creates `public.salesforce_webhook_idempotency` to store webhook event hashes to block replay attacks.
- Secure RPC `ingest_salesforce_lead_secure` to decrypt/re-encrypt inbound phone numbers into Dataless compliance storage.

---

### Supabase Edge Functions

Summary: Add Deno serverless functions to act as the inbound webhook receiver and the outbound task processor.

#### [NEW] [salesforce-webhook/index.ts](file:///c:/Users/iBUGG3D/Desktop/The%20Sourcing%20MAnager%20OS/supabase/functions/salesforce-webhook/index.ts)
- Receives inbound HTTPS POST webhooks from Salesforce.
- Validates the signature header `X-Salesforce-Signature` using HMAC SHA256 against the shared webhook secret from Supabase Vault.
- Validates idempotency against `salesforce_webhook_idempotency`.
- Sanitizes incoming payload and triggers `ingest_salesforce_lead_secure` database routine to safely ingest the lead.
- Queues task to `enterprise_task_queue` under type `salesforce_inbound_ingest`.

#### [NEW] [salesforce-sync-processor/index.ts](file:///c:/Users/iBUGG3D/Desktop/The%20Sourcing%20MAnager%20OS/supabase/functions/salesforce-sync-processor/index.ts)
- Outbound queue task processor triggered by task worker.
- Connects to Salesforce using JWT Bearer authentication with private key from Vault.
- Syncs Lead status (`visit_verified`), broker lock, and completed call Activities to Salesforce REST API.
- Completely strips contact numbers and names from REST payloads.
- Records result in `salesforce_sync_map` and updates `enterprise_task_workflow` / `enterprise_task_history`.

#### [MODIFY] [_shared/orchestration/index.ts](file:///c:/Users/iBUGG3D/Desktop/The%20Sourcing%20MAnager%20OS/supabase/functions/_shared/orchestration/index.ts)
- Registers new enterprise task types: `'salesforce_outbound_sync'` and `'salesforce_inbound_ingest'`.

---

## Verification Plan

### Automated Tests
- Command: `supabase functions serve`
- Local PowerShell script `scripts/test-salesforce-adapter.ps1` to:
  1. POST simulated lead webhooks with invalid signatures to confirm `401 Unauthorized` rejection.
  2. POST simulated lead webhooks with valid signatures to confirm successful ingestion to `leads_public` and `enterprise_task_queue`.
  3. POST identical payloads consecutively to verify webhook replay/idempotency protection.
  4. Invoke outbound sync process to confirm the REST payload is correctly formatted and contains 0% PII.
- Build and lint checks:
  - `npx tsc --noEmit` on Edge Functions to verify types.
  - `python scripts/security-check.py` to verify PII compliance.

### Manual Verification
- Ask reviewer to deploy migrations and Edge Functions using `supabase db push` and `supabase functions deploy`.
- Configure test Salesforce Dev Org with webhook and confirm real-time bi-directional synchronization.

---

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
