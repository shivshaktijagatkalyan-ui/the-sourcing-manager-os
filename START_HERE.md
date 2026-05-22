# Start Here

This repository is now organized around a small root and structured documentation folders.

## Core Entry Points

- `README.md` - project overview.
- `AGENTS.md` - agent and verification rules for this repo.
- `ARCHITECTURE.md` - short architecture overview.
- `DEPLOYMENT.md` - deployment guidance.
- `SECURITY.md` - security policy.
- `LAUNCH_INDEX.md` - launch and operations navigation.
- `docs/PROJECT_FILE_INDEX.md` - file location and cleanup map.
- `docs/reports/BROKER_DASHBOARD_MASTER_BLUEPRINT_REPORT_2026-05-19.md` - broker dashboard vision, backend/frontend logic, UX direction, and completion roadmap.
- `docs/reports/FUTURETRUST_MASTER_BLUEPRINT_STRATEGY_SYNTHESIS_2026-05-19.md` - consolidated strategy/readiness analysis across the master blueprint corpus.
- `docs/architecture/FUTURETRUST_MASTER_STRATEGY_GOVERNANCE_BLUEPRINT.md` - master strategy, category, roadmap, and governance thesis.
- `docs/FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md` - production backend blueprint.

## Source Folders

- `supabase/` - migrations, Edge Functions, config, and SQL snippets.
- `flutter_app/` - Flutter web/mobile application.
- `web-dashboard/` - Next.js dashboard surface.
- `scripts/` - verification, UAT, deployment, and inspection scripts.
- `react_components/` - standalone dashboard components.

## Documentation Folders

- `docs/architecture/` - system design, lifecycle, role, AI, trust, and backend maps.
- `docs/reports/` - audits, verification reports, sprint results, and completion reports.
- `docs/runbooks/` - launch, deployment, onboarding, UAT, pilot, and recovery procedures.
- `docs/security/` - constitution, privacy, compliance, abuse, risk, and PII documents.
- `docs/product/` - sprint specs, MVP notes, training mode, and product workflow docs.
- `docs/releases/` - changelog, release notes, launch gates, and completion summaries.
- `docs/archive/root-cleanup-2026-05-19/` - old loose docs and generated logs kept for traceability.

## Verification

Before finishing backend or project-structure work, run:

```powershell
npm run build
npx tsc --noEmit
npm run security
```

For this Flutter/Supabase repo, `npm run build` delegates to the Flutter web release build.
