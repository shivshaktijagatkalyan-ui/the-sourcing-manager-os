# PREMIUM UI UX UPGRADE REPORT

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Status: DESIGN SPECIFICATION - IMPLEMENTATION PENDING

## Design Mandate

FutureTrust should feel like an operational trust console, not a generic CRM. The UI must make the next protected action obvious, show where work is stuck, and keep attribution status visible without exposing contact data.

The interface should be premium and dark, but the priority is field usability. A broker using one hand on a phone should understand the next action in under five seconds.

## Visual System

Color roles:

| Role | Color | Use |
| --- | --- | --- |
| Background | `#09090B` | App shell and main canvas. |
| Surface | `#18181B` | Cards and grouped panels. |
| Elevated surface | `#27272A` | Bottom sheets and dialogs. |
| Trust gold | `#D4A843` | Broker locks and protected attribution. |
| Verified green | `#22C55E` | GPS verified, visit verified, lock active. |
| Blocked red | `#EF4444` | Failed gates, blocked workflows, high risk. |
| Scheduled blue | `#3B82F6` | Scheduled calls, visits, queued work. |
| Warning amber | `#F59E0B` | At-risk but recoverable workflow. |
| Primary text | `#F8FAFC` | Main labels. |
| Secondary text | `#A1A1AA` | Metadata and timestamps. |

Typography:

| Token | Size | Use |
| --- | ---: | --- |
| Screen title | 24 | Dashboard and screen heading. |
| Section title | 18 | Panel heading. |
| Card title | 16 | Lead alias and workflow state. |
| Body | 14 | Operational detail. |
| Meta | 12 | Timestamp, area, budget, proof notes. |

No viewport-scaled typography. No tiny status text. No dense CRM tables on mobile.

## Screen Principles

Every screen must answer:

- What needs action now?
- Which lead is protected?
- Which visit is verified?
- Which workflow is blocked?
- Which deal is at risk?
- What should I do next?

## Broker Dashboard

Primary question: what needs action now?

Required sections:

| Section | Purpose |
| --- | --- |
| Broker identity card | Broker ID, trust score, active status. |
| Protected work strip | Active locks, expiring locks, verified visits. |
| Action queue | Overdue follow-ups, visit-ready leads, lock actions. |
| Lead vault | Lead alias list with status and next action. |
| Brokerage status | Eligible, pending proof, disputed, paid. |
| Growth tips | Operational coaching only; no generic motivational content. |

Primary actions:

- Upload lead.
- Create follow-up.
- View lock.
- Propose site visit.

## Sourcing Manager Dashboard

Primary question: which workflow is stuck?

Required sections:

| Section | Purpose |
| --- | --- |
| Today's follow-ups | Leads that require action now. |
| Broker network | Active brokers and protected output. |
| Hot brokers | Brokers producing verified work. |
| Lead assignment | Unassigned or stale leads. |
| Site visits | Scheduled, started, proof pending, verified. |
| Broker locks | Active, expiring, blocked. |
| Performance | Conversion and trust health. |

Primary actions:

- Assign caller.
- Schedule visit.
- Verify proof.
- Resolve blocker.

## Caller Dashboard

Primary question: which protected call should I make next?

Required sections:

| Section | Purpose |
| --- | --- |
| Assigned calls | Ordered secure-call queue. |
| Pending calls | Data loans not yet used. |
| Call later | Follow-ups due later. |
| Interested leads | Leads requiring SM action. |
| Outcome capture | Closed enum outcome buttons. |

The secure call button must never reveal contact data or provider routing metadata.

## Site Visit Verification

Primary question: is proof complete?

Required proof states:

- Scheduled.
- Started.
- GPS verified.
- Photo uploaded.
- Visit verified.
- Lock created.

The UI must show why a visit cannot be verified. It should not hide failure behind generic error text.

## Interaction Rules

- Use bottom sheets for secondary mobile actions.
- Use one primary CTA per card.
- Keep action buttons large enough for field use.
- Do not use nested cards.
- Do not show decorative dashboards when a queue is needed.
- Do not show raw IDs unless necessary for support/debug.
- Show lead aliases, not identities.
- Show workflow states, not contact details.

## Harsh-Truth Verdict

A premium dark theme does not create trust. The UI creates trust only when it reduces field mistakes and makes protected work visible. Implement this after the core trust loop is live-proven; otherwise the UI will polish an unfinished operating system.
