# Launch Runbook (Sprint 10)

## 1. Environment Preparation

- [ ] Create production Supabase project.
- [ ] Link Exotel production SID/API Key.
- [ ] Set up daily backup schedule (Pro Plan).

## 2. Deployment Sequence

1. **Migrations**: Apply all migrations from `20240501...` to `20240511...`.
   - ✅ **DEPLOYED (May 7, 2026 10:41 UTC)**: Migration `20260507000600_site_visit_proposal_confirmation.sql` applied to production.
     - Site Visit Proposals table: ✅ Created
     - Site Visit Confirmations table: ✅ Created
     - RLS Policies: ✅ Applied
     - Database Indexes: ✅ Created
2. **Edge Functions**: Deploy the full list of 30+ functions.
3. **Flutter**: Build and deploy Flutter Web/PWA to production hosting.
4. **Secrets**: Initialize all env secrets (Exotel, JWT, etc.).

## 3. Data Sanitization

- [ ] Run `DATA_CLEANUP_PLAN.md` to remove pilot test records.
- [ ] Seed base `role_definitions` and `permission_templates`.

## 4. Final Smoke Test

- [ ] Run `scripts/security-check.py`.
- [ ] Verify `system-health-check` returns `healthy`.
- [ ] Create one "System Admin" user manually via SQL to trigger the first onboarding flow.

## 5. Official Release

- [ ] Tag the repository: `v1.0.0-stable`.
- [ ] Issue release notes.
