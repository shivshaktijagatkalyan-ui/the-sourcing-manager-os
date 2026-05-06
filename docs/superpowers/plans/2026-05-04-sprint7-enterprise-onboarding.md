# Sprint 7 Enterprise Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build safe enterprise onboarding and role operations without weakening the no-phone constitution or prior sprint guarantees.

**Architecture:** Add an additive hardening migration over the existing Sprint 7 draft, then route every protected onboarding action through service-role Edge Functions. Flutter screens remain operational shells over Edge Functions and RLS-protected safe reads.

**Tech Stack:** Supabase Postgres, RLS, SECURITY DEFINER helper functions, Supabase Edge Functions, Flutter Web/PWA, Node static checks.

---

### Task 1: Static Contract Gate

**Files:**
- Create: `scripts/sprint7-static-check.mjs`
- Modify: `package.json`

- [x] Add a check that fails when required Sprint 7 tables, roles, permissions, functions, docs, or RLS hardening are missing.
- [x] Run `npm run sprint7:check` and verify it fails against the existing incomplete Sprint 7 draft.

### Task 2: Database Hardening

**Files:**
- Create: `supabase/migrations/20240510000100_sprint7_hardening.sql`

- [ ] Add missing onboarding tables and invite hardening columns.
- [ ] Seed complete roles and permissions.
- [ ] Add active-org, suspension, and permission helper functions.
- [ ] Force RLS and remove direct protected frontend mutations.
- [ ] Add safe onboarding audit helpers.

### Task 3: Edge Functions

**Files:**
- Modify: existing Sprint 7 Edge Functions.
- Create: missing Sprint 7 Edge Functions.

- [ ] Replace raw error returns with generic safe reasons.
- [ ] Remove direct identity values from audit contexts.
- [ ] Ensure invite acceptance does not activate a user.
- [ ] Add role assignment, activation, deactivation, pause, resume, and permission template workflows.

### Task 4: Flutter Screens

**Files:**
- Modify existing onboarding screens.
- Create missing onboarding operation screens.
- Modify `flutter_app/lib/main.dart`.

- [ ] Use Edge Functions for protected writes.
- [ ] Keep screens ID/status/role oriented.
- [ ] Add pending invites, activation checks, suspended users, permission template editor, and onboarding timeline screens.

### Task 5: Documentation

**Files:**
- Create/update Sprint 7 docs.

- [ ] Document role and permission model.
- [ ] Document onboarding runbook.
- [ ] Keep smoke tests pending until live verification.

### Task 6: Verification

**Commands:**
- `npm run security`
- `npm run sprint7:check`
- `flutter analyze`
- `flutter build web --release`
- `npm run build`
- `npx tsc --noEmit`

- [ ] Report unavailable or unconfigured commands as blockers, not passes.
