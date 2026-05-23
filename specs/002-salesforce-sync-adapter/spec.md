# Feature Specification: Salesforce CRM Synchronization Adapter

**Feature Branch**: `002-salesforce-sync-adapter`

**Created**: 2026-05-23

**Status**: Implemented pending operator Salesforce secret registration

**Input**: User description: "Salesforce CRM synchronization adapter"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Outbound Lead and Lock Sync to Salesforce (Priority: P1)

When a lead is successfully verified and locked in the Sourcing Manager OS, the system synchronizes the public lead metadata, assigned project, and active broker lock details to Salesforce as a new or updated Lead/Opportunity.

**Why this priority**: Outbound sync ensures Salesforce is kept up-to-date with active real estate allocations, verified statuses, and commission locks in real-time, preventing conflicts and double-selling.

**Independent Test**: Trigger a verified site visit on a sourced lead, confirm that the system enqueues an outbound sync task, and confirm that the Salesforce adapter safely translates the payload into standard Salesforce SObject creation/update payloads without including any restricted contact data.

**Acceptance Scenarios**:

1. **Given** a lead whose status is updated to `visit_verified` and brokerage is `locked`, **When** the synchronization task triggers, **Then** the adapter formats the payload to create/update a Lead record in Salesforce containing the lead UUID, alias, assigned sourcing manager, and locked broker details.
2. **Given** the outbound sync payload is generated, **When** it is parsed, **Then** it MUST NOT contain any raw contact numbers, masked digits, or private buyer identification.

---

### User Story 2 - Inbound Lead Ingestion via Webhooks (Priority: P1)

When a lead is captured or updated in Salesforce, Salesforce triggers a secure HTTPS webhook. The Sourcing Manager OS adapter receives the payload, validates its authenticity, sanitizes inputs, and enqueues it to the asynchronous task queue for orchestrator ingestion.

**Why this priority**: Live inbound ingestion from Salesforce connects external sales pipelines into the secure calling and verification engine of Sourcing Manager OS.

**Independent Test**: POST a simulated Salesforce lead payload to the webhook endpoint, confirm that forged signatures fail closed, and confirm that valid payloads successfully ingest as a queued task.

**Acceptance Scenarios**:

1. **Given** a webhook request from Salesforce with an invalid or missing signature, **When** the endpoint processes the request, **Then** it rejects the request with a `401 Unauthorized` status and logs an audit event.
2. **Given** a valid webhook signature and active organization context, **When** the payload is processed, **Then** standard inputs (alias, area, city, budget) are sanitized, phone values are validated and queued for secure encryption, and a task is successfully written to the `enterprise_task_queue`.

---

### User Story 3 - Activity and Follow-up Synchronization (Priority: P2)

When a secure call or follow-up is logged by a caller in Sourcing Manager OS, the system synchronizes this interaction as an Activity Task under the corresponding Salesforce Lead record to maintain a unified conversation history.

**Why this priority**: Operational tracking requires sales managers in Salesforce to see the activity and trust engagement levels of all leads without direct database access.

**Independent Test**: Complete a secure call outcome update in the UAT environment, and verify that the sync service schedules a task update for the Salesforce Lead containing only compliance metadata (call duration, general outcome category, and safe notes).

**Acceptance Scenarios**:

1. **Given** a completed call attempt or follow-up event, **When** the outbound sync runs, **Then** a Task SObject is created in Salesforce containing the duration, outcome state, and scrubbed, PII-free call notes.

### Edge Cases

- **Credential Expiry/Failure**: If Salesforce OAuth tokens expire or request rate-limits are reached, the adapter MUST fail closed, record a system health warning, queue the retry task in `enterprise_task_workflow` with exponential backoff, and escalate to the recovery queue.
- **Webhook Replay**: If the same Salesforce event ID is posted multiple times, the webhook adapter MUST enforce idempotency by checking duplicate event signatures before enqueuing a duplicate task.
- **Mismapped SObjects**: If Salesforce custom fields or schemas differ, the adapter MUST capture parsing errors as recovery tickets without disrupting core lead processing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support bi-directional metadata synchronization between Sourcing Manager OS and Salesforce.
- **FR-002**: Webhook endpoint MUST validate signature integrity using a shared secret token before parsing Salesforce payloads.
- **FR-003**: Webhook endpoint MUST reject malformed or blank payloads with a stable `400 Bad Request` code.
- **FR-004**: System MUST encrypt and hash restricted contact numbers received via webhook through Deno/Postgres secure ingestion before committing to public tables.
- **FR-005**: System MUST enqueue inbound webhook events as `pending` task payloads in the `enterprise_task_queue`.
- **FR-006**: Outbound synchronization tasks MUST run asynchronously to prevent blocking core workflows.
- **FR-007**: Outbound synchronization payloads MUST be completely metadata-only and exclude raw or masked buyer contact fields.
- **FR-008**: Outbound tasks MUST track execution history in `enterprise_task_history` and support automatic retries on network failures.
- **FR-009**: System MUST record all sync transactions, authentication failures, and rate limits in `audit_events`.

### Security, Privacy, and Audit Requirements

- **SR-001**: Salesforce API credentials, Client IDs, and private keys MUST be stored securely as Supabase Vault secrets and never committed to source files.
- **SR-002**: All outbound and inbound data flows MUST be strictly PII-safe, ensuring zero raw contact leakage (complying with the Sourcing Manager OS Constitution).
- **SR-003**: Webhook connections and REST requests MUST fail closed if signatures, OAuth handshakes, or security checks are invalid.

### Key Entities *(include if feature involves data)*

- **Salesforce Adapter Config**: Protected credential metadata and webhook configuration.
- **Enterprise Task Queue**: Database queue table used to serialize synchronization tasks.
- **Audit Event**: Append-only transaction log proving who, when, and what synchronized.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Webhook endpoint rejects 100% of invalid signatures and forged payloads.
- **SC-002**: 100% of successful lead updates, locks, and secure calls trigger an asynchronous outbound sync task.
- **SC-003**: 0% of contact numbers or PII fields leak into Salesforce REST payloads or local debug logs.
- **SC-004**: System automatically retries failed Salesforce connections up to 5 times with exponential backoff before escalating to human review.

## Assumptions

- Salesforce connection utilizes the standard Salesforce REST API (OAuth 2.0 JWT Bearer flow).
- Salesforce organization is configured to send outgoing events via secure webhooks with signature headers.
- Safe default fields (alias, area, city, project ID) map directly to standard Salesforce Lead attributes.
