# Implementation Plan: Complete Trust Platform

**Branch**: `001-complete-trust-platform` | **Date**: 2026-05-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-complete-trust-platform/spec.md`

## Summary

Complete the production-critical FutureTrust Real Estate OS by preserving the
existing Flutter/Supabase architecture and formalizing the deterministic trust
flow from onboarding to lead ingestion, caller data loans, secure provider
calls, site visit proof, broker lock creation, super-admin governance, and
release verification. The implementation approach is brownfield hardening:
patch missing source/schema/doc/script gaps additively, keep protected actions
behind Supabase Edge Functions, and verify with local static/build gates before
any live UAT run.

## Technical Context

**Language/Version**: Dart/Flutter 3.x, TypeScript for Supabase Edge Functions
through Deno/Supabase CLI, JavaScript/PowerShell for local scripts

**Primary Dependencies**: Flutter, supabase_flutter, Supabase CLI, Supabase JS,
PostgreSQL/RLS, Exotel provider integration, optional Next.js dashboard

**Storage**: Supabase PostgreSQL with public/sensitive table split, RLS, and
append-only audit events

**Testing**: `flutter analyze`, Flutter web release build, root TypeScript check
for scripts, security scans, function drift check, Supabase dry-run, focused UAT
scripts

**Target Platform**: Flutter Web PWA, Supabase Edge Functions, Supabase remote
Postgres, local Windows PowerShell development

**Project Type**: Flutter/Supabase hybrid application with protected serverless
workflow actions

**Performance Goals**: Role dashboards remain responsive for pilot data volumes;
protected actions return stable responses without leaking PII; release build
completes successfully

**Constraints**: Preserve deterministic trust flow, WhatsApp/Exotel call flow,
Supabase persistence, PII-safe responses, and fail-closed behavior

**Scale/Scope**: Production-critical real estate sourcing pilot covering broker,
sourcing manager, caller, developer/admin, and super-admin workflows

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- PASS: Deterministic trust flow is preserved by keeping workflow transitions in
  Edge Functions, database constraints, and focused state-machine helpers.
- PASS: Supabase remains source of truth; Flutter and dashboards remain clients
  of public metadata and protected actions.
- PASS: Protected actions stay behind Edge Functions with JWT, permission, and
  service-role persistence.
- PASS: Privacy, audit events, and fail-closed behavior are explicit in every
  user story and contract.
- PASS: Verification commands are listed and tied to changed areas, with live
  UAT called out as mutating.

## Project Structure

### Documentation (this feature)

```text
specs/001-complete-trust-platform/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── protected-actions.md
│   ├── ui-service-contracts.md
│   └── verification-gates.md
└── tasks.md
```

### Source Code (repository root)

```text
flutter_app/
├── lib/
│   ├── auth/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── state/
│   └── widgets/
supabase/
├── config.toml
├── functions/
│   ├── _shared/
│   └── <protected-action>/
└── migrations/
scripts/
docs/
web-dashboard/
```

**Structure Decision**: Preserve the existing Flutter/Supabase hybrid
structure. Use additive migrations and small focused source files where required
by the target architecture. Do not redesign architecture unless a future spec
explicitly requests it and the constitution check justifies the change.

## Phase 0 Research Output

Research is captured in [research.md](research.md). Key decisions:

- Brownfield hardening instead of rewrite.
- Additive migrations for missing required tables.
- Metadata-only Flutter models/services/widgets as structural entrypoints.
- Dry-run-by-default UAT seed tooling.
- Live trust-loop UAT remains opt-in because it mutates linked remote data.

## Phase 1 Design Output

Design artifacts:

- [data-model.md](data-model.md)
- [contracts/protected-actions.md](contracts/protected-actions.md)
- [contracts/ui-service-contracts.md](contracts/ui-service-contracts.md)
- [contracts/verification-gates.md](contracts/verification-gates.md)
- [quickstart.md](quickstart.md)

## Post-Design Constitution Check

- PASS: Data model keeps sensitive and public records separated.
- PASS: Contracts route protected state changes through Edge Functions.
- PASS: UI contracts avoid direct sensitive-table access.
- PASS: Verification gates include build, typecheck, security, drift, Flutter,
  migration dry-run, and explicit live UAT decision.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
