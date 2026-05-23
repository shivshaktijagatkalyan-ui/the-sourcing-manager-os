import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const scanDirs = [
  join('flutter_app', 'lib'),
  join('supabase', 'functions'),
];

const blockedTerms = [
  'masked_phone',
  'last_four',
  'plain_phone',
  'customer_phone',
  'mobile_number',
  'tel:',
  'wa.me',
  'api.whatsapp.com',
  'console.log(phone',
  'console.log(payload',
  'raw_provider_payload',
];

const blockedPatterns = [
  { pattern: /console\.(log|debug|info|warn|error)\s*\(/, reason: 'runtime logging is forbidden in frontend and Edge Functions' },
  { pattern: /https:\/\/wa\.me|https:\/\/api\.whatsapp\.com|tel:/i, reason: 'direct calling or WhatsApp links are forbidden' },
  { pattern: /last\s*4|last\s*four|masked\s*number/i, reason: 'partial or masked contact display is forbidden' },
  { pattern: /(?:api_key|api_token|secret_key|private_key|encryption_key|service_role_key)\s*=\s*['"`][0-9a-zA-Z+\/=_-]{16,}['"`]/i, reason: 'hardcoded credential or API key is forbidden' },
];

const edgeFunctionRawErrorPatterns = [
  { pattern: /reason:\s*(err|error)\.message/i, reason: 'raw internal error messages must not be returned to clients' },
  { pattern: /const\s+msg\s*=\s*error\s+instanceof\s+Error\s*\?\s*error\.message\s*:/i, reason: 'raw internal error aliases must not be returned to clients' },
  { pattern: /reason:\s*msg\b/i, reason: 'raw internal error aliases must not be returned to clients' },
  { pattern: /unknown_error/i, reason: 'generic internal failures should use stable public reason codes' },
];

const phoneWordAllowed = new Set([
  join('flutter_app', 'lib', 'screens', 'broker_upload.dart'),
  join('supabase', 'functions', 'broker-upload-lead', 'index.ts'),
  join('supabase', 'functions', 'manage-external-broker', 'index.ts'),
  join('supabase', 'functions', 'flag-abuse-event', 'index.ts'),
  join('flutter_app', 'lib', 'screens', 'add_broker_screen.dart'),
  join('flutter_app', 'lib', 'screens', 'broker_crm_list.dart'),
  join('flutter_app', 'lib', 'screens', 'broker_detail_screen.dart'),
  join('flutter_app', 'lib', 'screens', 'broker_followup_queue.dart'),
  join('flutter_app', 'lib', 'screens', 'activation_pipeline_board.dart'),
  join('flutter_app', 'lib', 'screens', 'add_lead_from_broker.dart'),
  join('flutter_app', 'lib', 'screens', 'sourcing_manager_dashboard.dart'),
  join('flutter_app', 'lib', 'screens', 'broker_sourced_site_visits.dart'),
  join('flutter_app', 'lib', 'screens', 'caller_dashboard_screen.dart'),
  join('flutter_app', 'lib', 'screens', 'caller_lead_queue_screen.dart'),
  join('supabase', 'functions', 'lead-from-broker', 'index.ts'),
  join('supabase', 'functions', 'manage-caller-workflow', 'index.ts'),
  join('supabase', 'functions', 'ai-lead-response', 'index.ts'),
  join('supabase', 'functions', 'kafka-decoder', 'index.ts'),
  join('supabase', 'functions', 'salesforce-webhook', 'index.ts'),
  join('supabase', 'functions', 'salesforce-sync-processor', 'index.ts'),
]);

function listFiles(dir) {
  const abs = join(root, dir);
  return readdirSync(abs).flatMap((entry) => {
    const path = join(abs, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) return listFiles(relative(root, path));
    if (!/\.(dart|ts)$/.test(path)) return [];
    return [path];
  });
}

const violations = [];

const configPath = join(root, 'supabase', 'config.toml');
if (existsSync(configPath)) {
  const configText = readFileSync(configPath, 'utf8');
  for (const match of configText.matchAll(/^\s*secret\s*=\s*"([^"]*)"/gim)) {
    const value = match[1].trim();
    if (value && !value.startsWith('env(') && !value.startsWith('encrypted:')) {
      violations.push('supabase/config.toml: OAuth provider secrets must use env(...) or encrypted: values');
      break;
    }
  }
}

for (const dir of scanDirs) {
  for (const file of listFiles(dir)) {
    const rel = relative(root, file);
    const normalizedRel = rel.split('\\').join('/');
    const text = readFileSync(file, 'utf8');
    const lowered = text.toLowerCase();

    for (const term of blockedTerms) {
      if (lowered.includes(term)) {
        violations.push(`${normalizedRel}: blocked term '${term}'`);
      }
    }

    for (const rule of blockedPatterns) {
      if (rule.pattern.test(text)) {
        violations.push(`${normalizedRel}: ${rule.reason}`);
      }
    }

    if (normalizedRel.startsWith('supabase/functions/')) {
      for (const rule of edgeFunctionRawErrorPatterns) {
        if (rule.pattern.test(text)) {
          violations.push(`${normalizedRel}: ${rule.reason}`);
        }
      }
    }

    if (!phoneWordAllowed.has(rel) && /\b(phone|mobile|whatsapp)\b/i.test(text)) {
      violations.push(`${normalizedRel}: contact wording outside broker upload flow`);
    }
  }
}

if (violations.length > 0) {
  console.error('Security constitution scan failed:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log('Security constitution scan passed');
