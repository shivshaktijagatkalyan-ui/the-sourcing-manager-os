# Backend Architecture

Supabase PostgreSQL stores the source of truth. Edge Functions perform protected actions with service-role access, JWT checks, role permissions, safe response shaping, and append-only audit events.

Canonical references:

- [FutureTrust production backend architecture](FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md)
- [Backend logic connector map](architecture/BACKEND_LOGIC_CONNECTOR_MAP.md)
- [Edge Function security report](reports/EDGE_FUNCTION_SECURITY_REPORT.md)
