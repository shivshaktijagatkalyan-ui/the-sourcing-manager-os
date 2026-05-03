# Security

## System Constitution

Sensitive customer contact data must never be visible in UI, API responses, logs, exports, screenshots, browser memory, or provider callback storage. Partial masks and last digits are also forbidden.

## Enforcement Model

- Public metadata lives in `leads_public`.
- Encrypted ciphertext lives in `leads_sensitive`.
- Authenticated frontend users have no `SELECT` policy on `leads_sensitive`.
- RLS is enabled and forced on every Sprint 1 table.
- Sensitive actions require an active, unexpired, non-revoked `data_loans` row.
- Edge Functions use service role only after authenticating the caller.
- Decryption occurs only in `initiate-call`, only in memory, and is never returned.
- Audit events are append-only and must contain only safe metadata.

## Calling

Calling is server-side PSTN bridging through Exotel. The Flutter app sends only:

```json
{ "lead_id": "uuid" }
```

Frontend direct calling, WhatsApp links, and browser call links are forbidden.

## India Compliance Assumptions

- DPDP: collect minimum data, bind processing to the broker upload and data-loan purpose, and keep sensitive data encrypted.
- TRAI DND: `initiate-call` blocks rows marked `dnd_status = blocked`.
- Consent: `initiate-call` blocks rows unless `consent_status = granted`.
- RERA/GST: metadata columns exist for future verified integrations without merging sensitive data.

## Abuse Cases Covered

- No active loan: Edge Function returns `access_denied`.
- Expired loan: Edge Function returns `loan_expired`.
- Revoked loan: Edge Function returns `revoked`.
- DND blocked: Edge Function returns `dnd_blocked`.
- Consent missing: Edge Function returns `consent_required`.
- Frontend network inspection: call request body contains only `lead_id`.
- Direct sensitive-table read: no authenticated frontend policy exists.
