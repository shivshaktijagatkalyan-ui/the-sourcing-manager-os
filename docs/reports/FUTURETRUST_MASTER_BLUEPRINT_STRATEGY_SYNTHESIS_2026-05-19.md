# FutureTrust Master Blueprint Strategy Synthesis

Date: 2026-05-19
Branch: `codex/project-folder-cleanup`
Scope: Master, blueprint, strategy, roadmap, trust, AI, goal, pilot, and architecture documents in the cleaned project folder.

## Executive Summary

FutureTrust is consistently defined across the blueprint corpus as a real estate operational trust infrastructure product, not a CRM. The core product thesis is stable: protect broker attribution, isolate PII, govern workforce actions through role and data-loan controls, verify physical site visits, and preserve audit continuity.

The architecture is also internally consistent. Most documents point to the same spine:

```text
Lead intake
-> encryption and hashing
-> duplicate prevention
-> broker attribution
-> governed caller assignment
-> data loan
-> secure Exotel call
-> outcome and follow-up
-> site visit proposal
-> GPS/photo proof
-> verified visit
-> broker lock
-> payout eligibility
-> audit and risk monitoring
```

The main issue is not strategy quality. The main issue is readiness consistency. Several older launch/completion documents describe the system as production-ready, but the stricter and more recent trust-loop documents say the official verdict is:

```text
B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN
```

That stricter verdict should be treated as the current source of truth until live provider handoff, valid Exotel callback, site visit proof, broker lock, and release-gate evidence all pass in the production environment.

## Source Corpus Reviewed

Primary architecture and strategy files:

- `ARCHITECTURE.md`
- `docs/FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md`
- `docs/architecture/FUTURETRUST_MASTER_STRATEGY_GOVERNANCE_BLUEPRINT.md`
- `docs/architecture/FUTURETRUST_OPERATIONAL_BLUEPRINT_MASTER.md`
- `docs/architecture/FUTURETRUST_LEAD_LIFECYCLE_STATE_MACHINE.md`
- `docs/architecture/ROADMAP_BLUEPRINT.md`
- `docs/architecture/TARGET_DRIVEN_SALES_ENGINE_BLUEPRINT.md`
- `docs/architecture/BACKEND_LOGIC_CONNECTOR_MAP.md`
- `docs/architecture/broker-dashboard-data-contract.md`
- `docs/architecture/FUTURETRUST_CONTENT_ENGINE_STRATEGY.md`
- `docs/architecture/TRUST_DECAY_MODEL.md`
- `docs/architecture/TRUST_OBSERVABILITY_DASHBOARD_SPEC.md`
- `docs/architecture/VERDICT_B_TO_A_TRANSITION_ROADMAP.md`
- `docs/architecture/ROLE_PERMISSION_MODEL.md`

Product, AI, trust, pilot, and readiness files:

- `docs/product/PRACTICAL_MVP_ROADMAP.md`
- `docs/product/TRAINING_MODE.md`
- `docs/product/USER_TRAINING_PACK.md`
- `docs/reports/AI_SAFE_TOOL_LAYER_REPORT.md`
- `docs/reports/AI_TRUST_EVALS_REPORT.md`
- `docs/reports/FUTURETRUST_AI_NATIVE_OS_UPGRADE_REPORT.md`
- `docs/reports/FUTURETRUST_RAG_ARCHITECTURE_REPORT.md`
- `docs/reports/FUTURETRUST_REAL_ESTATE_OS_DEEP_RESEARCH_AUDIT_2026-05-16.md`
- `docs/reports/FUTURETRUST_TRUST_INFRASTRUCTURE_AUDIT_2026-05-15.md`
- `docs/reports/FULL_MASTER_RECHECK_REPORT_2026-05-16.md`
- `docs/reports/MASTER_PROJECT_REPORT_v1.0.0.md`
- `docs/reports/MASTER_PROJECT_STATUS_AUDIT.md`
- `docs/reports/PHASE_1_TRUST_LOOP_COMPLETION_REPORT.md`
- `docs/reports/TEN_YEAR_AHEAD_AI_READY_SM_OS_REPORT.md`
- `docs/reports/TRAINING_MODE_PRODUCTION_GATE_REPORT.md`
- `docs/reports/TRUST_LOOP_UAT_REPORT.md`
- `docs/runbooks/AI_COPILOT_PRODUCT_SPEC.md`
- `docs/runbooks/CONTROLLED_TRUST_LOOP_PILOT_STATUS.md`
- `docs/runbooks/PRACTICAL_MVP_PILOT_PLAN.md`
- `docs/runbooks/UAT_TEST_PLAN.md`
- `docs/runbooks/DAILY_USAGE_CHECKLIST.md`
- `docs/runbooks/DATA_CLEANUP_PLAN.md`
- `docs/security/BROKER_LOCK_TRUST_TEST_REPORT.md`
- `docs/superpowers/plans/2026-05-15-futuretrust-onboarding-hardening.md`
- `docs/superpowers/plans/2026-05-16-ai-safe-tool-layer.md`

