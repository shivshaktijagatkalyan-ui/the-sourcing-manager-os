# Sprint 3: Dispute, Trust Score & Pilot Operations Layer

## Goal
Convert verified lead activity, call attempts, GPS/photo evidence, broker approvals, and commission locks into an operational trust system for pilot users.

## Core Principles
1. **Trust is Calculated**: Scores are derived from verified system events (audit logs), not user claims.
2. **PII Isolation**: No phone numbers or names in timelines, disputes, or trust metrics.
3. **Evidence-First Disputes**: Resolution relies on the evidence chain (GPS, hashes, timestamps).
4. **Administrative Guardrails**: Role-based access with "Fail Closed" logic for disabled users/orgs.

## Modules

### 1. Pilot Operations (Foundations)
- [ ] Table: `organizations` (id, name, status, created_at)
- [ ] Table: `pilot_users` (id, user_id, org_id, role, status, metadata)
- [ ] RLS: Organizations and users must fail-closed if `status != 'active'`.
- [ ] Edge Function: `admin-pilot-action` for activation/deactivation.

### 2. Evidence Timeline View
- [ ] View: `v_evidence_timeline` (lead_id, event_type, context, timestamp)
- [ ] Source: Aggregates from `audit_events`.
- [ ] Privacy: Filters out any potential PII from `event_context`.

### 3. Dispute Resolution Engine
- [ ] Table: `disputes` (id, target_id, target_type, org_id, type, status, created_at)
- [ ] Table: `dispute_events` (id, dispute_id, actor_id, event_type, comment, evidence_refs)
- [ ] Edge Functions: `open-dispute`, `add-dispute-event`, `resolve-dispute`.

### 4. Trust Scoring Engine
- [ ] Table: `trust_scores` (entity_id, entity_type, score, components_json, last_updated_at)
- [ ] Edge Function: `calculate-trust-score` (triggered by major audit events).
- [ ] Signals: Call connectivity, GPS verification rate, broker approval rate, dispute history.

### 5. Abuse Monitoring & Alerts
- [ ] Dashboard View: Aggregates GPS failures and out-of-hours activity.
- [ ] Edge Function: `flag-abuse-event` for automated alerting.

### 6. Flutter PWA Updates
- [ ] Screen: Pilot Admin Dashboard.
- [ ] Screen: Evidence Timeline (linked to lead/visit).
- [ ] Screen: Dispute Management.
- [ ] Screen: Trust Score Profile.

## Implementation Schedule

1. **Week 1: Foundations & Disputes** (Schema, RLS, Organization logic, Dispute API).
2. **Week 2: Trust & Evidence** (Timeline view, Trust Scoring Engine, Abuse detection).
3. **Week 3: Admin Console & UI** (Flutter PWA screens, final auditing).

## Acceptance Gate (Sprint 3)
- [ ] Disabled pilot user cannot perform any protected actions.
- [ ] Dispute timeline verified clear of PII.
- [ ] Trust score correctly reflects a rejected GPS attempt.
- [ ] Evidence timeline accurately reconstructs a site visit from `audit_events`.
