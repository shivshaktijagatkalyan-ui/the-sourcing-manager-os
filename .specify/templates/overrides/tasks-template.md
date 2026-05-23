---
description: "Project task list template for FutureTrust / The Sourcing Manager OS"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/,
quickstart.md

**Tests**: Include focused tests or smoke checks for every workflow/state change.
Live UAT is optional and must be called out because it can mutate the linked
remote Supabase project.

**Organization**: Tasks are grouped by user story to enable independent
implementation, verification, and deployment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no
  dependency on incomplete tasks.
- **[Story]**: Required for user-story tasks, for example `[US1]`.
- Each task MUST include exact repository-relative file paths.

## Required Final Verification

- [ ] Run `python scripts/security-check.py`
- [ ] Run `node scripts/security-check.mjs`
- [ ] Run `node scripts/check-function-drift.mjs`
- [ ] Run `npx tsc --noEmit`
- [ ] Run `flutter analyze` if Flutter code changed
- [ ] Run `npm run build`
- [ ] Run `npx supabase db push --dry-run --linked` if migrations changed
- [ ] Decide explicitly whether live UAT is safe to run
