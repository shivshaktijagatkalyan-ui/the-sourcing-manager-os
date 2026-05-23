# Technical Requirements Document

The system is a Flutter PWA backed by Supabase PostgreSQL, Row Level Security, and protected Edge Functions. The database is the source of truth; Edge Functions own protected actions; Flutter screens render workflow state and never expose restricted lead data.

Canonical technical references:

- [Backend architecture](FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md)
- [Backend logic connector map](architecture/BACKEND_LOGIC_CONNECTOR_MAP.md)
- [Role permission model](architecture/ROLE_PERMISSION_MODEL.md)
- [Real build verification report](reports/REAL_BUILD_VERIFICATION_REPORT.md)
