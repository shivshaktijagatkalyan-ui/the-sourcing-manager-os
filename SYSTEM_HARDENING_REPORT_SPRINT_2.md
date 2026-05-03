# System Hardening Report: Sprint 2 Verification Engine

Project: The Sourcing Manager OS
Version: `v0.2.0-stable`
License: AGPLv3
Report purpose: Handoff summary for Antigravity and acceptance tracking
Status: **ACCEPTANCE PASSED - AUTHORIZED**

### Acceptance Gate: Live Stress Tests
Status: **PASSED**

| Test | Status | Result |
| :--- | :--- | :--- |
| Geofence Shield | **PASS** | Remote check-in (London) rejected for Bangalore project. |
| Evidence Chain | **PASS** | SHA256 hashing and non-overwrite in private storage verified. |
| Lock Trigger | **PASS** | Automated 45-day broker lock generated on visit completion. |
| Identity Audit | **PASS** | Audit events and logs verified clear of PII (Names/Phones). |

## Executive Summary

Sprint 2 has been moved from a flexible development implementation toward a hardened production state. The reported deployment completed successfully at `2026-05-03 21:31:34Z`.

Live production stress-test results have been reported for all four acceptance gates. The verification engine is accepted for pilot users, and Sprint 3 is unlocked for planning. The Sprint 2 verification engine should remain frozen except for targeted fixes, security patches, or operational defects found during pilot use.

## Reported Hardening Completed

### RLS and State Machine Lockdown

Direct client ownership of verification transitions has been removed from the intended production design. Verification-owned writes must be performed only through backend-controlled Edge Functions using explicit state predicates.

Required invariant:

- frontend can request an action
- backend validates actor, visit, state, loan, and evidence
- database update happens atomically
- frontend cannot directly advance `site_visits.status`

### pgcrypto Resolution Hardening

The encryption/decryption layer was reported hardened by schema-qualifying pgcrypto calls, such as `extensions.pgp_sym_encrypt`, so linked Supabase environments resolve the functions correctly.

Required invariant:

- phone data is stored only as ciphertext
- plaintext is never stored
- decryption happens only in Edge Function memory
- decrypted values are never returned to the browser

### Service Role Mutation Pattern

Sprint 2 Edge Functions were reported updated to follow the Sprint 1 enforcement model:

- authenticate user first
- validate business rules manually
- use service role for privileged state transitions
- return only safe response codes
- never expose sensitive data

### Zero-PII Runtime Integrity

Production functions were reported scrubbed of forbidden logging behavior. The security scanner should remain mandatory before deployment.

Forbidden outputs remain:

- phone numbers
- masked numbers
- customer names in evidence paths
- raw provider payloads
- WhatsApp links
- `tel:` links
- raw sensitive request bodies

## Acceptance Gate

The required acceptance result was reported:

```text
Geofence Shield: PASS
Evidence Chain: PASS
Lock Trigger: PASS
No phone/name in UI/logs/network/storage: PASS
```

## Required Live Tests

### 1. Geofence Shield

Purpose: prove fake site visits are blocked.

Test:

- open the PWA away from the project site
- start a test visit linked to a distant project geofence
- submit GPS

Expected safe result:

- `ok: false`
- reason equivalent to outside geofence
- `gps_status = rejected`
- visit does not complete
- `gps_verified_at` remains null unless the final hardened schema intentionally stores failed-at timestamps separately

### 2. Evidence Chain

Purpose: prove photo evidence is stored safely.

Test:

- perform a valid visit at the project site or with a controlled test geofence
- upload live photo evidence
- inspect private storage bucket path

Expected safe path shape:

```text
{visit_id}/{hash}.jpg
```

Allowed variant:

```text
site-visits/{visit_id}/{hash}.jpg
```

Forbidden path examples:

```text
customer-name/photo.jpg
lead-name/photo.jpg
phone-like-value/photo.jpg
```

### 3. Lock Trigger

Purpose: prove broker commission protection activates.

Test:

- complete GPS verification
- upload photo evidence
- approve as broker
- inspect `broker_locks`

Expected:

- `status = active`
- `source_site_visit_id` linked
- `expires_at` around 45 days after lock creation
- duplicate active locks for the same lead/broker are blocked or safely idempotent

### 4. Identity Audit

Purpose: prove the Security Constitution remains intact after Sprint 2.

Inspect:

- browser UI
- browser Network tab
- Supabase Edge Function logs
- `audit_events`
- `call_attempts`
- `site_visits`
- `broker_locks`
- storage paths

Expected:

- no phone number
- no masked phone number
- no customer name
- no WhatsApp link
- no `tel:` link
- no raw Exotel payload
- no raw sensitive request body

## Current Blockers

No Sprint 2 acceptance blockers remain in this report.

Pilot use is authorized. Sprint 3 is unlocked for planning and scoped implementation.

## Decision Record

```text
Version: v0.2.0-stable
Deployment: SUCCESS
Acceptance: PASSED
Pilot User Authorization: AUTHORIZED
Sprint 3: UNLOCKED
```

No further code changes should be made to the Sprint 2 verification engine unless a targeted fix, security patch, or pilot defect requires it.
