# Sprint 6: Compliance, Reporting & Enterprise Governance

Status: **UNLOCKED / ACTIVE**
Version: `v0.6.0-compliance`

## Objective

Convert verified sourcing activity into compliance-grade, enterprise-ready records. Hardening the system for DPDP, TRAI, and RERA compliance while maintaining the core "No PII" enforcement.

## Core Modules

### 1. DPDP & TRAI Compliance

- **Consent Ledger**: Track and version customer consent for calls/visits.
- **DND Reporting**: Automated trail of DND checks performed before every call.
- **Data Minimization Audit**: Verification that no PII is stored beyond the encrypted foundation.

### 2. RERA & Developer ROI

- **Project Registry Hardening**: Immutable link between `site_visits` and RERA project IDs.
- **Developer ROI Dashboard**: Aggregate verified activity stats (visits/locks) per project.

### 3. Financial Compliance (GST-Ready)

- **Commission Reports**: Generate PDF/CSV reports for payouts with tax-ready fields.
- **Broker Payout Statements**: Self-service portal for brokers to download verified earning statements.

### 4. Enterprise Operations

- **Safe Audit Exports**: Export audit logs with PII-free actor/lead identifiers.
- **Incident Response**: Logic for bulk-revoking loans or pausing organizations during a breach.
- **AGPL Compliance**: Public "Compliance Page" detailing the deployment of the OS.

## Governance Rules

- No PII in any exported report.
- Every payout statement must link back to a `verified_site_visit_id`.
- Consent must be granular (Call vs. Visit).
