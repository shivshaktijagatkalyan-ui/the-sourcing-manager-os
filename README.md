# The Sourcing Manager OS (v1.0.0-stable)

## Status: LAUNCH READY

An open-source, trustless enforcement layer for real estate sourcing operations. The system, not user honesty, controls sensitive lead access and commission verification.

## Core Pillars

- **Data Privacy (Sprint 1)**: AES-256 encrypted leads. No PII visible to Managers/Callers.
- **Verification Engine (Sprint 2)**: GPS Geofencing and Live Photo evidence. 45-day commission locks.
- **Operational Trust (Sprint 3)**: Role-based data loan rules and pilot organizations.
- **Abuse Monitoring (Sprint 4)**: Proactive security with automated risk flagging.
- **Scalable Enforcement (Sprint 5)**: Trust-gated routing, verified payout ledger, and broker performance visibility.
- **Governance & Compliance (Sprint 6)**: DPDP Consent, TRAI DND Audit, and Payout Statements.
- **Enterprise Onboarding (Sprint 7)**: RBAC Matrix and Organization Lifecycle management.
- **Field UX & Training (Sprint 8)**: Role dashboards, Hinglish guidance, and Training Mode.
- **Reliability & Control (Sprint 9)**: Health Monitoring, Rate Limiting, and Rollback Discipline.
- **Launch & Hardening (Sprint 10)**: Final Security Audit, Legal Drafts, and Runbooks.

## Tech Stack

- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions)
- **Frontend**: Flutter PWA (Material 3, Google Fonts)
- **Security**: pgcrypto, Row Level Security (RLS), and append-only audit trails.
- **Integrations**: Exotel (PSTN Bridging).

## Getting Started

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Docker](https://www.docker.com/get-started) (for local testing)

### 2. Database Setup

```powershell
supabase db push
```

### 3. Edge Functions

```powershell
# Set secrets from .env.example
supabase secrets set --env-file ./supabase/.env
supabase functions deploy --all
```

### 4. Flutter App

```powershell
cd flutter_app
flutter run -d chrome
```

## Security Model

The system operates on a **Fail-Closed** architecture. If a user is disabled, an organization is paused, or a trust score drops below threshold, all operational access (Calls, Visits, Payouts) is immediately revoked by the database engine, not the application layer.

## License

AGPLv3
