# Sprint 7: Enterprise Onboarding & Role Operations

Status: BUILT / DEPLOYMENT PENDING
Version: `v0.7.0-enterprise-onboarding`

## Objective

Sprint 7 replaces manual SQL onboarding with audited Edge Function workflows. The goal is safe enterprise pilot onboarding, not CRM convenience.

No user becomes active until:

- organization is active
- organization pilot status is approved
- organization compliance status is verified
- user role is assigned
- permission template is attached
- user profile is marked complete by an authorized admin
- user pilot status is approved
- user compliance status is verified
- no active suspension exists
- the action has an authenticated audit actor

## Added Modules

- `organization_profiles`
- `role_assignments`
- `permission_templates`
- `permission_template_permissions`
- `onboarding_requests`
- `onboarding_audit_events`
- `user_activation_checks`
- `org_activation_checks`

Existing Sprint 7 draft tables are hardened:

- `user_profiles`
- `organization_invites`
- `user_suspensions`
- role and permission catalogs

## Edge Function Workflows

- `create-organization`
- `invite-user`
- `accept-invite`
- `assign-role`
- `activate-user`
- `deactivate-user`
- `pause-organization`
- `resume-organization`
- `update-permission-template`
- `suspend-user`

All protected writes are service-role Edge Function actions. Flutter does not directly mutate protected onboarding tables.

## Security Notes

- Invite references are hashed before storage.
- Invite acceptance creates a disabled user context, not an active user.
- Activation is separate and check-based.
- Onboarding audit records use IDs, status codes, role IDs, template IDs, and check counts only.
- Paused organizations and suspended users fail closed.
- No phone number, masked number, WhatsApp link, direct call link, raw provider payload, or customer identity belongs in onboarding tables, dashboards, logs, or audit events.

## Acceptance Gate

Sprint 7 is accepted only when `SPRINT_7_SMOKE_TEST_RESULTS.md` is updated with real deployment evidence.
