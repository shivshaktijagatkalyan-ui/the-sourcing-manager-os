# Research: Salesforce CRM Synchronization Adapter

## Summary

This document presents technical research, best practices, and integration patterns for building the Salesforce CRM Synchronization Adapter in a secure, PII-safe, and fail-closed manner.

---

## 1. Salesforce API Authentication

### OAuth 2.0 JWT Bearer Flow

To execute background server-to-server operations without interactive login, the adapter uses the standard **Salesforce OAuth 2.0 JWT Bearer Flow** (RFC 7523).

#### Mechanics
1. **Digital Certificate**: Generate an X.509 certificate and private key. Upload the certificate to the Salesforce Connected App configuration.
2. **Secret Storage**: Store the private key and Connected App Client ID (`salesforce_client_id` and `salesforce_private_key`) securely as secrets inside the Supabase Vault.
3. **JWT Generation**: The outbound Edge Function constructs a JWT assertion:
   - **Header**: `{ "alg": "RS256", "typ": "JWT" }`
   - **Payload**:
     - `iss`: Salesforce Connected App Client ID.
     - `sub`: Salesforce integration user username.
     - `aud`: Salesforce login environment URL (`https://login.salesforce.com` or `https://test.salesforce.com`).
     - `exp`: Expiration time (current epoch + 300 seconds).
4. **Token Request**: Make an HTTP POST request to `/services/oauth2/token` passing `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer` and the signed assertion JWT.
5. **REST Client**: Salesforce returns an `access_token` and `instance_url` to sign REST API requests via `Authorization: Bearer <access_token>`.

#### Token Caching Strategy
To avoid hitting Salesforce authentication rate limits (standard limit is 5 token requests per minute per Connected App), the adapter implements an in-memory or transient cache:
- Cache the `access_token` and its expiration timestamp.
- Re-use the cached token for subsequent REST requests.
- Retrieve a new token only when the cached token is within 60 seconds of expiration or if a REST request returns a `401 Unauthorized` response.

---

## 2. Inbound Webhook Ingestion Security

Salesforce can trigger webhooks on SObject creation or modification. The webhook handler must guard against unauthorized payload submissions and replay attacks.

### Signature Validation
1. **Shared Webhook Secret**: Store a shared secret token `salesforce_webhook_secret` in Supabase Vault.
2. **Signature Header**: Salesforce outbound webhook requests include a signature header, e.g., `X-Salesforce-Signature` containing the signature.
3. **Validation Algorithm**:
   - Compute the HMAC SHA256 hex digest of the raw request payload using the shared secret.
   - Compare the computed digest with the signature header value using a time-constant/safe comparison routine to prevent timing attacks.
   - **Fail Closed**: If the signature does not match, return `401 Unauthorized` immediately and record an abuse warning in `audit_events`.

### Webhook Replay Protection
To enforce idempotency and block replay attacks:
- Webhook payloads include a unique event identifier (`event_id` or message UUID).
- Create a lookup table `public.salesforce_webhook_idempotency` with a unique constraint on `event_hash` or `event_id`.
- The webhook endpoint performs an insert into this table before processing. If a duplicate key violation occurs, the endpoint acknowledges the event with `200 OK` (to prevent Salesforce from retrying) but skips processing or enqueuing a duplicate task.

---

## 3. Asynchronous Execution and Retries

Core business transactions must not be blocked by external Salesforce network roundtrips.

### Asynchronous Outbound Architecture
1. **State Machine Trigger**: In the database, when a lead state is updated to `visit_verified` and brokerage status is `locked`, a trigger or internal procedure enqueues a sync task into `public.enterprise_task_queue` with `task_type = 'salesforce_outbound_sync'`.
2. **Asynchronous Processing**: An Edge Function or background worker picks up the task from the queue.
3. **Transaction Logging**: Results of the synchronization task are stored in `public.enterprise_task_history` and logged to `public.audit_events`.

### Retry and Backoff Policy
External REST API requests can fail due to network hiccups, transient timeouts, or Salesforce rate limits.
- **Failures**: If a REST request fails, update the queue task status to `retry`.
- **Exponential Backoff**: Set `available_at` in `enterprise_task_queue` to:
  $$\text{available\_at} = \text{now()} + (2^{\text{retry\_count}} \times 30\text{ seconds})$$
- **Max Retries**: Limit retries to 5 times.
- **Escalation**: If a task fails 5 times, mark its status as `failed`, transition the `enterprise_task_workflow` to `failed_review`, and write an entry to `public.enterprise_human_review_queue` for manual administrator intervention.

---

## 4. Dataless Compliance and PII Exclusions

To remain completely compliant with the **Sourcing Manager OS Dataless Constitution**:
- **Zero PII Outbound**: Outbound REST payloads sent to Salesforce MUST NOT contain `contact_number`, `whatsapp_link`, `caller_id`, or `broker_secret`.
- **Metadata Mappings Only**: Payloads contain UUIDs, alias names, assigned project labels, verified site visit verification tags, and lock status indicators.
- **Inbound Ingestion Security**: Incoming leads via Salesforce webhooks containing raw contact numbers must be immediately processed through the secure Postgres RPC `ingest_lead_contact_secure(p_contact, p_enc_key, p_hash_salt)` to generate AES256 ciphertexts and salted hashes. Raw phone numbers must never be committed to public database tables or unencrypted server logs.

---

## 5. Alternatives Considered

### 1. Direct Synchronous HTTP Calls from Triggers
- *Rejected*: Triggers making external HTTP calls block database connections, reduce throughput, and fail if the external service is slow or down.
- *Chosen Alternative*: Asynchronous transactional queueing via `enterprise_task_queue`.

### 2. Basic Username/Password Authentication (Salesforce Soap login)
- *Rejected*: Username/password flows are deprecated by Salesforce, violate multi-factor authentication policies, and require managing sensitive passwords.
- *Chosen Alternative*: Secure OAuth 2.0 JWT Bearer flow with public/private keys.