## Consolidated Product Definition

FutureTrust should be described as:

```text
Real Estate Operational Trust Infrastructure for Indian real estate sourcing.
```

It is not:

- a generic CRM,
- a lead marketplace,
- a telecalling application,
- a dashboard-only SaaS product,
- an AI-first automation layer.

It is:

- an attribution protection engine,
- a governed workflow operating system,
- a PII-isolated lead vault,
- a caller and sourcing-manager coordination system,
- a site-visit proof system,
- an audit and abuse evidence layer,
- a metadata-only AI tool platform.

## Core Strategic Thesis

The corpus repeats one central thesis: trust must be implemented as system architecture, not assumed as human behavior.

The strongest recurring strategy points are:

- Brokers contribute higher-quality leads only when attribution theft risk is reduced.
- Developers pay and optimize better when site visits are verified rather than claimed.
- Buyers are protected when phone numbers do not leak into calling lists.
- Callers remain productive when they get governed queues instead of unrestricted contact access.
- Sourcing managers become more valuable when field work creates durable proof.
- AI is valuable only when subordinate to deterministic workflow rules and metadata-only tools.

## Non-Negotiable Constitution

The following rules are consistent across the major docs and should be treated as the product constitution:

- No raw phone exposure.
- No masked phone display.
- No last-four display.
- No WhatsApp direct links.
- No `tel:` links.
- No contact export.
- No phone numbers in logs.
- No phone numbers in audit events.
- No frontend sensitive table reads.
- PII is stored only as encrypted ciphertext.
- Contact hashes are used only for duplicate detection.
- Calls happen only through governed provider bridges.
- Data loans are required for call access.
- Protected mutations go through Edge Functions or service-role RPCs.
- Site visit verification requires proof.
- Broker locks require verified site visits.
- AI receives metadata only.
- System fails closed.

## Backend Architecture Synthesis

The backend architecture is built around Supabase, Postgres, RLS, Edge Functions, service-role RPCs, Storage, Exotel, JWT auth, and audit tables.

The core data split is:

- `leads_public`: safe lead metadata, alias, area, budget, routing, lifecycle state, attribution references.
- `leads_sensitive`: encrypted phone ciphertext and private duplicate hash.
- `brokers_public`: safe broker profile and assignment data.
- `brokers_sensitive`: encrypted broker contact data.
- `data_loans`: temporary access contracts for call or site visit purposes.
- `call_attempts`: provider call state and outcomes without raw PII.
- `site_visit_proposals`, `site_visits`, `site_visit_confirmations`: proposal, scheduling, proof, and verification trail.
- `broker_locks`: 45-day attribution protection.
- `audit_events`: append-only operational memory.
- `abuse_events`, `risk_notifications`, `trust_score_snapshots`: abuse, risk, and trust score infrastructure.

The important backend control plane is:

```text
Client
-> Edge Function
-> Supabase Auth user
-> backend role/org/permission lookup
-> workflow state check
-> data loan or proof check
-> service-role RPC/table mutation
-> audit event
-> PII-safe response
```

## Lead Lifecycle Synthesis

The lead lifecycle docs agree that one generic CRM status is wrong. The lead must track separate axes:

- `trust_state`: what the workflow has actually proven.
- `sales_state`: buyer journey stage.
- `lead_temperature`: cold, warm, hot intent signal.
- `attribution_state`: broker attribution and brokerage protection state.
- `next_action`: deterministic operational instruction.

Correct examples:

