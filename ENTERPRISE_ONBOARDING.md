# Enterprise Onboarding

Sprint 7 onboarding is self-serve only through Edge Functions. Protected onboarding tables do not allow direct frontend mutation.

## Organization Flow

1. `create-organization`
   - Requires `can_manage_org_users`.
   - Creates organization in `paused` status.
   - Creates an organization profile with pending compliance and pilot status.
   - Writes sanitized onboarding audit records.

2. `resume-organization`
   - Requires `can_pause_org`.
   - Runs organization activation checks.
   - Moves organization to `active` only after pilot and compliance approval.

3. `pause-organization`
   - Requires `can_pause_org`.
   - Sets organization to `paused`.
   - Blocks protected workflows through existing pilot checks.

## User Flow

1. `invite-user`
   - Requires `can_manage_org_users`.
   - Stores a hashed invite reference and hashed one-time invite code.
   - Returns the invite code once to the authorized operator.

2. `accept-invite`
   - Authenticated invitee submits the one-time invite code.
   - Creates or updates `pilot_users` as `disabled`.
   - Creates role assignment and safe profile shell.
   - Does not activate the user.

3. `assign-role`
   - Requires `can_manage_org_users`.
   - Assigns the enterprise role and permission template.

4. `activate-user`
   - Requires `can_manage_org_users`.
   - Runs activation checks.
   - Activates only when all checks pass.

5. `deactivate-user` and `suspend-user`
   - Disable access and write audit events.

## Audit Boundary

Onboarding audit records may contain:

- organization ID
- target user ID
- invite ID
- role ID
- permission template ID
- status code
- reason code
- check counts

They must not contain customer names, customer contact data, raw invite references, raw provider payloads, or free-form personal details.
