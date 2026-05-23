# Database Schema

The production schema is represented by timestamped Supabase migrations under `supabase/migrations/`. Core domains include organizations, role assignments, permission templates, public and sensitive lead storage, data loans, call attempts, site visits, proof metadata, broker locks, projects, inventory, audit events, abuse events, risk notifications, trust scores, and system health events.

Canonical references:

- [Supabase migrations](../supabase/migrations/)
- [Database isolation verification report](reports/DB_ISOLATION_VERIFICATION_REPORT.md)
- [Full project core logic audit](reports/FULL_PROJECT_CORE_LOGIC_AUDIT.md)
