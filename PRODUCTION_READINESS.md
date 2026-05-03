# Production Readiness Gate

Project: The Sourcing Manager OS
Current version: `v0.3.0-trust`
Sprint 1 v0.1.0: ACCEPTED / FROZEN
Sprint 2 v0.2.0-stable: ACCEPTED / FROZEN
Sprint 3 v0.3.0-trust: PASSED
Pilot users: AUTHORIZED & ONBOARDING
Deployment log timestamp reported: `2026-05-03 21:31:34Z`

## Sprint 1: Enforcement Spine

Status: `STABLE`

Core guarantees:

- [x] RLS enabled and forced on Sprint 1 protected tables
- [x] No frontend policy on `leads_sensitive`
- [x] Phone numbers stored only as encrypted ciphertext
- [x] No direct browser calling links
- [x] No WhatsApp links
- [x] No masked or partial contact display
- [x] No raw Exotel callback payload storage
- [x] `initiate-call` accepts only `lead_id`
- [x] Active data loan required before decryption
- [x] Consent and DND checks block calls
- [x] Revoked and expired loans block calls
- [x] Audit events append-only
- [x] Security scanner enabled

## Sprint 2: Site Visit Verification Engine

Status: `DEPLOYED, ACCEPTANCE PASSED`

Reported hardening completed:

- [x] Direct frontend `UPDATE` access to verification-owned `site_visits` transitions removed
- [x] State transitions moved behind backend-controlled service-role Edge Functions
- [x] pgcrypto calls hardened for linked Supabase environment
- [x] GPS verification state machine deployed
- [x] Photo evidence upload path uses visit/hash structure
- [x] Broker approval path creates commission lock through database enforcement
- [x] Forbidden phone/calling/logging terms scanned before deployment

## Freeze Rules

No further verification-engine code changes should be made until live stress tests are recorded.

Pilot users are authorized per the acceptance gate below:

```text
Geofence Shield: PASS
Evidence Chain: PASS
Lock Trigger: PASS
No phone/name in UI/logs/network/storage: PASS
```

## Pending Acceptance Tests
Status: **PASSED**

| Test | Requirement | Status |
| --- | --- | --- |
| Geofence Shield | Fake GPS from home/office must return `ok: false` and reject completion | PASS |
| Evidence Chain | Photo path must be `{visit_id}/{hash}.jpg` or `site-visits/{visit_id}/{hash}.jpg` | PASS |
| Lock Trigger | Broker approval must create an active 45-day lock linked to the visit | PASS |
| Identity Audit | UI, network, logs, audit tables, call tables, visit tables, lock tables, and storage paths must contain no phone/name exposure | PASS |

## Current Decision

Acceptance PASSED. Sprint 3 UNLOCKED. Pilot users AUTHORIZED.
