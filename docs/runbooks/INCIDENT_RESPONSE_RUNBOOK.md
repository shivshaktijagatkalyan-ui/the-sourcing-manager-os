# Incident Response Runbook (v1.0.0)

## 1. Severity Levels

- **Critical (P0)**: Calling or Verification system-wide failure. Data leakage suspected.
- **High (P1)**: Single Organization blocked. Edge Function error spike.
- **Medium (P2)**: UI bug affecting one role. Reporting delay.

## 2. Response Procedures

### Scenario: Suspected Data Leak

1. Immediate Pause: Call `incident-response(action='pause_all')`.
2. Investigation: Audit `edge_function_failures` and `provider_failures`.
3. Recovery: Revert to previous Edge Function version.
4. Notification: Notify Orgs via `create-risk-notification`.

### Scenario: Provider Outage (Exotel)

1. Degrade System: Mark system status as `degraded`.
2. User Guidance: Update UI toast to "Calling service temporarily down".
3. Retry Logic: Enable automatic retry for queued call attempts.

## 3. Communication Channels

- **Internal**: Pilot Admin Dashboard -> Risk Notifications.
- **External**: Support Playbook email/phone.
