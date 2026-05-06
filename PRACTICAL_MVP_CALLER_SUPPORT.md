# Practical MVP Caller Support — Broker Lead Workflow

**Objective**: Enable secure, audited calling support for broker-sourced leads without exposing sensitive contact data to the calling team.

---

## 1. The Workflow: Vinod (SM) -> Rahul (Caller)

| Actor | Action | System Enforcement |
| :--- | :--- | :--- |
| **Vinod (SM)** | Assigns Lead to Caller | Trigger creates 24hr `data_loan`; RLS grants lead visibility to Caller. |
| **Rahul (Caller)** | Views Lead Queue | Sees only Alias, Area, Budget, and Source Broker info. No phone visible. |
| **Rahul (Caller)** | Clicks "Secure Call" | Edge Function validates loan, bridges call via Exotel, wipes PII immediately. |
| **Rahul (Caller)** | Updates Outcome | `update_lead_call_outcome` RPC updates status and logs broker activity. |
| **System** | Performance Rollup | Broker profile updates with "Calls Attempted" and "Interested Leads." |

---

## 2. Security Configuration

### **Dataless Constitution Compliance**

- **No PII in UI**: Caller screens use only `lead_alias` and `broker_alias`.
- **Automatic Data Loans**: Access is time-bound (default 24h) and revoked automatically upon expiration or status change.
- **Secure RPC**: The `update_lead_call_outcome` function is `SECURITY DEFINER`, allowing the system to update sensitive logs while the caller stays within their RLS sandbox.

### **Audit Trails**

- Every call attempt is recorded in `call_attempts`.
- Every outcome shift is recorded in `broker_activity_logs` under the source broker's profile.

---

## 3. How to Use (For Vinod)

1. **Open Broker Profile**: Select a broker (e.g., Jitu Gupta / JSN Enterprise).
2. **Add Leads**: Input leads provided by the broker.
3. **Assign Caller**: Click the "Add Person" icon next to a lead and select an available caller.
4. **Monitor Performance**: Track "Interested Leads" and "Conversion Rate" directly on the broker's profile.

---

## 4. Technical Components

- **Migration**: `20240516000000_caller_workflow_support.sql`
- **Edge Function**: `manage-caller-workflow`
- **Flutter Screens**:
  - `CallerDashboardScreen` (Dashboard for callers)
  - `CallerLeadQueueScreen` (Actionable queue for callers)
