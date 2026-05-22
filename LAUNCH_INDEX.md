# Launch Index

Use this file as the root launch navigation point after the project folder cleanup.

## Required Launch Documents

- `docs/runbooks/LAUNCH_RUNBOOK.md` - launch-day execution.
- `docs/runbooks/DEPLOYMENT_ROLLBACK.md` - rollback procedure.
- `docs/runbooks/PRODUCTION_READINESS.md` - production readiness notes.
- `docs/runbooks/PRODUCTION_READINESS_REPORT.md` - detailed readiness report.
- `docs/releases/PROJECT_COMPLETION_SUMMARY.md` - executive completion summary.
- `docs/releases/V1_LAUNCH_ACCEPTANCE_GATE.md` - launch acceptance gate.
- `docs/security/PRIVACY_POLICY.md` - privacy policy.
- `docs/security/TERMS_OF_USE.md` - terms of use.
- `docs/security/CORE_LOGIC_CONSTITUTION.md` - trust and PII constitution.

## Backend Trust Documents

- `docs/reports/BROKER_DASHBOARD_MASTER_BLUEPRINT_REPORT_2026-05-19.md` - broker dashboard trust vault blueprint and completion plan.
- `docs/reports/FUTURETRUST_MASTER_BLUEPRINT_STRATEGY_SYNTHESIS_2026-05-19.md` - consolidated strategy and readiness synthesis.
- `docs/architecture/FUTURETRUST_MASTER_STRATEGY_GOVERNANCE_BLUEPRINT.md` - master strategy and governance blueprint.
- `docs/FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md` - production backend blueprint.
- `docs/architecture/BACKEND_LOGIC_CONNECTOR_MAP.md` - backend connector map.
- `docs/architecture/FUTURETRUST_LEAD_LIFECYCLE_STATE_MACHINE.md` - lead lifecycle model.
- `docs/reports/AI_SAFE_TOOL_LAYER_REPORT.md` - AI-safe tool layer report.
- `docs/security/PROVIDER_CALLBACK_SECURITY_REPORT.md` - provider callback hardening.

## Operational Verification

Run these gates before declaring the project ready:

```powershell
npm run build
npx tsc --noEmit
npm run security
```

Project-specific deployment checks still require Supabase CLI access, Flutter SDK, provider secrets, and live UAT evidence.

## Cleanup Notes

The root folder intentionally keeps only high-signal project files and source folders. Historical reports, sprint documents, launch prep notes, and generated logs were moved under `docs/` during the `2026-05-19` cleanup pass.
