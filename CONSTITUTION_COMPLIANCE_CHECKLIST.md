# Constitution Compliance Checklist (v1.0.0)

This checklist ensures that the "Masked Dataless" constitution remains unbroken at launch.

## 1. Zero-Exposure Policy

- [x] **No Phone Storage**: Client phone numbers are never stored in `leads_public` or `leads_private`.
- [x] **No Name Leakage**: Lead identities are always represented by their `Alias`.
- [x] **No Masked Hints**: No partial phone numbers (e.g., 98xxxx1234) exist in the database or logs.

## 2. Fail-Closed Policy

- [x] **No Consent = No Call**: Call bridge fails if `consent_ledger` has no active record.
- [x] **No GPS = No Lock**: Commission lock cannot be created without a verified `site_visit_gps` record.
- [x] **No Loan = No Dial**: PSTN bridge rejects call if `data_loan` is expired or missing.

## 3. Sovereign Enforcement

- [x] **No Override**: Even Admins cannot manually override a failed GPS verification.
- [x] **Immutable Audit**: `audit_events` is append-only and cannot be edited.
- [x] **Trust Gating**: Routing automatically pauses for brokers with a trust score below 40.

## 4. Verification

- [x] Run `grep -r "phone" .` (Verify no leakage in client-side models).
- [x] Run `grep -r "customer_name" .` (Verify no leakage).
- [x] Check `exotel-callback` logs for PII.
