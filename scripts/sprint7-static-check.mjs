import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const requiredTables = [
  'organization_profiles',
  'user_profiles',
  'organization_invites',
  'role_assignments',
  'permission_templates',
  'onboarding_requests',
  'onboarding_audit_events',
  'user_activation_checks',
  'org_activation_checks',
];

const requiredRoles = [
  'platform_admin',
  'developer_admin',
  'broker_owner',
  'broker_agent',
  'sourcing_manager',
  'caller',
  'compliance_admin',
  'dispute_admin',
  'finance_admin',
  'read_only_auditor',
];

const requiredPermissions = [
  'can_upload_leads',
  'can_grant_data_loans',
  'can_call_leads',
  'can_create_site_visits',
  'can_verify_site_visits',
  'can_review_site_visits',
  'can_view_disputes',
  'can_resolve_disputes',
  'can_view_payouts',
  'can_generate_statements',
  'can_view_compliance_reports',
  'can_manage_org_users',
  'can_pause_org',
  'can_suspend_user',
  'can_view_risk_dashboard',
];

const requiredFunctions = [
  'create-organization',
  'invite-user',
  'accept-invite',
  'assign-role',
  'activate-user',
  'deactivate-user',
  'pause-organization',
  'resume-organization',
  'update-permission-template',
];

const requiredDocs = [
  'docs/product/SPRINT_7.md',
  'docs/architecture/ROLE_PERMISSION_MODEL.md',
  'docs/product/ENTERPRISE_ONBOARDING.md',
  'docs/runbooks/ONBOARDING_RUNBOOK.md',
  'docs/reports/SPRINT_7_SMOKE_TEST_RESULTS.md',
];

const violations = [];

function read(path) {
  return readFileSync(join(root, path), 'utf8');
}

const migrationText = [
  'supabase/migrations/20240510000000_sprint7_enterprise.sql',
  'supabase/migrations/20240510000100_sprint7_hardening.sql',
]
  .filter((path) => existsSync(join(root, path)))
  .map(read)
  .join('\n');

for (const table of requiredTables) {
  if (!migrationText.includes(table)) violations.push(`missing Sprint 7 table or hardening reference: ${table}`);
}

for (const role of requiredRoles) {
  if (!migrationText.includes(role)) violations.push(`missing Sprint 7 role: ${role}`);
}

for (const permission of requiredPermissions) {
  if (!migrationText.includes(permission)) violations.push(`missing Sprint 7 permission: ${permission}`);
}

for (const fn of requiredFunctions) {
  const fnPath = join(root, 'supabase', 'functions', fn, 'index.ts');
  if (!existsSync(fnPath)) {
    violations.push(`missing Edge Function: ${fn}`);
    continue;
  }

  const text = readFileSync(fnPath, 'utf8');
  if (/err\.message|error\.message|reason:\s*(err|error)\./.test(text)) violations.push(`${fn}: raw errors may be returned`);
  if (/console\.(log|debug|info|warn|error)\s*\(/.test(text)) violations.push(`${fn}: runtime logging is forbidden`);
  if (/event_context:\s*\{[^}]*email|event_context:\s*\{[^}]*admin_email|event_context:\s*\{[^}]*full_name/s.test(text)) {
    violations.push(`${fn}: onboarding audit context contains direct identity fields`);
  }
}

for (const doc of requiredDocs) {
  if (!existsSync(join(root, doc))) violations.push(`missing Sprint 7 doc: ${doc}`);
}

if (!/FORCE ROW LEVEL SECURITY/i.test(migrationText)) {
  violations.push('Sprint 7 migration must force RLS on new protected tables');
}

if (violations.length) {
  console.error('Sprint 7 static check failed:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log('Sprint 7 static check passed');
