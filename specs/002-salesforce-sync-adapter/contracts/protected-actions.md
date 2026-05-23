# Interface Contracts: Protected Sync Actions

## Summary

This document specifies the exact JSON payload, HTTP header, and response schemas for both the **Inbound Webhook** endpoint and the **Outbound REST API** integration.

---

## 1. Inbound Webhook: `salesforce-webhook`

This serverless Edge Function endpoint receives HTTP POST notifications from Salesforce.

- **HTTP Method**: `POST`
- **Path**: `/functions/v1/salesforce-webhook`
- **Headers**:
  - `Content-Type`: `application/json`
  - `X-Salesforce-Signature`: `sha256=<hmac-hex-signature>` (HMAC SHA256 signature generated using the shared webhook secret)
  - `X-Api-Version`: `1`

### 1.1 Inbound JSON Payload

```json
{
  "event_id": "evt_sf_8891029381",
  "event_type": "Lead_Captured",
  "organization_id": "40d1a14e-4cfb-4917-ba3c-f14b13c8835b",
  "timestamp": "2026-05-23T12:00:00Z",
  "data": {
    "salesforce_lead_id": "00Q8c00001yZabc",
    "organization_id": "40d1a14e-4cfb-4917-ba3c-f14b13c8835b",
    "alias": "Lead-Alpha",
    "area": "Whitefield",
    "city": "Bengaluru",
    "budget": 8500000,
    "contact_phone": "+919876543210"
  }
}
```

### 1.2 Webhook Processing Logic

1. **Verify Signature**: Calculate the HMAC SHA256 of the raw body. If it does not match `X-Salesforce-Signature`, return `401 Unauthorized`.
2. **Verify Idempotency**: Query `public.salesforce_webhook_idempotency` for `event_id`. If it already exists, return `200 OK` (with body `{ "ok": true, "reason": "duplicate_skipped" }`) to acknowledge but skip processing.
3. **PII Safe Ingestion**: Call `public.ingest_lead_contact_secure(p_contact, p_enc_key, p_hash_salt)` using the raw `contact_phone` to generate the encrypted ciphertext and hash. Insert lead into `public.leads_public`.
4. **Queue Task**: Insert a sync mapping task into `public.enterprise_task_queue` under type `'salesforce_inbound_ingest'`.

### 1.3 Response Contracts

#### Successful Ingestion (`201 Created`)
```json
{
  "ok": true,
  "event_id": "evt_sf_8891029381",
  "lead_id": "3c5fa4a6-7104-4b5c-a5b6-c5c58a5c31ff",
  "status": "enqueued"
}
```

#### Verification Failure (`401 Unauthorized`)
```json
{
  "ok": false,
  "reason": "invalid_signature"
}
```

#### Malformed Input (`400 Bad Request`)
```json
{
  "ok": false,
  "reason": "missing_required_fields",
  "fields": ["event_id", "data.salesforce_lead_id"]
}
```

---

## 2. Outbound REST Integration: `salesforce-sync-processor`

This background serverless processor executes queued outbound sync tasks. It connects directly to the Salesforce REST API.

- **HTTP Method**: `POST` (SObject creation) or `PATCH` (SObject updates)
- **URL Path**:
  - Create: `/services/data/v60.0/sobjects/Lead`
  - Update: `/services/data/v60.0/sobjects/Lead/Sourcing_Manager_OS_ID__c/<local_lead_uuid>`
- **Headers**:
  - `Content-Type`: `application/json`
  - `Authorization`: `Bearer <cached_access_token>`

### 2.1 Outbound Lead/Opportunity Sync Payload

```json
{
  "Sourcing_Manager_OS_ID__c": "3c5fa4a6-7104-4b5c-a5b6-c5c58a5c31ff",
  "LastName": "Lead-Alpha",
  "Address_Area__c": "Whitefield",
  "Address_City__c": "Bengaluru",
  "Budget__c": 8500000,
  "Status": "visit_verified",
  "Brokerage_Locked__c": true,
  "Assigned_Sourcing_Manager__c": "123e4567-e89b-12d3-a456-426614174000"
}
```

> [!IMPORTANT]
> Payload contains **zero** raw contact numbers, masked digits, caller names, or whatsapp links, completely matching the **Dataless Constitution** limits.

### 2.2 Outbound Activity Task Sync Payload

Logged calls or follow-ups are pushed as Task SObjects linked to the lead.

- **URL Path**: `/services/data/v60.0/sobjects/Task`

```json
{
  "Sourcing_Manager_OS_Interaction_ID__c": "5f3a9e1a-c21b-4d5e-a61f-d72e9a5c43d2",
  "WhoId": "00Q8c00001yZabc",
  "Subject": "Secure Call Attempt - Sourcing Manager OS",
  "Status": "Completed",
  "CallDurationInSeconds": 87,
  "Description": "Secure outbound call completed. Outcome: Client interested. Site visit proposed. (PII-Scrubbed)"
}
```