```text
trust_state = loan_active
sales_state = assigned_to_caller
lead_temperature = warm
attribution_state = tracking
next_action = secure_call
```

Blocked transitions remain critical:

- `new -> locked`
- `new -> visit_verified`
- `called -> locked`
- `visit_scheduled -> locked`
- expired data loan -> secure call
- AI recommendation -> direct database mutation
- provider callback without valid signature -> call update

## Human Workflow Synthesis

The human workflow model is stable:

- Broker registers a protected lead.
- Sourcing manager coordinates broker activation and site visit logistics.
- Caller operates only through assigned queues and data loans.
- Buyer communication occurs through Exotel or equivalent bridge.
- Developer receives proof and attribution evidence, not raw customer identity.
- Platform/admin roles govern incidents, risk, disputes, permissions, and payout eligibility.

The daily MVP focus is also clear:

```text
Broker CRM
-> broker activation
-> broker lead intake
-> caller support
-> site visit proof
-> broker performance proof
```

## Broker Protection Synthesis

The broker OS is designed around anti-poaching, lead attribution, and proof-backed commission confidence.

Key broker protections:

- private broker lead pool,
- source-broker linkage,
- duplicate prevention by contact hash,
- site visit proof trail,
- broker review where required,
- 45-day lock after verified visit,
- payout ledger and brokerage status,
- dispute and issue records.

Important limitation: a broker lock is an attribution object, not a payout guarantee. Payout eligibility needs verified visit evidence, commercial state, clean audit trail, and finance governance.

## Caller Workforce Synthesis

Callers are intentionally constrained:

- no lead ownership,
- no unrestricted browsing,
- no export,
- no raw contact visibility,
- no call without active data loan,
- no call without consent/DND checks,
- no outcome mutation without governed workflow.

The long-term caller system should include:

- smart queue assignment,
- due callback resurfacing,
- fallback routing if assigned caller is offline,
- productivity and outcome quality metrics,
- portable professional identity based on verified work.

## Site Visit and Broker Lock Synthesis

Site visit proof is the central real-world trust mechanism.

Required proof chain:

```text
proposal
-> approval
-> scheduled visit
-> start/check-in
-> GPS verification
-> photo proof
-> proof verification
-> broker review where required
-> completed/verified visit
-> broker lock
```

No document supports manual shortcut verification. The strongest documents state that no broker lock should exist without verified visit proof.

## AI Strategy Synthesis

AI is consistently framed as a metadata assistant, not a trust authority.

AI may:

- summarize safe lead metadata,
- recommend next action,
- classify follow-up risk,
- prioritize queues,
- generate scripts or explanations,
- support RAG over safe knowledge bases,
- help with observability and anomaly surfacing.

AI may not:

- read `leads_sensitive` or `brokers_sensitive`,
- decrypt PII,
- approve visits,
- create broker locks,
- approve payouts,
- bypass role checks,
- query raw tables directly,
- become a spam engine.

The implemented AI-safe tool layer is the correct boundary:

- `trust-get-lead-summary`
- `trust-get-broker-lock-status`
- `trust-get-followup-risk`
- `trust-get-site-visit-proof`
- `trust-create-followup`
- `trust-recommend-next-action`

## Trust and Observability Synthesis

The trust observability documents define the missing command center. The dashboard should answer:

```text
Is the trust loop working without leaks, stale work, fake proof, or attribution disputes?
```

Primary metrics:

- lead response time,
- follow-up delay,
- caller outcome rate,
- site visit conversion,
- broker lock creation rate,
- duplicate attempts,
- GPS failures,
- callback failures,
- data loan expiry,
- stuck workflows,
- audit completeness.

The synthesis conclusion is direct: observability should be built before scaling beyond the first controlled pilot.

## Go-To-Market and Content Synthesis

The content strategy is coherent: educate the market on trust failures before selling the product.

Content pillars:

- why brokers lose commission,
- how lead theft happens,
- why informal messaging fails as attribution proof,
- what fake site visits cost developers,
- why CRM is not enough,
- how verified workflows reduce disputes,
- how broker locks protect business.

Content must avoid:

- inflated savings claims,
- legal guarantees,
- invented case studies,
- generic AI CRM positioning,
- claims of zero disputes before pilot proof exists.

## Roadmap Synthesis

The practical roadmap has two tracks.

