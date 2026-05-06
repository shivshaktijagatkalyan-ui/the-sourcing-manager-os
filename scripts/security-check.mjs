import { readdirSync, readFileSync, statSync } from 'node:fs';
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
