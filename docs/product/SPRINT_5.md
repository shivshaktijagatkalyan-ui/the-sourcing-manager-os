# Sprint 5: Scalable Enforcement & Automated Routing

Status: **ACCEPTED / FROZEN**
Version: `v0.5.0-scale`

## Objective

Transition from manual pilot oversight to an automated, performance-driven enforcement engine. Leverage trust scores to drive lead allocation and automate the commission lifecycle.

## Core Modules

### 1. Automated Payout Ledger

- **Table**: `payout_ledger`
- **Logic**: Automatic transition from `broker_lock` -> `payable` after 45-day verification period + positive trust check.
- **Audit**: Immutable record of every rupee earned/paid.

### 2. Performance Visibility

- **Logic**: View brokers by verified conversion rate and trust score.
- **Privacy**: Anonymized public view; full detail for Org Admins.

### 3. Trust-Gated Lead Routing

- **Engine**: Match leads to brokers based on trust tiers.
- **SLA Enforcement**: Auto-revoke data loans if no activity (call/visit) occurs within 4 hours.

### 4. Bulk Operations (Manager Suite)

- **Features**: CSV Import for Leads, Bulk Assignment, Bulk Payout Export.
- **Safety**: Multi-factor confirmation for any operation > 100 records.

## Governance Rules

- No payout without a verified `site_visit_id`.
- Lead routing must prioritize high-trust brokers (Fail-Closed to quality).
- All rankings must be explainable (linked to `trust_scores`).