Track A, immediate field utility:

1. Sourcing manager daily CRM.
2. Broker activation pipeline.
3. Lead from broker.
4. Site visit and walk-in tracker.
5. Broker performance proof.

Track B, enterprise trust layer:

1. Identity and RBAC.
2. Lead vault.
3. Data loans.
4. Secure calls.
5. Site proof.
6. Broker locks.
7. Payout/dispute governance.
8. AI-safe metadata tools.
9. Observability.
10. Multi-tenant scaling.

Three-year roadmap:

- Year 1: telecom completion, closed pilot, first 30 project sites.
- Year 2: commission escrow tracking and portable professional identity.
- Year 3: live developer inventory and expansion across major metros.

Ten-year vision:

- attribution ledger,
- financial integration,
- regulatory-standard trust infrastructure.

## Readiness Synthesis

The corpus has conflicting readiness language.

Older/completion-style documents say:

- production ready,
- v1.0.0 stable,
- commercial traffic authorized,
- launch ready.

Stricter trust-loop documents say:

- official verdict is B partial,
- provider/config blockers remain,
- Exotel handoff is not fully proven,
- callback success path is not proven with a real provider call,
- caller invite/provider secrets are blockers in some environments,
- broker lock/live site proof require complete UAT evidence,
- release gate must exit 0 before Verdict A.

The safe consolidated verdict is:

```text
Current strategy and internal architecture: strong.
Current field-pilot readiness: blocked until live provider and release-gate proof pass.
Current production claim: must be qualified by environment and evidence.
```

## Main Contradictions to Resolve

1. **Production-ready vs provider-blocked**
   Some docs declare launch readiness; stricter operational docs say Exotel/provider evidence is incomplete.

2. **Live deployment evidence vs local proof**
   Several documents treat local UAT and source checks as enough. Trust infrastructure requires live provider and production-environment proof.

3. **Training/demo success vs field proof**
   Training mode and simulated callback success prove workflow shape, not real operational trust.

4. **AI ambition vs AI governance**
   AI-native reports are ambitious, but all safe docs correctly block AI from verification, payout, PII, and direct mutations.

5. **Dashboard completeness vs observability gap**
   Role dashboards exist, but trust observability is still a specification and should be treated as a scaling blocker.

## File-by-File Summary

### `ARCHITECTURE.md`

Defines the short system model: public metadata in `leads_public`, encrypted contact data in `leads_sensitive`, broker upload through Edge Function, secure call through data loan and Exotel, sanitized callback, and site-visit-to-lock skeleton.

### `docs/FUTURETRUST_PRODUCTION_BACKEND_ARCHITECTURE.md`

Defines the production backend control plane: Supabase, RLS, RPCs, Edge Functions, audit, lead lifecycle, queue allocation, data loan governance, broker locks, site visit proof, AI-safe tools, risk, abuse, scaling, multi-tenancy, and deployment strategy.

### `docs/architecture/FUTURETRUST_MASTER_STRATEGY_GOVERNANCE_BLUEPRINT.md`

Defines the market thesis and long-range governance vision: FutureTrust as Real Estate Operational Trust Infrastructure, with PII isolation, attribution protection, workforce coordination, buyer trust, AI governance, rollout strategy, and 3-year/10-year vision.

### `docs/architecture/FUTURETRUST_OPERATIONAL_BLUEPRINT_MASTER.md`

Sets the official operational verdict to B partial. It states internal trust-loop logic is strong but live Exotel/provider callback proof and release-gate success are still required.

### `docs/architecture/FUTURETRUST_LEAD_LIFECYCLE_STATE_MACHINE.md`

The strongest lifecycle spec. It separates trust state, sales state, intent, attribution, booking, brokerage, and next action. It defines allowed and blocked transitions and clearly states AI cannot mutate workflow state.

### `docs/architecture/ROADMAP_BLUEPRINT.md`

Defines the start-to-end roadmap, roles, stack, sprint plan, Edge Function blueprint, frontend screens, security model, compliance model, UAT plan, and release strategy. It warns that roadmap is not deployment evidence.

### `docs/architecture/TARGET_DRIVEN_SALES_ENGINE_BLUEPRINT.md`

Defines the next product improvement: move from CRM-style dashboards to daily targets, smart priorities, role-specific goals, blocked/pending/verified counters, and next-best-action queues.

