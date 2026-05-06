# UAT Test Plan (v1.0.0-stable)

## 1. Scope

End-to-end verification of the Sourcing Manager OS across all 10 roles.

## 2. Critical Test Scenarios

### T1: Org Onboarding & Member Activation

- [ ] Admin creates new Organization.
- [ ] Manager invites a Broker Agent.
- [ ] Broker Agent accepts invite and completes profile.
- [ ] Result: `pilot_users` correctly populated with RBAC permissions.

### T2: Lead Sourcing to Lock

- [ ] Broker uploads new Lead Metadata.
- [ ] Sourcing Manager grants Data Loan.
- [ ] Caller initiates Secure Call (Verify no number exposure).
- [ ] Broker schedules Site Visit.
- [ ] Field Agent verifies GPS at site.
- [ ] Manager approves Visit.
- [ ] Result: `payout_ledger` entry created with 45-day lock.

### T3: Dispute & Abuse Enforcement

- [ ] Manager opens Dispute on a lead.
- [ ] Broker attempts visit while dispute is active (Expected: BLOCKED).
- [ ] System detects "Multiple failed GPS attempts" (Expected: Abuse Event generated).
- [ ] Admin pauses Organization (Expected: All user sessions blocked).

### T4: Financial Accuracy

- [ ] Run Payout Eligibility Job.
- [ ] Generate Payout Statement for an Org.
- [ ] Result: Correct totals excluding non-matured locks.
