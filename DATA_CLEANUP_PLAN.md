# Data Cleanup Plan (Post-Pilot / Pre-Launch)

## 1. Goal

Purge all non-essential test data while preserving role definitions and administrative structure.

## 2. Cleanup Targets

### A. Sandbox Leads

- [ ] Delete all leads where `alias` starts with `Test-` or `Demo-`.
- [ ] Clean `leads_public` and `leads_private` matching test UUIDs.

### B. Test Pilot Users

- [ ] Deactivate all users in `pilot_users` who are not part of the final launch team.
- [ ] Delete `audit_events` older than 30 days (pre-production history).

### C. Fake Commissions

- [ ] Clear `payout_ledger` entries created during Sprint 5-8 testing.
- [ ] Reset `broker_performance_stats`.

### D. Evidence Storage

- [ ] Purge `site_visit_photos` bucket.
- [ ] Clear `statement_reports` bucket.

## 3. Preservation List

- **DO NOT DELETE**: `role_definitions`.
- **DO NOT DELETE**: `permission_templates`.
- **DO NOT DELETE**: `organizations` marked as `Launch Partner`.