### `docs/architecture/BACKEND_LOGIC_CONNECTOR_MAP.md`

Maps app surfaces to backend connectors, Edge Functions, RPCs, storage, Exotel, AI placeholders, and critical deterministic flows. It also states WhatsApp outbound is not implemented in current source.

### `docs/architecture/broker-dashboard-data-contract.md`

Defines deterministic broker dashboard read/mutation surfaces. Live mode must use Supabase public tables and Edge Functions; training mode must use `TrainingRuntime`; sensitive tables and contact links are forbidden.

### `docs/architecture/FUTURETRUST_CONTENT_ENGINE_STRATEGY.md`

Defines market education positioning: teach attribution risk, lead theft, fake visits, and why CRM is insufficient. It forbids inflated claims and fake case studies before pilot proof.

### `docs/architecture/TRUST_DECAY_MODEL.md`

Defines conservative trust-score decay from verified audit events. It reduces confidence from inactivity but does not accuse fraud automatically.

### `docs/architecture/TRUST_OBSERVABILITY_DASHBOARD_SPEC.md`

Defines the required trust observability dashboard. It is implementation-pending and should be built before expanding beyond the first controlled pilot.

### `docs/architecture/VERDICT_B_TO_A_TRANSITION_ROADMAP.md`

Defines how to move from Verdict B to Verdict A: configure provider secrets, prove secure call provider handoff, prove valid callback update, complete site proof, create lock live, pass release gate.

### `docs/architecture/ROLE_PERMISSION_MODEL.md`

Defines roles and permissions. Access requires role assignment, active permission template, pilot status, compliance checks, and suspension checks. Caller access remains loan-gated.

### `docs/product/PRACTICAL_MVP_ROADMAP.md`

Defines the immediate field MVP: daily broker CRM, broker activation, lead from broker, site visit tracker, and broker performance proof.

### `docs/product/TRAINING_MODE.md`

Defines training mode as isolated sandbox behavior. Training data must not mutate production.

### `docs/product/USER_TRAINING_PACK.md`

Defines short operating instructions for sourcing managers, brokers/site agents, callers, and platform admins.

### `docs/reports/AI_SAFE_TOOL_LAYER_REPORT.md`

Reports AI-safe metadata tools as locally implemented and statically checked. Deployment and role-based UAT remain necessary before live AI usage.

### `docs/reports/AI_TRUST_EVALS_REPORT.md`

Defines AI safety evaluations: no PII, correct next action, hallucination prevention, broker isolation, role permission, secure call state, and site proof behavior.

### `docs/reports/FUTURETRUST_AI_NATIVE_OS_UPGRADE_REPORT.md`

Summarizes AI-native improvements while preserving the harsh truth that trust-loop provider blockers remain.

### `docs/reports/FUTURETRUST_RAG_ARCHITECTURE_REPORT.md`

Defines safe RAG sources, chunking, metadata, retrieval routes, guardrails, and evaluation plan. Recommends RAG only over safe docs and safe metadata.

### `docs/reports/FUTURETRUST_REAL_ESTATE_OS_DEEP_RESEARCH_AUDIT_2026-05-16.md`

Deep audit of what the system is, what is built, and what remains. Reinforces dataless constitution, broker isolation, lead intake, data loans, secure PSTN bridge, site visit verification, and AI boundaries.

### `docs/reports/FUTURETRUST_TRUST_INFRASTRUCTURE_AUDIT_2026-05-15.md`

Combines PRD and TRD framing: product vision, core users, trust loop, MVP criteria, stack reality, backend architecture, sensitive data boundary, and release gates.

### `docs/reports/FULL_MASTER_RECHECK_REPORT_2026-05-16.md`

Recheck report focused on release gates, trust-loop UAT evidence, AI voice hardening, web dashboard hygiene, pending migration risk, and operational readiness.

### `docs/reports/MASTER_PROJECT_REPORT_v1.0.0.md`

High-level project report that says the foundation is built, constitution is locked, and final launch gates remain around legal/compliance, production initialization, and final UAT.

### `docs/reports/MASTER_PROJECT_STATUS_AUDIT.md`

Audit report separating proven localhost progress from blocked field readiness. Useful for avoiding overclaiming.

