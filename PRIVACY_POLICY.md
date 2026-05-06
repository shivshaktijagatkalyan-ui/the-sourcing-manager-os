# Privacy Policy (Draft - v1.0.0)

> [!IMPORTANT]
> This document is a product draft and does NOT constitute legal advice. It must be reviewed by legal counsel before commercial use.

## 1. Introduction

The Sourcing Manager OS is a trust-gated enforcement platform. Our core design principle is **"Dataless Privacy"**. We minimize the storage of Personally Identifiable Information (PII) by design.

## 2. Data We Do NOT Collect

- **Phone Numbers**: We do not store client phone numbers in our primary database. All calls are routed via a Secure PSTN Bridge.
- **Names**: We use Aliases for client identities.

## 3. Data We Collect

- **Business Identity**: Organization details, GST, and RERA numbers.
- **Activity Data**: Call attempts, site visit durations, and GPS verification metadata.
- **Evidence**: Photos and GPS coordinates required for commission protection.

## 4. DPDP Compliance (Digital Personal Data Protection Act, India)

- **Consent**: User consent is tracked via a versioned `consent_ledger`.
- **Purpose**: Data is collected solely for the purpose of sourcing verification and commission payout integrity.
- **Retention**: Evidence is retained for 45 days (matching the commission lock period) unless a dispute is active.

## 5. Security

All data is stored in encrypted databases (Supabase) with Row Level Security (RLS) enforced for every role.
