# MCP and Connectors Security Policy

Date: 2026-05-23
Scope: FutureTrust Real Estate OS, Supabase Edge Functions, Flutter PWA, web dashboard, Spec Kit workflows, and agent tooling.

This policy governs any use of OpenAI connectors, remote MCP servers, local MCP servers, and agent skills against the FutureTrust workspace.

## Operating Position

FutureTrust is a production-critical WhatsApp and real estate lead-trust system. MCP tools and connectors are optional developer accelerators, not a replacement for the platform control plane.

The source of truth remains:

- Supabase Postgres for platform state.
- Supabase Edge Functions for protected mutations.
- Exotel and WhatsApp provider flows for communications.
- Audit tables for proof and governance.
- Spec Kit artifacts for requirements, plans, and task traceability.

Do not move Salesforce, Exotel, Supabase service-role, WhatsApp, broker lock, data loan, or lead state-machine authority into arbitrary MCP tools.

## Allowed Integration Classes

Use MCP/connectors only when the data boundary is clear and the tool is trusted:

- Official OpenAI connectors for bounded document, calendar, email, or drive workflows.
- Official vendor MCP servers when the server is operated by the service owner.
- Internal MCP servers exposed through Secure MCP Tunnel when they need private network access.
- Design tools such as Stitch, Figma, or Canva only with sanitized UI prompts and no production PII.
- GitHub MCP or connector workflows only for approved issue, PR, and repository operations.

Do not use third-party aggregator MCP servers for production data unless they pass a written security review.

## Default Approval Rules

Set conservative defaults for Responses API MCP tools:

- `require_approval: "always"` for tools that can read sensitive data, transmit repository context, or mutate external systems.
- `allowed_tools` must be set when the server exposes more than the exact tools needed.
- `defer_loading: true` should be used for large MCP servers unless immediate tool discovery is required.
- `require_approval: "never"` is allowed only for reviewed, read-only, low-risk tools that receive no secrets, PII, or proprietary business data.

Approval is mandatory for:

- Sending contact data, lead metadata, call outcomes, site visit evidence, or broker attribution outside the platform.
- Creating, updating, deleting, or publishing external records.
- Accessing Gmail, Drive, Calendar, SharePoint, Teams, Dropbox, Salesforce, GitHub, or any CRM system with business data.
- Any workflow that could message a customer, caller, broker, sourcing manager, or developer.

## Data That Must Not Leave FutureTrust

Never send these fields to a remote MCP server, connector, design generator, or skill:

- Buyer phone numbers, WhatsApp identifiers, emails, or names.
- Broker/caller/sourcing-manager private profile data.
- Lead PII, encrypted lead payloads, hashes, vault keys, salts, or duplicate-detection material.
- Supabase service role keys, JWT secrets, database URLs, vault secrets, or anon keys from production environments.
- Exotel API keys, tokens, SIDs, caller IDs, webhook secrets, or callback payloads containing contact details.
- Google OAuth client secrets, connector access tokens, refresh tokens, or API keys.
- Salesforce client secrets, refresh tokens, access tokens, signing secrets, or raw webhook payloads.
- Raw audit trails that include identifiers not already approved for public metadata views.

If a prompt needs business context, use sanitized metadata only.

## Secret Handling

Connector and MCP credentials must be treated as production secrets:

- Do not commit tokens, API keys, OAuth access tokens, refresh tokens, or MCP auth headers.
- Do not store secrets in `docs/`, `specs/`, `scratch/`, generated reports, screenshots, or walkthrough logs.
- Use environment variables for local developer tooling.
- Use Supabase Vault for production provider credentials.
- Pass MCP `authorization` values per request; do not persist them in source code.
- Rotate any key that has appeared in chat, terminal output, logs, or repository history.

Before staging, search for accidental secrets:

```powershell
rg --no-ignore --hidden --line-number "sk-|xoxb-|ya29\\.|AQ\\.|Bearer |service_role|refresh_token|client_secret|api[_-]?key" .
npm run security
node scripts/ai-safe-tool-check.mjs
```

## Remote MCP Review Checklist

Complete this checklist before adding a remote MCP server to agent workflows:

- Server owner and domain are verified.
- Transport is HTTPS Streamable HTTP or HTTP/SSE.
- Authentication scheme is documented.
- Requested OAuth scopes are minimal and justified.
- Tool list is reviewed and restricted with `allowed_tools`.
- Write actions require approval.
- Data retention and data residency are documented.
- Prompt-injection risk is evaluated for all tool outputs.
- Tool outputs are not embedded as trusted URLs or media without domain validation.
- PII and secrets are excluded from prompts, tool arguments, logs, and generated artifacts.
- Operational rollback is clear, including token revocation and config removal.

## Local Skills Policy

Skills are privileged instructions and files. Treat each skill bundle as untrusted until inspected.

- Read `SKILL.md` before using a new local or uploaded skill.
- Do not expose an open skill catalog to end users.
- Map each approved skill to a bounded product workflow.
- Require approval before a skill performs external writes, deployment, messaging, or data export.
- Keep skill-generated scratch files ignored unless they become reviewed production artifacts.
- Do not mount skills that request secrets or broad filesystem/network access without review.

## Audit Expectations

For approved MCP and connector usage, log only PII-safe metadata:

- Tool/server label.
- Tool name.
- Initiating user or service account.
- Purpose or workflow ID.
- Approval decision.
- Timestamp.
- Result status.

Do not log raw OAuth tokens, raw prompts, raw provider responses, buyer contact fields, or encrypted payloads. Use `audit_events`, `risk_notifications`, or project reports for governance evidence only when the payload is already sanitized.

## FutureTrust-Specific Boundaries

Approved examples:

- Google Drive/Docs connectors for sanitized documentation workflows.
- GitHub MCP for approved issue and PR tracking.
- Stitch/Figma/Canva design generation using sanitized screenshots or abstract UI prompts.
- Read-only project documentation retrieval when no production data is attached.

Not approved without a separate architecture review:

- Direct Salesforce record mutation through an arbitrary MCP server.
- Direct Supabase database mutation through MCP.
- WhatsApp or Exotel sends through MCP.
- Broker lock, data loan, duplicate detection, or lead state transitions through MCP.
- Sending raw lead/contact data to design, analytics, or general-purpose agent tools.

## Safe Responses API Pattern

Use narrow tool access by default:

```javascript
const response = await client.responses.create({
  model: "gpt-5",
  tools: [
    {
      type: "mcp",
      server_label: "trusted_docs",
      server_url: process.env.TRUSTED_DOCS_MCP_URL,
      authorization: process.env.TRUSTED_DOCS_MCP_TOKEN,
      require_approval: "always",
      allowed_tools: ["search", "fetch"],
      defer_loading: true,
    },
  ],
  input: "Find the sanitized release checklist for the current feature.",
});
```

For connectors, keep OAuth scopes minimal and pass the access token at request time. Do not write connector tokens to repository files.

## Incident Response

If a token or sensitive payload is exposed:

1. Revoke or rotate the credential immediately.
2. Remove local copies from ignored scratch files, logs, screenshots, and generated reports.
3. Search the repository and ignored files for the exposed pattern.
4. Run `npm run security` and `node scripts/ai-safe-tool-check.mjs`.
5. Update the relevant audit or incident report with sanitized facts.
6. Reissue credentials only after the source of exposure is fixed.

