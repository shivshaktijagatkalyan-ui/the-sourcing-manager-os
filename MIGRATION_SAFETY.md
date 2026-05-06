# Migration Safety & Discipline (Sprint 9)

To ensure 99.9% uptime during pilot operations, all database migrations must follow these rules:

## 1. No Destructive Schema Changes

- Never `DROP COLUMN` or `RENAME COLUMN` on a live production table.
- **Approach**: Add new column -> Sync data -> Deprecate old column in code -> Drop old column in next sprint.

## 2. Default-Safe Migrations

- All new tables must have RLS enabled by default.
- Use `IF NOT EXISTS` for all indices and extensions.

## 3. Transactional Integrity

- Every migration should be tested to ensure it doesn't lock the `auth.users` or `leads_public` tables for more than 5 seconds.

## 4. Rollback Strategy

- Every migration file should ideally have a corresponding manual rollback snippet documented in its header.
