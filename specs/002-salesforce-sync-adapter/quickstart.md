# Quickstart: Salesforce CRM Synchronization Adapter

## Summary

This quickstart guides developers through local setup, configuration, credential deployment, and verification procedures for the Salesforce CRM Synchronization Adapter.

---

## 1. Local Environment Setup

### Prerequisites
- Supabase CLI installed and logged in.
- Docker running locally (for local Supabase instance emulation).
- OpenSSL or native PowerShell commands to generate test certificates.

---

## 2. Secure Credential Registration

To test JWT Bearer authentication locally or in production, you must register Salesforce API keys and webhook shared secrets into the Supabase Vault.

### Local Simulation
Run the following SQL commands in your local Supabase Studio SQL Editor (or via migration scripts) to register mock variables:

```sql
-- Register mock Salesforce Connected App Client ID
SELECT public.register_production_vault_secret(
  'salesforce_client_id',
  '3MVG99qPHK.18rx791234567890abcdefghijklmnopqrstuvwxyz',
  'Salesforce Connected App OAuth Consumer Client ID'
);

-- Register mock Private Key (RS256 Private Certificate)
SELECT public.register_production_vault_secret(
  'salesforce_private_key',
  '-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC3c5...\n-----END PRIVATE KEY-----',
  'Salesforce Connected App JWT Bearer RSA Private Key'
);

-- Register Webhook Signature Shared Secret
SELECT public.register_production_vault_secret(
  'salesforce_webhook_secret',
  'sf_webhook_secret_hmac_key_2026_prod_v1',
  'HMAC SHA256 Shared Webhook Signature Validation Key'
);
```

---

## 3. Serverless Functions Deployment

### Local Serve
Run the following command from the repository root to start serving the Edge Functions locally:

```bash
supabase functions serve --env-file supabase/.env
```

### Production Deployment
When releasing this feature, deploy the Edge Functions to your active Supabase Cloud instance:

```bash
supabase functions deploy salesforce-webhook
supabase functions deploy salesforce-sync-processor
```

---

## 4. End-to-End Local Verification

We provide a local PowerShell test script to validate features and confirm security gates (forging, replay protection, dataless exports) pass without requiring live Salesforce connectivity.

### Run Verification Script
To test the webhook validation locally, execute:

```powershell
$env:SALESFORCE_WEBHOOK_SECRET="replace-with-local-hmac-secret"
$env:SALESFORCE_TEST_ORG_ID="replace-with-active-organization-uuid"
powershell -ExecutionPolicy Bypass -File scripts/test-salesforce-adapter.ps1
```

This script automatically tests:
1. **Valid Webhook Ingestion**: Sends a signed payload, confirms it successfully inserts a lead, registers a sync mapping, and writes a pending sync task.
2. **Invalid/Forged Signature Rejection**: Sends an incorrect signature, confirming the serverless function rejects the request with a `401 Unauthorized` code.
3. **Idempotency Protection**: Sends the exact same event signature twice, confirming the second execution returns a success code but skips duplicate database writes.
4. **Outbound Compliance Check**: Enqueues and triggers an outbound sync execution, confirming the REST payload excludes phone numbers and contains zero PII.
