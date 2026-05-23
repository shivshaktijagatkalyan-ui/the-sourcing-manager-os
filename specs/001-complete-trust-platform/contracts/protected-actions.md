# Contract: Protected Edge Actions

All protected actions are Supabase Edge Functions. They require an authenticated
JWT unless explicitly documented as provider callback endpoints. Responses must
use stable public reason codes and must not return restricted contact data.

## complete-onboarding

- **Actor**: authenticated user.
- **Input**: selected role and safe profile metadata.
- **Persists**: role assignment, pilot user, role-specific public profile,
  onboarding audit event.
- **Failure**: invalid role, missing invite, unavailable organization,
  permission template failure.
- **Privacy**: no sensitive contact fields.

## broker-upload-lead

- **Actor**: active broker with upload permission.
- **Input**: lead metadata plus restricted contact input.
- **Persists**: `leads_public`, `leads_sensitive`, audit event.
- **Rules**: `broker_id` is auth user id; `source_broker_id` is broker profile
  id; duplicate contact hash returns conflict.
- **Privacy**: response returns lead id/alias/status only.

## lead-from-broker

- **Actor**: sourcing manager or governed broker flow.
- **Input**: broker id, project/area/budget metadata, restricted contact input.
- **Persists**: safe lead metadata, sensitive storage, broker attribution.
- **Privacy**: no contact fields in response.

## manage-caller-workflow

- **Actor**: sourcing manager or caller depending on action.
- **Input**: action, lead id, caller id, outcome/follow-up metadata.
- **Persists**: data loan, call workflow state, follow-up, audit event.
- **Failure**: inactive actor, inactive organization, invalid role, missing
  lead, expired loan.

## initiate-call

- **Actor**: caller or permitted workflow actor with active data loan.
- **Input**: lead id and optional data loan id.
- **Persists**: call attempt queued through provider integration.
- **Failure**: missing active loan, provider credential failure, inactive actor.
- **Privacy**: no restricted contact data in response.

## exotel-callback

- **Actor**: provider callback.
- **Input**: provider event payload and callback signature/secret.
- **Persists**: call attempt status and provider callback metadata.
- **Failure**: forged callback, replay, unknown call reference.
- **Privacy**: raw provider payload must not be logged or exposed.

## propose-site-visit

- **Actor**: broker or sourcing manager through governed workflow.
- **Input**: lead id, broker id, project id, proposed time, safe notes.
- **Persists**: site visit proposal and audit event.
- **Failure**: invalid broker attribution, unavailable project, inactive actor.

## verify-site-gps

- **Actor**: assigned sourcing manager or actor with verify permission.
- **Input**: site visit id, latitude, longitude, accuracy.
- **Persists**: GPS proof metrics and partial proof state.
- **Failure**: out-of-geofence, poor accuracy, invalid visit state.

## verify-site-visit-proof

- **Actor**: assigned sourcing manager or actor with verify permission.
- **Input**: proof type and proof metadata.
- **Persists**: proof confirmation, site visit proof mirror, visit state, audit
  event, broker lock on visit completion.
- **Failure**: invalid state, restricted token in proof path, active lock
  conflict.

## super-admin-dashboard

- **Actor**: platform admin or permitted admin role.
- **Input**: dashboard request.
- **Returns**: safe summaries for organizations, workforce, risk, proofs,
  bottlenecks, and health.
- **Privacy**: metadata only.

## trust-* AI-safe tools

- **Actor**: authenticated permitted user.
- **Returns**: only approved metadata tokens.
- **Forbidden**: sensitive table reads, decrypt operations, contact wording,
  direct outreach links, raw internal errors.
