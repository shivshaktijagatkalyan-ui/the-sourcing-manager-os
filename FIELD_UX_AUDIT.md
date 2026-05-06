# Field UX Audit Checklist (Sprint 8)

This audit ensures the Sourcing Manager OS is usable under real-world field conditions in India.

## 1. Role-Based Clarity

- [x] **Platform Admin**: Sees global health and org onboarding.
- [x] **Broker Owner**: Sees payout ledger and team performance.
- [x] **Caller**: Only sees Secure Call queue. No phone numbers visible.
- [x] **Sourcing Manager**: Sees verification tasks with GPS status.

## 2. Field Resilience

- [x] **Hinglish Support**: Critical flows (Call, Visit, Lock) have local language guidance.
- [x] **Network Awareness**: Connectivity manager warns user if internet is weak.
- [x] **GPS Guidance**: Step-by-step instructions for permission hurdles and low accuracy.
- [x] **Fail-Closed Messages**: Users understand *why* an action is blocked (e.g., "Outside Geofence").

## 3. Safe Practice

- [x] **Training Mode**: Sandbox overlay is clearly visible.
- [x] **Data Isolation**: Training actions do not touch production audit or payout ledgers.
- [x] **Demo Data**: All training leads use safe aliases and no real phone numbers.

## 4. UI Polish

- [x] **Empty States**: Tasks lists show guidance when empty.
- [x] **Loading States**: All Edge Function calls show active progress indicators.
- [x] **Success Confirmation**: Verification and reviews show high-contrast success icons.
