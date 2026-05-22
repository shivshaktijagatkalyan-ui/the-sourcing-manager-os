import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();

const requiredTools = [
  'trust-get-lead-summary',
  'trust-get-broker-lock-status',
  'trust-get-followup-risk',
  'trust-get-site-visit-proof',
  'trust-create-followup',
  'trust-recommend-next-action',
];

const requiredOutputTokens = {
  'trust-get-lead-summary': [
    'lead_alias',
    'status',
    'budget_range',
    'area',
    'project_interest',
    'source_broker_id',
  ],
  'trust-get-broker-lock-status': [
    'lock_status',
    'days_remaining',
    'brokerage_status',
    'proof_status',
  ],
  'trust-get-followup-risk': [
    'followup_delay',
    'risk_level',
    'next_action',
  ],
  'trust-get-site-visit-proof': [
    'gps_verified',
    'photo_uploaded',
    'timestamp',
    'proof_status',
  ],
  'trust-create-followup': [
    'audit_event_id',
    'broker_followups',
    'audit_events',
  ],
  'trust-recommend-next-action': [
    'recommended_action',
    'reason',
    'risk',
    'confidence',
  ],
};

const blockedPatterns = [
  { pattern: /leads_sensitive/i, reason: 'AI tools must not read sensitive lead storage' },
  { pattern: /brokers_sensitive/i, reason: 'AI tools must not read sensitive broker storage' },
  { pattern: /\bdecrypt\w*/i, reason: 'AI tools must not decrypt restricted values' },
  { pattern: /service_role/i, reason: 'AI tools must not expose service role details' },
  { pattern: /console\.(log|debug|info|warn|error)\s*\(/, reason: 'AI tools must not log runtime data' },
  { pattern: /reason:\s*(err|error)\.message/i, reason: 'AI tools must not return raw internal errors' },
  { pattern: /tel:|wa\.me|api\.whatsapp\.com/i, reason: 'direct outreach shortcuts are forbidden' },
  { pattern: /\b(phone|mobile|whatsapp)\b/i, reason: 'AI tools must avoid restricted wording and fields' },
];

const violations = [];
const configPath = join(root, 'supabase', 'config.toml');
const config = existsSync(configPath) ? readFileSync(configPath, 'utf8') : '';

for (const tool of requiredTools) {
  const functionPath = join(root, 'supabase', 'functions', tool, 'index.ts');
  if (!existsSync(functionPath)) {
    violations.push(`${tool}: missing Edge Function source`);
    continue;
  }

  const source = readFileSync(functionPath, 'utf8');
  const configPattern = new RegExp(`\\[functions\\.${tool}\\][\\s\\S]*?verify_jwt\\s*=\\s*true`, 'm');
  if (!configPattern.test(config)) {
    violations.push(`${tool}: missing verify_jwt=true registration in supabase/config.toml`);
  }

  for (const rule of blockedPatterns) {
    if (rule.pattern.test(source)) {
      violations.push(`${tool}: ${rule.reason}`);
    }
  }

  for (const token of requiredOutputTokens[tool]) {
    if (!source.includes(token)) {
      violations.push(`${tool}: missing required metadata token '${token}'`);
    }
  }
}

if (violations.length > 0) {
  console.error('AI safe tool layer check failed:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log('AI safe tool layer check passed');
