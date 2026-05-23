# Project File Index

Date: 2026-05-19
Branch: `codex/project-folder-cleanup`

This file is the alias map for the cleaned project folder. It explains where common files now live and which folders should be treated as source, docs, archive, or generated evidence.

## Root Files Kept

- `README.md` - project overview.
- `START_HERE.md` - root navigation.
- `LAUNCH_INDEX.md` - launch navigation.
- `AGENTS.md` - repo-specific agent rules.
- `ARCHITECTURE.md` - short architecture overview.
- `DEPLOYMENT.md` - deployment overview.
- `SECURITY.md` - security policy.
- `LICENSE` - license.
- `package.json`, `package-lock.json`, `tsconfig.json` - Node verification/tooling.
- `.env.example`, `.cspell.json`, `.markdownlint.json`, `.gitignore` - local/tool config.
- `docker-compose.yml` - local container config.
- `provider.env` - provider-local environment file.

## Source Folders

- `supabase/functions/` - production Edge Functions.
- `supabase/migrations/` - database migrations. Do not combine or rename these casually.
- `supabase/snippets/manual/` - manual SQL snippets moved out of root.
- `flutter_app/` - Flutter application source and tests.
- `web-dashboard/` - Next.js dashboard source.
- `scripts/` - UAT, security, deployment, and inspection scripts.

## Documentation Folders

- `docs/PRD.md`, `docs/TRD.md`, `docs/APP_FLOW.md`, and other root-level docs - stable entrypoints for reviewers; most link to canonical docs in the folders below.
- `specs/` - Spec Kit feature specifications, plans, contracts, task lists, quickstarts, and analysis reports.
- `docs/architecture/` - backend maps, state machines, blueprint, models, and system strategy.
- `docs/reports/` - audit reports, status reports, smoke-test results, verification reports, and fix reports.
- `docs/runbooks/` - deployment, launch, pilot, onboarding, UAT, rollback, and operating procedures.
- `docs/security/` - compliance, privacy, PII, abuse, risk, lock, and constitution documents.
- `docs/security/MCP_AND_CONNECTORS_SECURITY.md` - OpenAI connectors, remote MCP, local skills, secret handling, and approval policy for agent tooling.
- `docs/product/` - sprint specs, MVP plans, training docs, and product workflow notes.
- `docs/releases/` - release notes, changelog, completion docs, and launch gates.
- `docs/archive/root-cleanup-2026-05-19/` - old loose docs and generated log/evidence files preserved for traceability.

## Moved Manual SQL

- `assign_admin_role.sql` -> `supabase/snippets/manual/assign_admin_role.sql`
- `RLS_FIX.sql` -> `supabase/snippets/manual/RLS_FIX.sql`

## Archived Generated Evidence

Root-level `*.log` files and `login_test.txt` were moved to:

```text
docs/archive/root-cleanup-2026-05-19/logs/
```

Two runtime logs remained in the root because Windows reported them as locked by another process:

```text
flutter_local_5055.err.log
flutter_local_5055.out.log
```

They are already covered by `.gitignore` and can be moved to the same archive folder after the process using them is stopped.

## Cleanup Rules Going Forward

- Keep production source in source folders, not the root.
- Keep Spec Kit governance in `.specify/`, agent skills in `.agents/skills/`, and feature work under `specs/`.
- Put new architecture docs in `docs/architecture/`.
- Put new launch or operational procedure docs in `docs/runbooks/`.
- Put verification output, audits, and sprint results in `docs/reports/`.
- Put old generated evidence in `docs/archive/<date>/`.
- Do not merge Supabase migrations unless the database deployment history is intentionally being rewritten.
- Do not move env files, production source folders, or deployment config without a specific reason.

## Key Strategy Documents

- `docs/reports/BROKER_DASHBOARD_MASTER_BLUEPRINT_REPORT_2026-05-19.md` - full broker dashboard product, backend, frontend, data, UX, and completion blueprint.
- `docs/reports/FUTURETRUST_MASTER_BLUEPRINT_STRATEGY_SYNTHESIS_2026-05-19.md` - consolidated analysis of master, blueprint, strategy, roadmap, trust, AI, goal, and pilot documents.
- `docs/architecture/FUTURETRUST_MASTER_STRATEGY_GOVERNANCE_BLUEPRINT.md` - master strategy, category design, governance thesis, rollout strategy, and long-term roadmap.
- `docs/FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md` - production backend architecture and Supabase control-plane blueprint.
