# Research: Complete Trust Platform

## Decision: Treat the project as brownfield hardening, not greenfield rebuild

**Rationale**: The repo already contains production Flutter screens, Supabase
migrations, Edge Functions, security checks, drift checks, UAT scripts, release
reports, and runbooks. Rebuilding would risk breaking verified WhatsApp/Exotel
and Supabase persistence flows.

**Alternatives considered**:

- Full architecture redesign: rejected because the constitution forbids redesign
  unless explicitly requested.
- New app scaffold: rejected because it would duplicate source of truth and
  bypass existing verified flows.

## Decision: Use additive, idempotent migrations for missing required tables

**Rationale**: Required entities such as `caller_profiles`,
`sourcing_managers_public`, `developer_lead_bank`, and `site_visit_proofs` can
be added safely without rewriting existing migrations or remote deployment
history.

**Alternatives considered**:

- Rename existing confirmation/proof tables: rejected because it could break
  deployed Edge Functions.
- Combine migrations: rejected because Supabase deployment history should not be
  rewritten casually.

## Decision: Keep protected actions in Supabase Edge Functions

**Rationale**: Lead upload, data loans, secure calls, provider callbacks, site
visit proof, broker locks, onboarding, and admin actions require service-role
access, stable error codes, permission checks, and PII-safe responses.

**Alternatives considered**:

- Direct frontend table writes: rejected because it violates privacy and
  fail-closed rules.
- Generic AI action layer: rejected because deterministic trust flow must govern
  protected transitions.

## Decision: Add frontend structural entrypoints without forcing a rewrite

**Rationale**: The target architecture expects auth, service, model, widget, and
state files. Existing screens can continue to work while lightweight entrypoints
give future work a stable place to grow.

**Alternatives considered**:

- Refactor large screens immediately: rejected because it increases blast radius.
- Add unused complex abstractions: rejected because minimal safe patches are
  preferred.

## Decision: Keep UAT scripts explicit about mutating linked remote data

**Rationale**: `scripts/uat-trust-loop.mjs` validates the full business chain but
creates or updates records in the linked Supabase project. Static/local gates
should run first, and live UAT should be a deliberate operator action.

**Alternatives considered**:

- Always run live UAT automatically: rejected because it can alter production or
  linked pilot data.
- Skip UAT entirely: rejected because the full trust loop is the strongest
  system-level proof.
