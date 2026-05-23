# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`

**Created**: [DATE]

**Status**: Draft

**Input**: User description: "$ARGUMENTS"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more prioritized user stories as needed. Each story must be independently
testable and must preserve the deterministic trust flow.]

### Edge Cases

- [Boundary condition or fail-closed scenario]
- [Provider, auth, environment, or persistence failure scenario]

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST [specific testable capability]
- **FR-002**: System MUST [specific testable capability]

### Security, Privacy, and Audit Requirements

- **SR-001**: Protected actions MUST execute through Supabase Edge Functions.
- **SR-002**: Restricted contact data MUST remain encrypted/hashed and never be
  returned to frontend clients or AI tools.
- **SR-003**: Protected state changes MUST write PII-safe audit events.
- **SR-004**: Invalid auth, organization status, role status, provider callback,
  GPS proof, photo proof, or data loan state MUST fail closed.

### Key Entities *(include if feature involves data)*

- **[Entity]**: [What it represents, key attributes, and relationships]

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: [Measurable outcome without implementation details]
- **SC-002**: [Measurable outcome without implementation details]

## Assumptions

- [Assumption about scope or environment]
- [Dependency on an existing system/service]

## Verification Expectations *(mandatory)*

- `npm run build`
- `npx tsc --noEmit`
- `python scripts/security-check.py`
- `node scripts/security-check.mjs`
- `node scripts/check-function-drift.mjs`
- Flutter analysis when frontend code changes.
- Supabase migration dry-run when migrations change.
- Live UAT only when explicitly approved because it can mutate the linked remote
  Supabase project.
