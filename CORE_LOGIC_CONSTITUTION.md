# The Sourcing Manager OS — Full Project Core Logic & Constitution

## 1. One-Line Definition

The Sourcing Manager OS is a trust-gated real estate sourcing enforcement layer that helps sourcing managers activate brokers, collect broker leads, verify site visits, protect broker credit, and prove performance without exposing sensitive customer or broker contact data.

## 2. Core Constitution (Immutable Rules)

1. **Phone numbers are never visible.**
2. **No masked phone numbers.**
3. **No last-four-digit display.**
4. **No WhatsApp direct links.**
5. **No browser tel: links.**
6. **No contact export.**
7. **No phone numbers in logs.**
8. **No phone numbers in audit events.**
9. **No phone numbers in browser network payloads.**
10. **Phone numbers are stored only as encrypted ciphertext.**
11. **Decryption happens only inside Edge Functions.**
12. **Decryption happens only in memory.**
13. **Decrypted value is wiped immediately after use.**
14. **Calls happen only through PSTN bridge such as Exotel.**
15. **Database uses RLS everywhere.**
16. **Default deny access.**
17. **Every sensitive action requires role, permission, organization, and data loan checks.**
18. **Audit logs are append-only.**
19. **System fails closed.**
20. **Convenience never overrides enforcement.**

## 3. Main Product Logic

The app has two connected layers:

- **Layer A — Practical Sourcing Manager MVP**: Daily workflow for Vinod (SM) - Call brokers, track follow-ups, activate pipeline, collect leads, verify visits.
- **Layer B — Enterprise Enforcement Core**: Security infrastructure - Encryption, Secure Call, Data Loans, GPS/Photo proof, Audit, RBAC.

## 4. Practical MVP Database Model

### 4.1 `brokers_public` (Metadata)

- **Fields**: id, organization_id, assigned_sourcing_manager_id, broker_alias, broker_name, company_name, area, city, speciality, category, interest_level, status, notes_safe, created_by, created_at, updated_at.
- **Categories**: new, warm, hot, active, inactive, dead.
- **Interest**: unknown, low, medium, high.

### 4.2 `brokers_sensitive` (Encrypted)

- **Fields**: broker_id, phone_ciphertext, email_ciphertext, encryption_version, created_at.
- **Access**: NO frontend SELECT. Edge Function only.

### 4.3 `broker_activations` (Pipeline)

- **Fields**: id, organization_id, broker_id, project_id, assigned_sourcing_manager_id, activation_stage, potential_score, last_contacted_at, next_followup_at, stage_notes.
- **Stages**: not_contacted, first_call_done, project_explained, inventory_shared, offer_shared, interested, meeting_scheduled, lead_expected, active_broker, dead_not_interested.

### 4.4 `broker_activity_logs` (History)

- **Fields**: id, organization_id, broker_id, project_id, actor_id, activity_type, outcome, notes_safe, next_followup_at.
- **Types**: call_attempt, call_connected, project_pitch, inventory_shared, offer_shared, meeting_scheduled, followup_set, lead_received, inactive_marked, note_added.
- **Rules**: Sanitize contact-like text from notes.

### 4.5 `broker_followups` (Queue)

- **Fields**: id, organization_id, broker_id, project_id, assigned_to, due_at, priority, status, reason.

## 5. Site Visit & Verification Logic

- **State Machine**: scheduled -> started -> gps_submitted -> gps_verified -> photo_uploaded -> photo_verified -> broker_review_pending -> broker_approved -> completed.
- **GPS Verification**: Server-side distance calculation (geofencing).
- **Photo Evidence**: Private bucket, SHA-256 hash, no PII in file path.
- **Broker Lock**: 45-day lock created ONLY after verified visit and broker approval.

## 6. Trust & Abuse Monitoring

- **Trust Score**: Signal-based (verified events), not manual opinion. Append-only audit.
- **Abuse Monitoring**: Detects GPS spoofing, photo overwrite, loan expiry bypass, and spike in rejections.

## 7. Practical MVP Build Phases

1. **Phase 1: Broker CRM** (Brokers, Add, List, Detail, Queue) - **IN PROGRESS**
2. **Phase 2: Broker Activation Pipeline** (Pitch board, stage filters)
3. **Phase 3: Lead From Broker** (Intake, encrypted contact, status)
4. **Phase 4: Site Visit Tracker** (GPS/Photo proof, review)
5. **Phase 5: Broker Performance Proof** (Rollups, ROI)

---
**This document is the Ground Truth for all development. Deviation requires constitutional amendment.**
