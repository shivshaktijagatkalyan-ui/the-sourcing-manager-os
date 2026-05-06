# Sprint 8: Field UX Polish & Training Layer

Status: **UNLOCKED / ACTIVE**
Version: `v0.8.0-field-ready`

## Objective

Make the Sourcing Manager OS reliable and mistake-proof for field teams (Brokers, Callers, Sourcing Managers) under real-world Indian operational conditions (poor network, GPS failures, Hinglish communication).

## Core Modules

### 1. Role-Safe Dashboards

- **Custom Home Screens**: Tailored views for 10 distinct roles.
- **Metric Isolation**: Only show what is relevant and safe for each role.

### 2. Mistake-Proof Field UX

- **GPS/Camera Guidance**: Step-by-step instructions for permission hurdles.
- **Hinglish Support**: Local language helper text for critical flows (Calling, Verification).
- **Empty States**: Clear guidance when no leads, visits, or reviews are pending.

### 3. Training Mode (Sandbox)

- **Safe Learning**: Simulated leads and visits to train field staff without affecting production ledgers or audit logs.
- **Visual Identity**: Clearly marked sandbox UI to prevent confusion.

### 4. Resilient Operations

- **Error Mapping**: Friendly translations for "Fail-Closed" states (e.g., "Outside Geofence", "DND Blocked").
- **Network Resilience**: Retry handling and connectivity awareness.

## Acceptance Gate

- Broker can track leads and commission proof without training calls.
- Caller understands "Secure Call" logic and DND blocks.
- Sourcing Manager can complete verification even in low-GPS accuracy zones with proper guidance.
- Training mode is strictly isolated from production data.
- Security scanner passes.
