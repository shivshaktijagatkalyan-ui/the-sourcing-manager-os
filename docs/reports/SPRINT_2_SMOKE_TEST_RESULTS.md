# Sprint 2 Smoke Test Results (Site Visit Verification)

Status: **PASSED**

Version: `v0.2.0-stable`  
Deployment log timestamp reported: `2026-05-03 21:31:34Z`  
Supabase project ref reported: `gblvnjilpcxhygvzikwe`

## 1. Deployment Gate Checks

- [x] Security Scan (v0.2.0) Passed
- [x] Sprint 2 Migration Applied (`20240504000100_sprint2_verification.sql`)
- [x] Private Storage Bucket Created (`site-visit-evidence`)
- [x] Edge Function: `create-site-visit` Deployed
- [x] Edge Function: `start-site-visit` Deployed
- [x] Edge Function: `verify-site-gps` Deployed
- [x] Edge Function: `upload-site-photo` Deployed
- [x] Edge Function: `broker-review-site-visit` Deployed
- [x] Flutter Analysis Passed
- [x] Flutter Web Release Built

## 2. Live Acceptance Tests

- [x] **Geofence Shield**: Remote check-in from London rejected for Bangalore project. Expected: fake GPS rejected.
- [x] **Evidence Chain**: SHA-256 photo evidence generated and stored in private bucket as `{visit_id}/{hash}.jpg`.
- [x] **Lock Trigger**: Broker approval created active 45-day commission lock in `broker_locks`.
- [x] **Identity Audit**: UI, network, logs, audit events, visit records, lock records, and storage metadata reported clean of phone/name exposure.

## 3. Expanded Smoke Checklist

- [x] **Geofence Registry**: Project created with GPS/radius.
- [x] **Scheduling**: Site visit created for valid loan.
- [x] **Authorization**: Unassigned user blocked from starting visit.
- [x] **Geofence Enforcement (Outside)**: GPS outside radius rejected.
- [x] **Accuracy Enforcement**: Low-accuracy GPS rejected or prevented by hardened verification rules.
- [x] **Geofence Enforcement (Inside)**: GPS inside radius verified.
- [x] **Evidence Capture**: Photo uploaded to private bucket with hash stored.
- [x] **Privacy Check**: No phone/name exposure in photo storage path or review UI.
- [x] **Broker Rejection**: Visit rejection path does not create lock.
- [x] **Broker Approval**: Verified visit approval creates 45-day lock.
- [x] **Lock Integrity**: Duplicate active lock for same lead blocked or idempotently protected.

## 4. RLS Audit

- [x] `projects` table RLS enabled.
- [x] `site_visits` table RLS enabled.
- [x] `broker_locks` table RLS enabled.
- [x] Verification-owned state changes controlled by backend/service-role functions.

## Final Acceptance Result

```text
Geofence Shield: PASS
Evidence Chain: PASS
Lock Trigger: PASS
No phone/name in UI/logs/network/storage: PASS
```

## Decision

```text
Sprint 2 v0.2.0-stable: ACCEPTED
Pilot users: AUTHORIZED
Sprint 3: UNLOCKED
```
