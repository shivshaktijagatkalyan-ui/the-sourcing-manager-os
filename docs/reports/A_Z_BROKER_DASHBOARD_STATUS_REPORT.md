# A-Z Broker Dashboard Status Report

## A. Product We Are Building

The Sourcing Manager OS is being built as a premium Indian real estate sourcing sales engine for small and local brokers.

The current focus is the Broker Dashboard / Broker Business Vault for brokers like:

- Broker: Jitu Gupta
- Company: JSN Enterprise
- Area: Mira Road
- Project: The Wadhwa Wise City, Panvel
- Connected Sourcing Manager: Vinod Gupta

This is not a generic CRM, contact book, lead marketplace, or WhatsApp dashboard. It is a secure business vault where broker data stays protected and broker performance becomes visible.

## B. Core Principle

The Dataless Constitution is still active.

The system must not show:

- customer number
- broker number
- masked number
- last digits
- WhatsApp links
- browser call links
- contact export
- sensitive table data in Flutter

All contact-sensitive work must stay behind Edge Functions.

## C. What Is Done

- Premium Broker Dashboard screen created.
- Broker Business Vault UI created.
- Broker ID style identity card created.
- Broker-safe KPI cards created.
- Broker lead cards created with safe metadata only.
- Lead quality and pipeline labels added.
- Data quality labels added.
- Site visit, broker lock, booking, and brokerage status areas added.
- Training/demo broker data added.
- Secure action buttons added without exposing contact data.
- Login screen updated with required controls.
- Create Account flow added.
- Choose Role screen added.
- Broker signup form added.
- Broker signup calls Supabase Auth `signUp`.
- Broker signup calls `complete-onboarding`.
- Role routing fixed for broker users.
- Access Restricted screen avoided for valid broker roles.
- Training Mode can show demo Sourcing Manager dashboard.
- Local mock broker mode can show Broker Dashboard without login.

## D. What Is Working On Localhost Now

Broker Dashboard can be opened directly in local mock broker mode:

`http://localhost:5050/?mockRole=broker_owner`

This bypasses real login and shows the Broker Dashboard immediately for visual review.

## E. Login / Signup Work Done

- If no user session exists, app shows LoginScreen.
- LoginScreen has Email, Password, Sign In, Create Account, Request Access, and Training Mode.
- Create Account opens role selection.
- Broker role opens Broker Signup form.
- Broker form collects full name, company name, area, city, email, password, confirm password.
- Broker signup sends `selected_role: broker_owner`.
- Password is not stored in app data.
- Flutter does not use service role key.

## F. Backend Onboarding Work Done

`complete-onboarding` was updated to:

- authenticate JWT user
- accept `selected_role`
- allow broker self-signup in pilot mode
- create/attach organization workspace
- create safe user profile
- create broker public profile
- create active broker role assignment in pilot mode
- create safe audit event `user_onboarded`
- return safe response only

## G. Broker Dashboard Safe Data

The dashboard shows safe broker/business metadata:

- broker code
- broker name
- company name
- area
- city
- verified status
- connected manager
- live projects
- performance rank
- trust score
- lead quality
- visit status
- broker lock status
- booking stage
- brokerage status

It does not show contact-sensitive data.

## H. Edge Functions Added / Updated

Updated:

- `complete-onboarding`

Created / improved earlier:

- `broker-vault-workflow`
- `broker-self-secure-call`
- `data-loan-workflow`

These are intended to keep protected actions behind server-side checks.

## I. Verification Done

Passed:

- `flutter test test\broker_signup_login_fix_test.dart`
- `flutter test test\auth_role_flow_test.dart`
- `flutter test test\broker_vault_constitution_test.dart`
- `python scripts\security-check.py`
- `flutter analyze`
- `flutter build web --release`
- `flutter build apk --release`

Local web server is running on:

- `http://127.0.0.1:5050`

Broker mock dashboard URL:

- `http://127.0.0.1:5050/?mockRole=broker_owner`

## J. What Remains

Real broker login/signup is not fully field-ready until these are done:

1. Deploy pending Supabase migrations.
2. Deploy updated `complete-onboarding` Edge Function.
3. Confirm Supabase Auth email confirmation setting for pilot mode.
4. Test real Jitu Gupta broker signup against live Supabase.
5. Confirm broker role assignment row is active after signup.
6. Confirm `brokers_public` row is created for Jitu Gupta.
7. Confirm app routes real broker session to BrokerDashboardScreen.
8. Confirm AccessRestrictedScreen does not show for real broker.
9. Seed or connect The Wadhwa Wise City project if not already present.
10. Connect real sourcing manager Vinod Gupta if required.
11. Connect caller Rahul / calling team if required.
12. Run live secure call flow only through Edge Function.
13. Run full manual APK smoke test after deployment.

## K. Current Blocker

The Broker Dashboard can be shown locally through mock broker mode, but real broker account creation depends on deployed Supabase backend changes.

Until the migrations and `complete-onboarding` function are deployed, real signup may still fail or may not create the broker ID in the live database.

## L. Final Status

Current status:

`PARTIAL - BROKER DASHBOARD READY FOR LOCAL REVIEW, REAL SIGNUP NEEDS BACKEND DEPLOYMENT`
