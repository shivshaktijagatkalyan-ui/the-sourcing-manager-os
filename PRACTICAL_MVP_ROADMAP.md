# Practical MVP Roadmap - Sourcing Manager Daily Ops

This document defines the **Phase-1 MVP** focus for daily operations at **The Wadhwa Wise City, Panvel**. While the Enterprise Sourcing Manager OS (Sprints 0-10) provides the infrastructure, this roadmap prioritizes the immediate needs of a Sourcing Manager (Vinod) managing a broker network.

---

## Level A: Practical Phase-1 MVP Roadmap

*Immediate utility for daily sourcing manager work.*

### Phase 1 — Sourcing Manager Daily CRM

**Goal**: Help Vinod manage daily broker calling and follow-ups.

- **Broker Management**: Broker list, Add Broker, Broker Category (A/B/C).
- **Activity Tracking**: Follow-up date, Call Notes, Project Pitch Status.
- **Operational Queue**: Today’s Call Queue, Hot Broker List, Inactive Broker List.
- **Reporting**: Basic performance dashboard.

### Phase 2 — Broker Activation Pipeline

**Goal**: Track which brokers are ready to work on Wadhwa Wise City.

- **Stages**: Not Contacted -> First Call Done -> Project Explained -> Inventory Shared -> Offer Shared -> Interested -> Meeting Scheduled -> Lead Expected -> Active Broker -> Dead / Not Interested.
- **Utility**: Identify warm, hot, active, or inactive partners.

### Phase 3 — Lead From Broker

**Goal**: Track leads received from brokers.

- **Lead Data**: Source Broker, Lead Alias, Budget, Area, Project Interest.
- **Actions**: Visit Expected Date, Lead Status, Secure Call (Encrypted).

### Phase 4 — Site Visit / Walk-in Tracker

**Goal**: Track and prove site visits.

- **Statuses**: Scheduled -> Confirmed -> Done -> No Show.
- **Evidence**: GPS proof, Photo proof, Broker Review, Visit Outcome.

### Phase 5 — Broker Performance Proof

**Goal**: Identify the most productive brokers for ROI verification.

- **Metrics**: Broker-wise Leads, Broker-wise Visits, Verified Visits, Broker Approval Rate, Broker Lock.
- **Outcome**: Monthly performance reporting and Top Broker identification.

---

## Level B: Full Enterprise Roadmap

*Strategic expansion to company-scale operations (as defined in ROADMAP_BLUEPRINT.md).*

| Sprint | Goal | Key Feature |
| :--- | :--- | :--- |
| **0-1** | **Data Protection** | Encryption & Secure Call Bridge. |
| **2-5** | **Trust & Scale** | GPS Verification, Disputes, Trust Scoring, Payouts. |
| **6-8** | **Governance & UX** | Compliance, Org Onboarding, Field UX/Training Mode. |
| **9-10** | **Hardening** | Reliability, Security Review, UAT, Launch. |

---

## Strategy: Where to Start & Focus

1. **Focus First on v0.1 (Phase 1-2)**: Build the "Sourcing Manager CRM" and "Activation Pipeline" to organize the existing broker network.
2. **Expand to v0.3 (Phase 3-4)**: Integrate lead tracking and the GPS-verified Site Visit Tracker once the broker network is active.
3. **Graduate to Enterprise (Sprints 6-10)**: Once the pilot at Wadhwa Wise City is proven, roll out Compliance, Multi-Org support, and Finance/Payout modules.

---

## Developer Guidance Summary

- **Database**: Ensure the schema supports the **Broker Activation Pipeline** stages.
- **UI**: Prioritize the **"Today’s Call Queue"** and **"Broker Category"** views in the Flutter app.
- **Logic**: Use the existing `Secure Call` infrastructure even in the CRM phase to maintain the Dataless Constitution.
