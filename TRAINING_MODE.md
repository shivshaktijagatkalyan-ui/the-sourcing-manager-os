# Training Mode & Sandbox Guide (Sprint 8)

Training Mode allows new field users to practice workflows without risking production data integrity.

## 1. Entering Training Mode

- Open the side drawer.
- Toggle **"Training Mode"** ON.
- A yellow amber border and "TRAINING MODE" banner will appear.

## 2. What is Isolated?

| Feature | Training Mode Behavior | Production Impact |
| :--- | :--- | :--- |
| **Leads** | Shows hardcoded "Lead-Alpha", "Lead-Beta". | NONE |
| **Calls** | UI walkthrough only. No Exotel trigger. | NONE |
| **Site Visits** | Simulated GPS/Photo flow. | NONE |
| **Audit Logs** | Not recorded. | NONE |
| **Payout Ledger** | Not recorded. | NONE |

## 3. Training Curriculum for Brokers

1. **Lead Tracking**: View the queue and identify "Active Loan" status.
2. **Secure Calling**: Walk through the PSTN bridge logic.
3. **Visit Submission**: Practice submitting GPS evidence while simulating "Outside Geofence" errors.
4. **Commission Locks**: Review how the 45-day protection appears in the ledger.

## 4. Safety Guarantee

Training Mode is a UI-level overlay. It does not store credentials or session data into production tables.
