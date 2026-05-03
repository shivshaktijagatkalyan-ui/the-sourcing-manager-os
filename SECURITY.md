# Security Constitution

The Sourcing Manager OS is built on a "Trustless" model. The system enforces data privacy through architectural constraints, not user policy.

## Non-Negotiable Rules

1. **Phone Visibility**: No phone numbers (full or masked) shall ever be visible to any user or returned in any frontend API response.
2. **Encryption**: All PII (Personally Identifiable Information) must be encrypted using `pgcrypto` AES-256 before storage.
3. **Edge Isolation**: Decryption is permitted ONLY within Supabase Edge Functions. The database itself never returns plaintext phone numbers to the client.
4. **Bridge Calling**: All communication happens via PSTN bridges (Exotel). The caller and receiver are connected by the server; neither sees the other's real number.
5. **Data Loan Model**: Access to interact with a lead is a temporary "loan". Once expired or revoked, the system blocks all interaction attempts at the API level.

## Threat Model & Mitigation

| Threat | Mitigation |
| --- | --- |
| Database Leak | Data is encrypted at rest; keys are stored in Supabase Vault/Env. |
| Malicious Caller | Caller never sees the number; PSTN bridge masks identity. |
| Scraping | Lead metadata is public-ish but useless without the encrypted bridge. |
| Frontend DevTools | API responses contain UUIDs, never phone numbers. |
