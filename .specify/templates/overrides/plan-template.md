# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

## Summary

[Extract from feature spec: primary requirement + technical approach]

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

- Deterministic trust flow is preserved and state transitions are explicit.
- Supabase remains source of truth; no competing frontend business state.
- Protected actions stay behind Edge Functions with JWT/permission checks.
- Privacy, audit events, and fail-closed behavior are included in design.
- Verification commands are listed and tied to changed areas.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
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

**Structure Decision**: Preserve the existing Flutter/Supabase hybrid structure.
Do not redesign architecture unless a feature explicitly requires it and the
constitution check justifies the change.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
