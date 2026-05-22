# Release Notes - v1.0.0-stable

We are proud to announce the stable release of **The Sourcing Manager OS**, the world's first trust-gated, PII-sovereign sourcing enforcement platform for the real estate industry.

## Key Features

### 1. Dataless Privacy (Constitution v1)

- **Masked Sourcing**: Brokers source leads without revealing phone numbers or customer names.
- **Secure PSTN Calling**: Integrated bridge connecting callers and clients without data exposure.

### 2. Site Visit Verification (The Truth Layer)

- **GPS Enforcement**: Verification within 50m of site coordinates.
- **Live Evidence**: Forced photo evidence prevents fraudulent commission claims.
- **45-Day Lock**: Automatic commission protection for verified visits.

### 3. Enterprise Operations

- **RBAC Matrix**: 10 distinct roles (Admin, Manager, Broker Owner, Caller, etc.).
- **Payout Ledger**: Automated commission eligibility and statement generation.
- **Compliance Audit**: Trai DND check, DPDP consent ledger, and GST/RERA reporting.

### 4. Reliability & Health

- **Control Plane**: Real-time health monitoring and provider failure tracking.
- **Rate Limiting**: Anti-abuse protection on all critical functions.
- **Fail-Closed Security**: Access is automatically revoked if compliance or trust score falls below threshold.

## Breaking Changes from Pilot

- All raw phone number access in legacy views has been removed.
- Data Loans are now mandatory for call initiation.
- Site Visit verification now requires live camera feed (no gallery uploads).

## Deployment Tag

`v1.0.0-stable`
