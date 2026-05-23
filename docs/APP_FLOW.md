# Application Flow

Primary flow:

1. User authenticates and resolves role.
2. Broker uploads lead through protected ingestion.
3. Duplicate detection blocks repeated restricted data.
4. Sourcing manager sees metadata and allocates data loans.
5. Caller uses secure bridge actions through Edge Functions.
6. Sourcing manager proposes, starts, and verifies site visits.
7. GPS and proof metadata complete the visit.
8. Verified visits create or extend broker locks.
9. Audit events provide proof for operations and governance.

Canonical references:

- [FutureTrust lead lifecycle state machine](architecture/FUTURETRUST_LEAD_LIFECYCLE_STATE_MACHINE.md)
- [Operational blueprint](architecture/FUTURETRUST_OPERATIONAL_BLUEPRINT_MASTER.md)
- [Trust loop UAT report](reports/TRUST_LOOP_UAT_REPORT.md)
