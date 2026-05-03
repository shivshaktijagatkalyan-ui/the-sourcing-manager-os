# The Sourcing Manager OS

Open-source trustless real estate operating system for India.

## Mission
Build a data-enforcement layer for Indian real estate where brokers own lead data, callers generate activity, sourcing managers execute verified site visits, and developers track ROI without exposing sensitive customer data.

## License
AGPLv3 - See [AGPL_COMPLIANCE.md](./AGPL_COMPLIANCE.md)

## Tech Stack
- **Frontend**: Flutter Web / PWA
- **Backend**: Supabase (PostgreSQL, Edge Functions)
- **Database**: PostgreSQL with pgcrypto and RLS
- **Calling**: Exotel India PSTN Bridge

## Security Constitution
1. **Zero Visibility**: Phone numbers are NEVER visible in UI, API, logs, or memory.
2. **Encrypted at Rest**: Sensitive data is stored as ciphertext using AES-256 (via pgcrypto).
3. **Just-in-Time Decryption**: Decryption occurs only in memory within Supabase Edge Functions.
4. **PSTN Bridging**: All calls are routed through a bridge. No direct browser calling.
5. **Data Separation**: Public metadata is separated from sensitive encrypted data.
6. **Strict RLS**: Default deny policies on all tables.
7. **Audit-Only**: All sensitive actions are logged in append-only audit tables.

## Getting Started
(Detailed setup instructions in SPRINT_1.md)
