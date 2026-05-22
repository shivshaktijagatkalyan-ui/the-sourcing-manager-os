# FutureTrust Onboarding Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the executive onboarding trust-loop entrypoint so it fails closed, uses canonical Sprint 7 roles, and never returns raw internal errors.

**Architecture:** Keep the existing Edge Function and Supabase schema. Add static security gates that catch raw Edge Function error leakage, then patch only `complete-onboarding` to preserve the current Flutter onboarding flow while aligning with the canonical role catalog.

**Tech Stack:** Supabase Edge Functions, Deno TypeScript source, Node/Python security gate scripts, Flutter/Supabase client flow.

---

### Task 1: Security Gate Coverage

**Files:**
- Modify: `scripts/security-check.mjs`
- Modify: `scripts/security-check.py`

- [x] **Step 1: Add raw-error response detection to Node gate**

Add a rule to flag Edge Function source that returns `err.message`, `error.message`, `msg`, or an `unknown_error` fallback as a client response reason:

```js
const rawErrorResponsePatterns = [
  { pattern: /reason:\s*(err|error)\.message/i, reason: 'raw internal error messages must not be returned to clients' },
  { pattern: /const\s+msg\s*=\s*error\s+instanceof\s+Error\s*\?\s*error\.message\s*:/i, reason: 'raw internal error aliases must not be returned to clients' },
  { pattern: /reason:\s*msg\b/i, reason: 'raw internal error aliases must not be returned to clients' },
  { pattern: /unknown_error/i, reason: 'generic internal failures should use stable public reason codes' },
];
```

- [x] **Step 2: Run Node gate and confirm RED**

Run: `npm run security`

Expected: FAIL on `supabase/functions/complete-onboarding/index.ts` because it returns a raw `msg` reason and uses `unknown_error`.

- [x] **Step 3: Add matching Python gate**

Add equivalent regex checks in `scripts/security-check.py` so the documented Python gate catches the same class of failure.

- [x] **Step 4: Run Python gate and confirm RED**

Run: `python scripts/security-check.py`

Expected: FAIL on `supabase/functions/complete-onboarding/index.ts` for raw internal error response hygiene.

### Task 2: Complete Onboarding Patch

**Files:**
- Modify: `supabase/functions/complete-onboarding/index.ts`

- [x] **Step 1: Canonicalize allowed roles**

Replace the legacy role allowlist:

```ts
const allowedRoles = ['broker_owner', 'broker', 'sourcing_manager', 'caller'];
```

with:

```ts
const allowedRoles = ['broker_owner', 'broker_agent', 'sourcing_manager', 'caller'];
```

and map legacy client role `broker` to `broker_owner` before validation so existing Flutter clients remain compatible.

- [x] **Step 2: Fail closed on raw errors**

Replace:

```ts
const msg = error instanceof Error ? error.message : 'unknown_error';
return safeJson({ ok: false, reason: msg }, 400);
```

with a stable public response:

```ts
return safeJson({ ok: false, reason: 'onboarding_failed' }, 400);
```

- [x] **Step 3: Preserve broker profile path**

Ensure the broker profile branch handles `broker_owner` and `broker_agent` only:

```ts
if (role === 'broker_owner' || role === 'broker_agent') {
```

### Task 3: Verification

**Files:**
- Read-only verification across scripts and Flutter/Supabase source

- [x] **Step 1: Run focused gates**

Run:

```powershell
npm run security
python scripts/security-check.py
```

Expected: both pass after the Edge Function patch.

- [x] **Step 2: Run project gates required by AGENTS.md and the PRD/TRD**

Run:

```powershell
npm run build
npx tsc --noEmit
flutter analyze
flutter build web --release
npm run sprint7:check
node scripts/uat-trust-loop.mjs
```

Expected: local deterministic gates pass. Live UAT may be blocked if provider secrets or test credentials are missing; blocked live dependencies must not be called production-ready.
