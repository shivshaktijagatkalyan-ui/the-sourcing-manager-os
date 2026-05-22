import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const functionPath = join(root, 'supabase', 'functions', 'super-admin-dashboard', 'index.ts');
const configPath = join(root, 'supabase', 'config.toml');
const violations = [];
const requiredPermissions = [
  'can_manage_org_users',
  'can_view_risk_dashboard',
  'can_pause_org',
];

const requiredResponseKeys = [
  'ok',
  'generated_at',
  'platform_health',
  'failed_functions',
  'provider_failures',
  'callback_failures',
  'last_release_gate',
  'health',
  'status',
  'last_event',
  'critical_failures_1h',
  'kpis',
  'organizations',
  'total_organizations',
  'active_brokers',
  'active_callers',
  'active_sms',
  'leads_today',
  'verified_visits_today',
  'active_broker_locks',
  'open_risks',
  'active_projects',
  'active_users',
  'total_brokers',
  'total_leads',
  'calls_attempted',
  'scheduled_visits',
  'verified_visits',
  'active_locks',
  'open_disputes',
  'open_risk_alerts',
  'held_sync_reviews',
  'projects',
  'attention_queue',
  'safe_ref',
  'route',
  'workforce',
  'brokers',
  'callers',
  'sourcing_managers',
  'workflow_bottlenecks',
  'trust_operations',
  'risk_alerts',
  'workflow_summary',
  'lead_intake_today',
  'secure_calls_today',
  'site_visits_today',
  'proofs_pending',
  'locks_created_today',
  'payouts_pending_review',
  'audit_events',
  'allowed_actions',
];

function functionBlock(configText, name) {
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = configText.match(new RegExp(`^\\[functions\\.${escapedName}\\]\\n([\\s\\S]*?)(?=^\\[|(?![\\s\\S]))`, 'm'));
  return match?.[1] ?? null;
}

if (!existsSync(functionPath)) {
  violations.push('missing Edge Function: super-admin-dashboard');
} else {
  const text = readFileSync(functionPath, 'utf8');
  const forbiddenTerms = [
    'phone',
    'phone_ciphertext',
    'raw_payload',
    'provider_payload',
    'contact_number',
    'email',
    'invited_email',
    'email_list',
    'raw_contact',
    'contact_text',
    'buyer_name',
    'encrypted_contact',
    'contact_ciphertext',
    'lead_contact_blob',
  ];

  if (!/currentUser\s*\(\s*req\s*\)/.test(text)) {
    violations.push('super-admin-dashboard must resolve currentUser(req)');
  }

  if (!/\brequirePermission\s*\(/.test(text)) {
    violations.push('super-admin-dashboard must use requirePermission');
  }

  if (!/\brecordAudit\s*\(/.test(text)) {
    violations.push('super-admin-dashboard must record sanitized audit events');
  }

  if (!/\badminClient\s*\(/.test(text)) {
    violations.push('super-admin-dashboard must use adminClient');
  }

  if (!/\.from\s*\(\s*['"`]role_assignments['"`]\s*\)/.test(text) || !/role_id/.test(text)) {
    violations.push('super-admin-dashboard must read role_assignments.role_id');
  }

  if (!/platform_admin/.test(text) || !/ops_admin/.test(text) || !/role_assignments/.test(text)) {
    violations.push('super-admin-dashboard must require platform_admin or ops_admin from role_assignments');
  }

  if (/\.eq\s*\(\s*['"`]role['"`]\s*,\s*['"`]platform_admin['"`]\s*\)/.test(text)) {
    violations.push('super-admin-dashboard must not rely on legacy pilot_users.role for platform_admin gating');
  }

  if (!/super_admin_dashboard_viewed/.test(text)) {
    violations.push('super-admin-dashboard must record super_admin_dashboard_viewed audit event');
  }

  const requiredHelpers = [
    'requirePlatformAdmin',
    'getPlatformHealthSnapshot',
    'getOrganizationSummary',
    'getWorkforcePerformance',
    'getAttentionQueue',
    'getTrustOperations',
    'getRiskSummary',
    'getAuditTimeline',
    'getAllowedActions',
  ];

  for (const helper of requiredHelpers) {
    if (!text.includes(helper)) {
      violations.push(`super-admin-dashboard missing helper: ${helper}`);
    }
  }

  for (const permission of requiredPermissions) {
    if (!text.includes(permission)) {
      violations.push(`super-admin-dashboard missing required permission check: ${permission}`);
    }
  }

  for (const key of requiredResponseKeys) {
    if (!text.includes(key)) {
      violations.push(`super-admin-dashboard missing deterministic response key: ${key}`);
    }
  }

  if (/\.select\s*\(\s*['"`]\*/.test(text)) {
    violations.push('super-admin-dashboard must not select wildcard columns');
  }

  if (/\.select\s*\(\s*['"`][^'"`]*event_context/.test(text)) {
    violations.push('super-admin-dashboard must not select raw audit event_context blobs');
  }

  for (const term of forbiddenTerms) {
    if (text.includes(term)) {
      violations.push(`super-admin-dashboard must not read or return forbidden PII term: ${term}`);
    }
  }
}

if (!existsSync(configPath)) {
  violations.push('missing supabase/config.toml');
} else {
  const configText = readFileSync(configPath, 'utf8');
  const block = functionBlock(configText, 'super-admin-dashboard');
  if (!block) {
    violations.push('config.toml must register [functions.super-admin-dashboard]');
  } else if (!/^verify_jwt\s*=\s*true$/m.test(block)) {
    violations.push('config.toml must register [functions.super-admin-dashboard] with verify_jwt = true');
  }
}

if (violations.length > 0) {
  console.error('Super Admin dashboard static check failed:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log('Super Admin dashboard static check passed');
