# AI Safe Tool Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a metadata-only AI tool layer for FutureTrust without weakening RLS, Edge Function governance, or the Dataless Constitution.

**Architecture:** Implement six Supabase Edge Functions with JWT verification and shared Sprint 7 helpers. Add a static gate that proves every required tool exists, is registered, avoids sensitive tables, returns expected metadata fields, and records protected mutations through audit events.

**Tech Stack:** Supabase Edge Functions, Deno TypeScript, Node static verification scripts, Flutter/Supabase release gates.

---

### Task 1: Static Gate

**Files:**
- Create: `scripts/ai-safe-tool-check.mjs`
- Modify: `package.json`

- [x] **Step 1: Add required tool inventory check**

Create a Node script that checks for the six required function directories:

```js
const requiredTools = [
  'trust-get-lead-summary',
  'trust-get-broker-lock-status',
  'trust-get-followup-risk',
  'trust-get-site-visit-proof',
  'trust-create-followup',
  'trust-recommend-next-action',
];
```

- [x] **Step 2: Add metadata-only source checks**

The script must fail if any tool source references `leads_sensitive`, `brokers_sensitive`, `decrypt`, direct runtime logging, raw error message returns, `tel:`, `wa.me`, or `api.whatsapp.com`.

- [x] **Step 3: Run red check**

Run:

```powershell
node scripts/ai-safe-tool-check.mjs
```

Expected: FAIL because the required tool directories do not exist yet.

### Task 2: Edge Functions

**Files:**
- Create: `supabase/functions/trust-get-lead-summary/index.ts`
- Create: `supabase/functions/trust-get-broker-lock-status/index.ts`
- Create: `supabase/functions/trust-get-followup-risk/index.ts`
- Create: `supabase/functions/trust-get-site-visit-proof/index.ts`
- Create: `supabase/functions/trust-create-followup/index.ts`
- Create: `supabase/functions/trust-recommend-next-action/index.ts`
- Modify: `supabase/config.toml`

- [x] **Step 1: Implement read-only lead summary**

Use `currentUser`, `adminClient`, `validUuid`, `safeJson`, and `requirePermission`. Return only alias, status, budget range, area, project interest, and source broker id.

- [x] **Step 2: Implement lock status**

Return active lock status, days remaining, brokerage status, and proof status from `broker_locks` and linked public metadata only.

- [x] **Step 3: Implement follow-up risk**

Return deterministic risk from public lead follow-up timestamps and status. Do not use generative AI.

- [x] **Step 4: Implement site visit proof summary**

Return proof booleans, timestamp, and proof status only.

- [x] **Step 5: Implement follow-up creation**

Create a metadata-only `broker_followups` row through the Edge Function, then create a PII-safe audit event. Return the audit event id when available.

- [x] **Step 6: Implement deterministic next action**

Return one of `call_now`, `schedule_visit`, `verify_site_visit`, `resolve_blocker`, `monitor_lock`, or `wait` with reason, risk, and confidence from current metadata.

- [x] **Step 7: Register functions**

Add each function to `supabase/config.toml` with `verify_jwt = true`.

### Task 3: Reports

**Files:**
- Create: `PHASE_1_TRUST_LOOP_COMPLETION_REPORT.md`
- Create: `AI_SAFE_TOOL_LAYER_REPORT.md`
- Create: `FUTURETRUST_RAG_ARCHITECTURE_REPORT.md`
- Create: `AI_COPILOT_PRODUCT_SPEC.md`
- Create: `TRUST_OBSERVABILITY_DASHBOARD_SPEC.md`
- Create: `AI_TRUST_EVALS_REPORT.md`
- Create: `PREMIUM_UI_UX_UPGRADE_REPORT.md`
- Create: `FUTURETRUST_CONTENT_ENGINE_STRATEGY.md`
- Create: `FUTURETRUST_AI_NATIVE_OS_UPGRADE_REPORT.md`

- [x] **Step 1: Document Phase 1 truth**

Report provider/caller blockers as blockers, not readiness.

- [x] **Step 2: Document AI tool layer**

Describe tools, inputs, outputs, restrictions, and verification.

- [x] **Step 3: Document RAG, copilots, observability, evals, UI, and content**

Keep all future AI architecture metadata-only and tool-mediated.

### Task 4: Verification

**Files:**
- Read-only verification across source and generated reports

- [x] **Step 1: Run focused AI gate**

Run:

```powershell
node scripts/ai-safe-tool-check.mjs
```

Expected: PASS.

- [x] **Step 2: Run required project gates**

Run:

```powershell
python scripts/security-check.py
npm run security
npm run sprint7:check
npx tsc --noEmit
npm run build
cd flutter_app
flutter analyze
flutter build web --release
flutter build apk --release
cd ..
powershell -ExecutionPolicy Bypass -File scripts/release-gate.ps1
```

Expected: static/build gates pass. Release gate may still report UAT blocked if caller/provider configuration is absent.
