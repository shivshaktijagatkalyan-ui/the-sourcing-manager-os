# Role Permission Model

Sprint 7 uses explicit role assignments and permission templates. Roles alone do not grant access unless an active permission template is attached and the user passes pilot, compliance, and suspension checks.

## Roles

- `platform_admin`
- `developer_admin`
- `broker_owner`
- `broker_agent`
- `sourcing_manager`
- `caller`
- `compliance_admin`
- `dispute_admin`
- `finance_admin`
- `read_only_auditor`

## Permissions

- `can_upload_leads`
- `can_grant_data_loans`
- `can_call_leads`
- `can_create_site_visits`
- `can_verify_site_visits`
- `can_review_site_visits`
- `can_view_disputes`
- `can_resolve_disputes`
- `can_view_payouts`
- `can_generate_statements`
- `can_view_compliance_reports`
- `can_manage_org_users`
- `can_pause_org`
- `can_suspend_user`
- `can_view_risk_dashboard`

## Default Role Seeds

- `platform_admin`: all permissions
- `developer_admin`: org user management, pause/suspend, risk, compliance, dispute visibility
- `broker_owner`: upload leads, grant loans, review visits, disputes, payouts, statements, org users
- `broker_agent`: upload leads, view payouts
- `sourcing_manager`: create and verify site visits
- `caller`: call leads through secure PSTN bridge only
- `compliance_admin`: compliance and dispute visibility
- `dispute_admin`: view and resolve disputes
- `finance_admin`: payouts and statements
- `read_only_auditor`: read-only disputes, payouts, compliance, risk

Developer/admin roles do not receive sensitive broker lead data access by default. Caller access remains loan-gated and never exposes customer contact data.
