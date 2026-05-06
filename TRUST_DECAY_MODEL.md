# Trust Decay Model

Sprint 4 trust decay is explainable by design. It is not a black-box score.

## Inputs

Only verified audit events may affect decay:

- `site_visit_state_change`
- `broker_lock_created`
- `call_queued`

These are operational events produced by the system, not user claims.

## Stored Evidence

Each decay run stores a row in `public.trust_score_snapshots`:

- `entity_id`
- `entity_type`
- `organization_id`
- `score_before`
- `score_after`
- `score_delta`
- `reason_code`
- `components_json`
- `calculation_run_id`
- `calculated_at`

The `components_json` field records the reason in plain terms, such as:

- last verified event timestamp
- inactive days
- decay rule

## Current Rules

Default threshold: 30 days.

- If a user has no verified activity after the threshold, score decreases by `0.05`.
- If inactivity exceeds three times the threshold, score decreases by `0.15`.
- Scores are clamped between `0.00` and `5.00`.
- Reason code is `inactivity_decay` or `no_verified_activity`.

The model is deliberately conservative. It reduces confidence from inactivity; it does not automatically accuse a user of fraud.

## Execution

Function: `run-trust-decay`

Requirements:

- authenticated user
- active pilot admin
- active pilot organization

Output is limited to `changed_count` and `calculation_run_id`.

## Audit Event

Every run writes:

- `trust_decay_run`

The audit context contains only organization ID, calculation run ID, and changed count.
