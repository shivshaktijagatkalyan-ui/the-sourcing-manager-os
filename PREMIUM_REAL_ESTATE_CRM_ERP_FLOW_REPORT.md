# Premium Real Estate CRM ERP Flow Report

## screens updated
- `flutter_app/lib/screens/sourcing_manager_dashboard.dart`
- `flutter_app/lib/screens/broker_dashboard_screen.dart`
- `flutter_app/lib/screens/broker_detail_screen.dart`
- `flutter_app/lib/screens/broker_followup_queue.dart`
- `flutter_app/lib/screens/caller_lead_queue_screen.dart`
- `flutter_app/lib/screens/add_lead_from_broker.dart`
- `flutter_app/lib/utils/training_runtime.dart`
- `flutter_app/test/widget_test.dart`
- `flutter_app/test/caller_assignment_smoke_test.dart`
- `flutter_app/test/manual_smoke_test_sim.dart`
- `flutter_app/test/outcome_visit_smoke_test.dart`

## dashboard logic
- Role routing remains fail-closed:
  - `sourcing_manager` -> `SourcingManagerDashboard`
  - `broker_owner` / `broker_agent` / `broker` -> `BrokerDashboardScreen`
  - `caller` -> `CallerDashboardScreen`
  - `platform_admin` / `admin` / `developer_admin` -> `SuperAdminDashboard`
  - unknown -> `AccessRestrictedScreen`
- Drawer remains role-filtered from `flutter_app/lib/main.dart`.
- Premium dark ERP shell remains consistent across admin, sourcing manager, broker, and caller surfaces.

## broker flow
- Broker dashboard now exposes:
  - connected sourcing managers
  - live projects
  - lead status
  - data-loan / call-permission summary
  - verified performance summary
  - recent activity
- Broker detail now supports deterministic training-mode behavior for:
  - activation stage updates
  - secure broker call simulation
  - activity logging
  - follow-up creation
  - caller assignment
  - site-visit scheduling from interested leads
- No contact data is shown in broker views.

## SM flow
- Sourcing manager dashboard remains the command center for:
  - broker follow-ups
  - activation pipeline
  - lead intake
  - caller assignment visibility
  - interested lead action queue
  - site-visit tracker
  - broker performance summary
- Hinglish helper copy remains short and operational.
- Follow-up queue is now wired into shared training runtime instead of static demo rows.

## caller flow
- Caller dashboard stays limited to assigned leads only.
- Caller lead queue now uses the premium shell and makes the workflow explicit:
  - Secure Call
  - outcome update
  - status badge visibility
  - broker/project context without exposing phone data
- Outcome changes continue to flow through the protected workflow path in live mode and shared training runtime in demo mode.

## admin flow
- Super Admin panel remains a safe control room with counts, project/org summaries, risk alerts, and audit summaries only.
- No sensitive contact data is surfaced.
- Admin quick actions continue to route to existing protected or safe admin screens.

## follow-up automation
- Training runtime now supports:
  - broker follow-up creation
  - broker follow-up completion
  - broker activity logging
  - activation stage updates
- Follow-up queue reads shared runtime data in training mode, so broker follow-up actions now persist across screens and refresh correctly.
- Live mode still relies on Edge Functions / Supabase persistence.

## input/output logic
- Add Lead From Broker:
  - live mode uses `lead-from-broker`
  - training mode now supports broker selection and persistent lead creation
  - phone input is still wiped from controller state immediately after submit
- Assign Lead to Caller:
  - live mode uses `manage-caller-workflow`
  - training mode persists assignment and auto data-loan creation via shared runtime
- Caller Outcome Update:
  - live mode uses `manage-caller-workflow`
  - training mode updates lead status, call attempts, broker activity, and audit trail
- Schedule Site Visit:
  - live mode uses `lead-from-broker`
  - training mode persists `source_broker_id`, `source_lead_id`, and scheduled visit state

## security scan result
- `python scripts/security-check.py`: PASS
- No `leads_sensitive` query found in `flutter_app/lib`
- No `brokers_sensitive` query found in `flutter_app/lib`
- No `wa.me` links found in `flutter_app/lib`
- No `tel:` links found in `flutter_app/lib`
- No phone exposure introduced in the updated screens

## build result
- `flutter analyze`: PASS
- `flutter build web --release`: PASS
- `npm run build`: PASS
- `npx tsc --noEmit`: FAIL at repo root because no root TypeScript toolchain is installed; this remains consistent with the repository guidance that root TypeScript typechecking is not applicable for this Flutter / Supabase hybrid

## remaining issues
- Live Exotel verification is still manual-required.
- Live GPS / camera / broker-lock verification is still manual-required.
- APK generation is still blocked separately by missing Android SDK and missing production Flutter build defines.
- `flutter_app/android/` is present as an untracked workspace artifact and was not used for this web-flow pass.
