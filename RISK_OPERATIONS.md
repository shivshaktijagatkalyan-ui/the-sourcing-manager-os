# Risk Operations

Sprint 4 gives pilot admins operational visibility without weakening data enforcement.

## Daily Operating Flow

1. Open the Ops Control Room.
2. Refresh risk summary.
3. Review critical and high abuse events.
4. Acknowledge risk notifications.
5. Resolve or dismiss events after evidence review.
6. Run trust decay on the approved schedule.
7. Review pilot activity trends.

## Notification Flow

Table: `public.risk_notifications`

Functions:

- `create-risk-notification`
- `acknowledge-risk-notification`

Notifications are reason-code based. They do not include customer identity, raw provider payloads, free-form personal details, or storage paths that include names.

## Freeze Recommendations

Critical abuse events can generate:

- `user_freeze_recommended`
- `org_freeze_recommended`

Sprint 4 records recommendations. Actual freeze actions should remain admin-controlled and auditable through the pilot admin console.

## RLS Expectations

Allowed:

- active pilot admin reads organization risk records
- active pilot user reads their own safe trust history if policy allows
- notification recipient reads their own notification inside an active pilot organization

Blocked:

- non-admin reading abuse dashboards
- disabled user reading operational risk records
- paused organization reading operational risk records
- direct client insert/update/delete on risk tables

## Deployment

Run:

```powershell
.\scripts\production-deploy.ps1
```

The script runs the security scan, applies migrations, deploys all Edge Functions, and builds the Flutter PWA.

Sprint 4 remains pending until `SPRINT_4_SMOKE_TEST_RESULTS.md` contains real test results.
