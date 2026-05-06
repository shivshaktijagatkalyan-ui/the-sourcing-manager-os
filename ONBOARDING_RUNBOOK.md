# Onboarding Runbook

## Onboard A New Organization

1. Login as an authorized admin.
2. Open `Onboard New Org`.
3. Create the organization.
4. Keep it paused until compliance and pilot approval are complete.
5. Open organization activation workflow and resume only after checks pass.

## Invite A User

1. Open `Invite User`.
2. Enter organization ID, invite reference, and target role.
3. Store the one-time invite code through your approved operator process.
4. The invitee accepts the code while authenticated.
5. User remains disabled until activation checks pass.

## Activate A User

1. Assign role and permission template.
2. Open `Activation Checks`.
3. Confirm profile completion, compliance approval, and pilot approval.
4. Run activation.
5. If blocked, inspect failed check codes. Do not bypass with manual SQL.

## Suspend A User

1. Open `Suspensions`.
2. Enter organization ID, user ID, and reason code.
3. Submit through `suspend-user`.
4. Confirm the user is disabled and an audit event exists.

## Pause Or Resume Organization

Use only Edge Functions:

- `pause-organization`
- `resume-organization`

Manual table updates are not an accepted operations path.
