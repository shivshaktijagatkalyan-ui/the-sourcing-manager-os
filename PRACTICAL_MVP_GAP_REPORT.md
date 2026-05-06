# Practical MVP Gap Report - Sourcing Manager OS

This report audits the current codebase against the **Practical MVP (Phase 1-5)** requirements for Vinod's daily sourcing manager operations at The Wadhwa Wise City, Panvel.

## 1. Feature Status Audit

| Feature | Status | Location | Notes |
| :--- | :--- | :--- | :--- |
| **Broker table/model** | **Completed** | Database | Partitioned public metadata and encrypted sensitive store. |
| **Add Broker screen** | **Completed** | Flutter | Secure entry with encrypted-and-discarded phone logic. |
| **Broker List screen** | **Completed** | Flutter | CRM list with category filtering and secure call action. |
| **Broker Detail screen** | **Completed** | Flutter | Timeline, activation controls, and secure call bridge. |
| **Broker Follow-up Queue** | **Completed** | Flutter | "Today's Calls" logic for Sourcing Managers. |
| **Broker Activation Pipeline** | **Completed** | Database | 10-stage tracking mechanism implemented in `broker_activations`. |
| **Broker Call Logs** | **Completed** | Database | `broker_activity_logs` table implemented with audit triggers. |
| **Lead From Broker flow** | **Completed** | `lead-from-broker.ts` | Secure lead entry with source tracking and PII encryption. |
| **Site Visit Tracker (Source)** | **Completed & Verified** | `leads_public` | Fully integrated with broker source tracking and GPS verification. |
| **Activation Pipeline Board** | **Completed & Verified** | Flutter | Kanban-style overview of entire broker database. |
| **Role Dashboard Layer** | **Completed & Verified** | Flutter | Specialized views for Sourcing Manager, Broker, and Caller roles. |
| **PII-Safe Dashboards** | **Completed & Verified** | Flutter | All dashboards purged of phone numbers and external links. |

## 2. Infrastructure Requirements

### Database Migrations Required

- **`public.brokers`**: Master table for external brokers (Encrypted Phone, Category, Speciality).
- **`public.broker_activations`**: Links brokers to specific projects (e.g., Wadhwa Wise City) with the 10-stage pipeline.
- **`public.broker_activity_logs`**: Tracks calls, follow-up notes, and project pitch outcomes.
- **`public.broker_followups`**: Scheduled tasks for daily queues.

### Edge Functions Required

- **`manage-external-broker`**: [COMPLETED] Securely handles creation/encryption of external broker data.
- **`initiate-broker-call`**: [COMPLETED] Extends the PSTN Secure Call logic to the broker CRM.
- **`update-activation-stage`**: [INCORPORATED] Logic moved into `manage-external-broker`.

### Flutter Screens Required

1. **`SourcingManagerHome`**: Dashboard with "Today's Follow-ups".
2. **`BrokerCrmList`**: Filterable list of all brokers.
3. **`AddBrokerWizard`**: Secure entry form for new brokers.
4. **`BrokerProfileView`**: Activity history and activation status.

## 3. Security & Compliance

- **Dataless Constitution**: All external broker phone numbers MUST be stored as ciphertext using `PHONE_ENCRYPTION_KEY`.
- **No Direct Calls**: "Secure Call" must be the only way to reach a broker from the CRM.
- **Audit Integrity**: Every follow-up note and status change must generate an `audit_event`.

## 4. Next Build Order (Practical MVP v0.1)

1. **[DB]** Create `brokers`, `broker_activations`, and `broker_activity_logs` tables.
2. **[EF]** Deploy `manage-external-broker` and `initiate-broker-call`.
3. **[UI]** Build **Add Broker** screen with encrypted phone entry.
4. **[UI]** Build **Broker List** with search/filter by Category.
5. **[UI]** Build **Broker Detail** with activity timeline.
6. **[UI]** Build **Today's Follow-up Queue** logic and screen.
7. **[UI]** Implement the **10-stage Activation Pipeline** tracker.

---

**Verdict**: The **Sourcing Manager CRM Layer** and **Role-Based Dashboard System** are now fully implemented and verified against the security constitution. The system is ready for Pilot Operations with distinct, PII-safe views for all key stakeholders.
