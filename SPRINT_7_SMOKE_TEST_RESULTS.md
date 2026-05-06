# Sprint 7 Smoke Test Results

Status: PENDING
Version: `v0.7.0-enterprise-onboarding`

Do not mark Sprint 7 accepted until these tests pass against the deployed environment.

```text
Organization Onboarding Without SQL: PENDING
Broker Invite And Activation: PENDING
Caller Invite With No Contact Visibility: PENDING
Sourcing Manager Assignment: PENDING
Developer/Admin Separation: PENDING
Disabled User Blocked: PENDING
Paused Organization Blocked: PENDING
Permission Matrix Enforced: PENDING
Onboarding Audit Safe: PENDING
Direct DB Mutation Blocked: PENDING
No customer identity in UI/logs/network/onboarding tables: PENDING
Security Scan: PENDING
Sprint 7 Static Check: PENDING
```

## Required Checks

1. Create organization through Edge Function only.
2. Confirm organization starts paused.
3. Resume organization only after approval checks pass.
4. Invite broker user and confirm invite reference is hashed in storage.
5. Accept invite and confirm user remains disabled.
6. Assign role and permission template.
7. Activate user and confirm activation checks are recorded.
8. Confirm non-admin cannot manage users.
9. Confirm caller cannot view sensitive customer contact data.
10. Confirm paused organization blocks protected workflows.
11. Confirm suspended user is blocked everywhere.
12. Confirm onboarding audit timeline contains no customer identity or raw invite reference.
13. Run `npm run security`.
14. Run `npm run sprint7:check`.
