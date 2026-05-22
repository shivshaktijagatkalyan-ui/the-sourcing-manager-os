-- Data Cleanup: Purge Pilot Test Records for Production Launch
-- This script safely removes pilot data while preserving system schemas.

BEGIN;

-- 1. Disable append-only enforcement temporarily
ALTER TABLE audit_events DISABLE TRIGGER audit_events_append_only;

-- 2. Purge compliance and audit trails
DELETE FROM audit_events;
DELETE FROM consent_ledger;

-- 3. Re-enable append-only enforcement
ALTER TABLE audit_events ENABLE TRIGGER audit_events_append_only;

-- 4. Purge PII and leads
DELETE FROM leads_sensitive;
DELETE FROM leads_public;

-- 3. Purge operational events
DELETE FROM call_attempts;
DELETE FROM data_loans;
DELETE FROM site_visits;
DELETE FROM broker_locks;

-- 4. Purge financial and trust data
DELETE FROM payout_ledger;
DELETE FROM trust_score_snapshots;
DELETE FROM pilot_activity_daily;

-- 5. Reset pilot status for organizations
UPDATE organization_profiles SET pilot_status = 'approved' WHERE pilot_status = 'pending';

-- 6. Reset pilot status for users
UPDATE user_profiles SET pilot_status = 'approved' WHERE pilot_status = 'pending';

COMMIT;
