# Backup & Restore Policy (Sprint 9)

## 1. Backup Strategy

- **Daily Backups**: Automated by Supabase (Pro Plan).
- **Verification**: The `backup-verify` Edge Function checks backup metadata daily.
- **Pre-deployment**: A manual backup record must be created in `backup_runs` before applying any irreversible migration.

## 2. Retention Policy

- **Audit Logs**: 1 year.
- **Evidence (Storage)**: 45 days (matching commission lock) + 15 days grace period.
- **Payout Ledger**: Indefinite (Tax/Legal requirement).
- **Failure Logs**: 30 days.

## 3. Restore Drills

- **Frequency**: Monthly.
- **Process**: Restore a point-in-time backup to a staging environment and verify the `pilot_users` and `payout_ledger` integrity.
- **Recording**: Results must be logged in the `restore_drills` table.

## 4. Disaster Recovery

In the event of total project failure:

1. Re-initialize project from `supabase/migrations`.
2. Restore latest Postgres dump.
3. Re-link Exotel credentials.
4. Notify all organizations via incident-response channel.
