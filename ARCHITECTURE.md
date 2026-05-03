# System Architecture

## Data Flow (Lead Upload)
1. Broker enters Lead Name + Phone in Flutter PWA.
2. Flutter calls Edge Function `broker-upload-lead`.
3. Edge Function:
   - Encrypts phone using `PHONE_ENCRYPTION_KEY`.
   - Stores metadata in `leads_public`.
   - Stores ciphertext in `leads_sensitive`.
4. Response returns only `lead_id`.

## Data Flow (Calling)
1. Caller clicks "Call" on a lead in PWA.
2. Flutter calls Edge Function `initiate-call` with `lead_id`.
3. Edge Function:
   - Checks for active `data_loan`.
   - Fetches ciphertext from `leads_sensitive`.
   - Decrypts phone in memory.
   - Calls Exotel API to bridge `caller_phone` to `lead_phone`.
   - Wipes memory.
4. Response returns `call_id` status.

## Database Schema Layers
- **Public Layer**: Metadata for discovery and status tracking.
- **Sensitive Layer**: Encrypted PII.
- **Enforcement Layer**: RLS, Loans, and Audit logs.