### `docs/reports/PHASE_1_TRUST_LOOP_COMPLETION_REPORT.md`

States internal trust loop is close but provider/config blockers remain. Lists AI tools, duplicate prevention, caller assignment, GPS, photo, lock, and audit results.

### `docs/reports/TEN_YEAR_AHEAD_AI_READY_SM_OS_REPORT.md`

Frames the platform as AI-ready because metadata boundaries and role dashboards exist. It still notes live infrastructure validation remains necessary.

### `docs/reports/TRAINING_MODE_PRODUCTION_GATE_REPORT.md`

Reports training mode is gated by build context and release builds should not honor training URL/local storage overrides.

### `docs/reports/TRUST_LOOP_UAT_REPORT.md`

Shows many trust-loop steps passing, but secure call provider acceptance is blocked by Exotel credentials/authorization.

### `docs/runbooks/AI_COPILOT_PRODUCT_SPEC.md`

Defines broker, sourcing manager, caller, and developer copilots. All copilots must use approved metadata tools and must not expose PII or approve protected outcomes.

### `docs/runbooks/CONTROLLED_TRUST_LOOP_PILOT_STATUS.md`

States production DB migrations and broker isolation made progress, but provider secrets, caller invite, follow-up proof, site proof, and broker lock live proof remain blockers in that environment.

### `docs/runbooks/PRACTICAL_MVP_PILOT_PLAN.md`

Defines a 7-day pilot for sourcing operations with success criteria around avoiding WhatsApp/spreadsheet dependence and preserving secure calls/audit trail.

### `docs/runbooks/UAT_TEST_PLAN.md`

Defines critical UAT scenarios: org onboarding, lead sourcing to lock, dispute/abuse enforcement, and financial accuracy.

### `docs/runbooks/DAILY_USAGE_CHECKLIST.md`

Defines a daily operating routine for the pilot: security check, queue review, broker activation, lead intake, site verification, and evening review.

### `docs/runbooks/DATA_CLEANUP_PLAN.md`

Defines post-pilot/pre-launch cleanup targets while preserving launch partners, verified visits, broker locks, and audit history.

### `docs/security/BROKER_LOCK_TRUST_TEST_REPORT.md`

States code is hardened but live broker lock UAT was blocked by incomplete trust loop. Lock creation/countdown/protected credit still need complete site visit UAT.

### `docs/superpowers/plans/2026-05-15-futuretrust-onboarding-hardening.md`

Implementation plan for onboarding hardening: canonical roles, fail-closed caller invite, no raw internal error leakage, and security gates.

### `docs/superpowers/plans/2026-05-16-ai-safe-tool-layer.md`

Implementation plan for the AI-safe tool layer: static gate, six Edge Functions, reports, and verification commands.

## Consolidated Final Verdict

FutureTrust has a coherent and defensible product strategy. The documentation is strongest when it describes the product as governed trust infrastructure rather than CRM. The architecture, state machine, PII isolation, role governance, data loan model, site proof model, broker lock model, and AI boundaries all align.

The project should not use unqualified launch-ready language until the stricter release evidence passes. The correct operating message is:

```text
FutureTrust has a strong internal trust-infrastructure foundation.
It is not fully field-pilot-ready until live provider handoff, valid callback, proof, broker lock, and release-gate evidence pass in production.
```

## Recommended Next Actions

1. Make `docs/reports/FUTURETRUST_MASTER_BLUEPRINT_STRATEGY_SYNTHESIS_2026-05-19.md` the summary entry point for strategy/readiness discussions.
2. Treat `docs/architecture/FUTURETRUST_OPERATIONAL_BLUEPRINT_MASTER.md` and `docs/architecture/VERDICT_B_TO_A_TRANSITION_ROADMAP.md` as readiness truth until the release gate passes.
3. Update or archive older documents that say "production ready" without qualifying provider/config blockers.
4. Complete Exotel production secret setup and callback proof.
5. Run `scripts/release-gate.ps1` and preserve the raw evidence.
6. Prove one complete live lead journey: upload, duplicate check, assignment, data loan, provider call, callback, visit proof, broker lock, audit review.
7. Build the trust observability dashboard before scaling the pilot.
8. Keep AI limited to metadata-only tools until role-based UAT proves no leakage.

