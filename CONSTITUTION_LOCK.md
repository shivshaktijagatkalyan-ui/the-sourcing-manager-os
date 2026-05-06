# The Sourcing Manager OS: Constitution Lock (v1.0.0)

This document serves as the permanent record of the system's enforcement principles. These rules are locked for the v1.0.0-stable release and cannot be relaxed for operational convenience.

## ⚖️ Immutable Principles

### 1. The Dataless Privacy Rule

- **No Raw PII**: Client phone numbers and customer names are never stored in the database.
- **Masked Identity**: Every lead is a metadata-only record identified by an `Alias`.
- **Zero-Exposure Calling**: Communication is only permitted via the Secure PSTN Bridge. No user, regardless of role or admin status, can reveal a phone number.

### 2. The Evidence-Gated Rule

- **No Proof, No Payout**: Commission eligibility and payout ledger entries require a verified `site_visit_gps` and `live_photo` record.
- **Geofence Enforcement**: Site visits must be verified within the 50m geofence. GPS overrides are hard-blocked by the system logic.

### 3. The Fail-Closed Rule

- **Compliance first**: If an organization is paused, a user is suspended, a trust score is below threshold, or a data-loan is expired, all operational access is revoked at the database level.
- **Safety Over Sales**: The system will always choose to block an action rather than risk a data leak or a fraudulent commission claim.

### 4. The Sovereign Audit Rule

- **Append-Only History**: Every critical action—calls, visits, role changes, and lockdowns—is recorded in the immutable `audit_events` ledger.

## 🛑 Prohibited Features

The following features are constitutionally prohibited:

- Exporting lead lists with contact details.
- Revealing "Last Four Digits" of phone numbers.
- Direct-dial or WhatsApp contact buttons.
- Manual override of GPS/Photo verification.
- Admin-level "God Mode" for PII reveal.

**Signed & Locked.**
**Version: v1.0.0-stable**
**Status: PRODUCTION ACTIVE**
