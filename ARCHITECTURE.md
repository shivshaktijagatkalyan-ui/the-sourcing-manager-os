# Architecture

## Positioning

The Sourcing Manager OS is a data enforcement layer for Indian real estate. It can sit beside a CRM, but it does not behave like a contact database.

## Data Layers

### Public Layer

`leads_public` contains:

- lead id
- broker id
- assigned manager/caller ids
- alias
- area and city
- property metadata
- budget range
- status
- consent, DND, RERA, and GST metadata

### Sensitive Layer

`leads_sensitive` contains only:

- lead id
- encrypted contact ciphertext as `TEXT`
- encryption version
- timestamps

No frontend policy can read this table.

## Upload Flow

1. Broker enters lead metadata and a one-time sensitive contact value.
2. Flutter calls `broker-upload-lead`.
3. The Edge Function authenticates the broker.
4. PostgreSQL `pgcrypto` encrypts through the service-role-only RPC.
5. Metadata is stored in `leads_public`.
6. Ciphertext is stored in `leads_sensitive`.
7. The response returns only `lead_id` and `alias`.

## Call Flow

1. Caller presses Secure PSTN Call.
2. Flutter sends only `lead_id`.
3. `initiate-call` authenticates the caller.
4. The function validates active `data_loans` purpose `call`.
5. The function validates consent and TRAI DND status.
6. The function decrypts only in memory.
7. Exotel receives the server-to-server PSTN request.
8. Local references are cleared.
9. `call_attempts` and `audit_events` store sanitized metadata only.

## Callback Flow

`exotel-callback` accepts only status, duration, and provider call id. It never stores raw callback payloads.

## Site Visit And Lock Skeleton

When a `site_visits` row becomes `verified`, the trigger creates a 45-day `broker_locks` row and writes a safe audit event.
