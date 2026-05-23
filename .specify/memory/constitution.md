<!--
Sync Impact Report
Version change: template -> 1.0.0
Modified principles:
- [PRINCIPLE_1_NAME] -> I. Deterministic Trust Flow
- [PRINCIPLE_2_NAME] -> II. Supabase Is the Source of Truth
- [PRINCIPLE_3_NAME] -> III. Protected Actions Only Through Edge Functions
- [PRINCIPLE_4_NAME] -> IV. Audit, Privacy, and Fail-Closed Security
- [PRINCIPLE_5_NAME] -> V. Verification Before Completion
Added sections:
- Production Stack and Boundaries
- Development Workflow and Release Gates
Removed sections:
- Placeholder section headings and example comments
Templates requiring updates:
- ✅ .specify/templates/overrides/spec-template.md
- ✅ .specify/templates/overrides/plan-template.md
- ✅ .specify/templates/overrides/tasks-template.md
Follow-up TODOs: none
-->

# The Sourcing Manager OS Constitution

## Core Principles

### I. Deterministic Trust Flow

The system MUST preserve a deterministic sales and trust lifecycle over generic
AI behavior. Lead intake, duplicate checks, caller assignment, data loan access,
secure call bridging, site visit proposal, GPS/photo verification, broker lock
creation, brokerage eligibility, and final lead state transitions MUST be
explicitly modeled and testable. AI-assisted tooling MAY recommend next actions,
but it MUST NOT bypass state machines, expose restricted data, or decide payout
eligibility without the server-side trust flow.

### II. Supabase Is the Source of Truth

Supabase PostgreSQL MUST remain the authoritative store for organizations,
roles, leads, loans, calls, visits, proof, broker locks, audit events, risk
events, trust scores, system health, and governance records. Flutter, web
dashboards, scripts, and AI tools are clients of this source of truth; they MUST
NOT maintain competing business state. Schema changes MUST be additive and
idempotent unless an explicit migration plan justifies a breaking change.

### III. Protected Actions Only Through Edge Functions

Protected business actions MUST execute through Supabase Edge Functions with
JWT validation, role/permission checks, service-role persistence, stable public
error codes, and PII-safe responses. Frontend clients MUST NOT write sensitive
tables directly, decrypt lead contact data, create broker locks, mark visits
verified, or grant data loans outside the protected server boundary.
WhatsApp/Exotel call flow MUST be preserved when changing call, follow-up,
webhook, or state machine logic.

### IV. Audit, Privacy, and Fail-Closed Security

The platform MUST treat audit evidence as proof. Every protected state change
MUST write PII-safe audit metadata sufficient to reconstruct who acted, on which
organization or lead, and why the transition was accepted or rejected. Restricted
contact data MUST remain encrypted or hashed in sensitive storage and MUST NOT
be displayed, logged, returned to AI tools, or exposed through masked fragments.
If role status, organization status, provider callback authenticity, GPS proof,
photo proof, or data loan validity cannot be verified, the action MUST fail
closed.

### V. Verification Before Completion

No work may be marked complete without fresh verification evidence. The default
release checks are `npm run build`, `npx tsc --noEmit`, security scans,
function/config drift checks, Flutter analysis where frontend code changed, and
Supabase migration dry-runs when migrations changed. Live UAT scripts that
mutate the linked remote project MUST be called out explicitly before running.
If a gate is not applicable because of the Flutter/Supabase hybrid architecture,
the reason MUST be documented with the nearest applicable verification result.

## Production Stack and Boundaries

The product is a Flutter Web PWA with Supabase PostgreSQL, Supabase Auth, Row
Level Security, Supabase Edge Functions, and Exotel/WhatsApp-adjacent call
provider flows. The repository also contains a Next.js web-dashboard surface,
automation scripts, release reports, and runbooks. Production source belongs in
`flutter_app/`, `supabase/`, `web-dashboard/`, and `scripts/`; architecture,
security, product, release, and runbook evidence belongs under `docs/`.

Root Node.js tooling is verification glue, not the primary application runtime.
TypeScript under `supabase/functions/` is Deno-managed through the Supabase CLI.
Flutter release output is the production frontend artifact. Environment-specific
failures MUST be evaluated against Production versus Preview assumptions before
code is changed.

## Development Workflow and Release Gates

Every change MUST start by reading the existing repo shape and preserving
current architecture unless a redesign is explicitly requested. Patches MUST be
minimal, production-safe, and compatible with existing Supabase persistence and
WhatsApp/Exotel send flow. When changing follow-ups, webhooks, lead state,
caller workflow, site visit proof, or broker lock logic, the change MUST include
or update deterministic verification of the affected transition.

Spec Kit artifacts MUST trace requirements to implementation tasks. A feature
is ready for implementation only when `spec.md`, `plan.md`, `data-model.md`,
contracts or UI/service contracts where relevant, `quickstart.md`, and
`tasks.md` agree with this constitution. Tasks MUST use exact file paths and
must be independently testable by user story.

## Governance

This constitution supersedes informal project habits and generic agent defaults.
Amendments require a documented reason, semantic version update, date update,
and a review of dependent Spec Kit templates and active feature specs. Major
version changes are required for principle removals or incompatible governance
changes. Minor version changes are required for new principles or materially
expanded gates. Patch version changes are reserved for clarifications that do
not alter obligations.

Pull requests, commits, and completion reports MUST state the verification
commands run and any skipped gates. Generated artifacts are allowed only when
they preserve the production-critical rules above and do not obscure the
business trust flow.

**Version**: 1.0.0 | **Ratified**: 2026-05-04 | **Last Amended**: 2026-05-23
