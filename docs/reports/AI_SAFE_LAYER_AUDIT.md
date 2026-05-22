# AI SAFE LAYER AUDIT

Generated: 2026-05-22
Verdict: B. PARTIAL - BLOCKERS REMAIN

## What was tested
- Static AI tool scan, UAT AI metadata calls, follow-up creation, and sampled proof retrieval.

## What passed
- `npm run ai:tools:check` passed.
- UAT sampled `trust-get-lead-summary`, `trust-get-broker-lock-status`, `trust-get-followup-risk`, `trust-recommend-next-action`, `trust-create-followup`, and `trust-get-site-visit-proof`.
- Sampled AI tools returned metadata-only responses without raw contact output.

## What failed
- AI tool safety is only proven for sampled paths. The whole app still has service-role Next API routes that could expose unsafe lead data outside the AI layer.
- If source workflow state is corrupted by callback, data-loan, or proof bugs, AI recommendations may faithfully summarize bad state.

## What is dangerous
- AI safety cannot compensate for direct service-role APIs.
- `trust-create-followup` can create operational work items; it must remain metadata-only and never approve trust outcomes.

## What is unproven
- Prompt-injection resistance across every free-text field.
- Notes leakage across all future AI tools.
- Whether AI tool queries remain org-scoped after migration drift is resolved.

## Exact blocker
- No AI-specific blocker found in sampled tools, but system-level blockers remain: service-role APIs and state-machine weaknesses.

## Exact recommended fix
- Keep AI tools read-only or recommendation-only except tightly scoped follow-up creation.
- Add regression tests that seed phone-like notes and ensure AI tools redact them.
- Add org isolation tests for every AI tool.

## Harsh-truth verdict
The sampled AI layer is comparatively disciplined, but it cannot be declared production-safe while surrounding APIs and workflow state remain blocked.

