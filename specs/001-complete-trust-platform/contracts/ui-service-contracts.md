# Contract: Flutter UI, Models, Services, and State

Flutter screens render metadata and invoke protected actions. They do not own
business truth, decrypt sensitive values, or write protected state directly.

## Auth and Role

- `flutter_app/lib/auth/auth_service.dart` exports the shared auth service.
- `flutter_app/lib/auth/role_resolver.dart` exports deterministic role
  resolution.
- Role resolver returns explicit inactive states such as pending, suspended,
  unknown, or anonymous.

## Services

- `EdgeFunctionClient` invokes Edge Functions and normalizes map responses.
- `LeadService` owns lead upload and lead-from-broker client calls.
- `CallerService` owns secure call and caller workflow client calls.
- `BrokerService` owns broker vault and site visit proposal calls.
- `SiteVisitService` owns GPS and proof verification calls.
- `AdminService` owns dashboard and onboarding calls.

## Models

Models are metadata-only:

- `Lead`
- `Broker`
- `Caller`
- `SiteVisit`
- `BrokerLock`
- `DashboardSnapshot`

No model may include restricted contact fields, masked contact fragments, or
direct outreach links.

## Widgets

Widgets are reusable metadata renderers:

- `LeadCard`
- `FollowupCard`
- `BrokerLockCard`
- `SiteVisitCard`
- `TrustBadge`

Widgets must not render restricted contact data or instructions for bypassing
protected actions.

## State Machine

`LeadStateMachine` defines deterministic transitions for the app surface. The
database and Edge Functions remain authoritative, but UI code may use this state
machine to prevent impossible client-side transitions before submitting protected
actions.
