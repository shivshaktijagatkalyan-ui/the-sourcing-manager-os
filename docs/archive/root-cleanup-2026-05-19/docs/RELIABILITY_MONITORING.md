# Reliability & Monitoring Guide (Sprint 9)

This document outlines the production control plane for the Sourcing Manager OS.

## 1. System Health Status

| Status | Meaning | Action Required |
| :--- | :--- | :--- |
| **Healthy** | All systems operational. | None. |
| **Degraded** | Minor failures in Edge Functions or non-critical providers. | Check `edge_function_failures`. |
| **Incident** | Critical flow blocked (e.g., Calling or Verification). | Immediate investigation; possible incident-response. |
| **Maintenance** | Scheduled system updates or migration window. | Notify organizations via admin panel. |

## 2. Failure Tracking

Every critical Edge Function now uses the `log_edge_failure` helper.

- **Sanitization**: Raw request bodies and PII (phone numbers) are NEVER logged.
- **Traceability**: Failures are linked to `actor_id` and `organization_id` for quick isolation of "noisy" users or orgs.

## 3. Provider Monitoring

- **Exotel**: Tracked via `exotel-callback`. Failures in bridge logic trigger high-severity health events.
- **Storage**: Upload failures are recorded to detect "corrupt evidence" patterns.

## 4. Rate Limiting Policy

- **Threshold**: 5 calls per minute per user.
- **Enforcement**: Fail-closed. If the rate limit check fails, the primary action is blocked.
- **Audit**: Every blocked attempt is logged as a `rate_limit_blocked` event.

## 5. Diagnostics

Administrators can run `generate-diagnostics` to get an aggregated snapshot of:

- Total active loans vs. used loans.
- Verification success/failure ratios.
- Payout ledger velocity.
- Active incident count.
