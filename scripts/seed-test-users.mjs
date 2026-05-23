import { createClient } from '@supabase/supabase-js';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = process.cwd();
const apply = process.argv.includes('--apply');

function loadDotEnv(path) {
  if (!existsSync(path)) return;
  const text = readFileSync(path, 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const rawValue = trimmed.slice(eq + 1).trim();
    const value = rawValue.replace(/^['"]|['"]$/g, '');
    if (key && process.env[key] === undefined) process.env[key] = value;
  }
}

loadDotEnv(resolve(root, '.env'));
loadDotEnv(resolve(root, 'provider.env'));

const dryRunRequiredEnv = [
  'TEST_BROKER_EMAIL',
  'TEST_CALLER_EMAIL',
  'TEST_SM_EMAIL',
];

const applyRequiredEnv = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'UAT_ORGANIZATION_ID',
  'TEST_BROKER_PASSWORD',
  'TEST_CALLER_PASSWORD',
  'TEST_SM_PASSWORD',
];

const requiredEnv = apply
  ? [...dryRunRequiredEnv, ...applyRequiredEnv]
  : dryRunRequiredEnv;
const missing = requiredEnv.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error(`Missing required environment variables: ${missing.join(', ')}`);
  process.exit(1);
}

const orgId = process.env.UAT_ORGANIZATION_ID;
const users = [
  {
    email: process.env.TEST_BROKER_EMAIL,
    password: process.env.TEST_BROKER_PASSWORD,
    role: 'broker_owner',
    legacyRole: 'broker',
  },
  {
    email: process.env.TEST_CALLER_EMAIL,
    password: process.env.TEST_CALLER_PASSWORD,
    role: 'caller',
    legacyRole: 'caller',
  },
  {
    email: process.env.TEST_SM_EMAIL,
    password: process.env.TEST_SM_PASSWORD,
    role: 'sourcing_manager',
    legacyRole: 'sourcing_manager',
  },
];

if (!apply) {
  console.log('Dry run only. Re-run with --apply to create or update UAT users.');
  for (const user of users) {
    console.log(`- ${user.email}: ${user.role}`);
  }
  process.exit(0);
}

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

async function findUserByEmail(email) {
  const normalized = email.toLowerCase();
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({
      page,
      perPage: 100,
    });
    if (error) throw error;
    const match = data.users.find((user) => user.email?.toLowerCase() === normalized);
    if (match) return match;
    if (data.users.length < 100) return null;
  }
  return null;
}

async function permissionTemplateForRole(role) {
  const { data, error } = await supabase
    .from('permission_templates')
    .select('id')
    .eq('organization_id', orgId)
    .eq('status', 'active')
    .ilike('name', `%${role}%`)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data?.id ?? null;
}

async function createOrUpdateUser(seed) {
  const existing = await findUserByEmail(seed.email);
  if (existing) {
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, {
      password: seed.password,
      email_confirm: true,
      app_metadata: {
        ...existing.app_metadata,
        role: seed.role,
      },
      user_metadata: {
        ...existing.user_metadata,
        role: seed.role,
      },
    });
    if (error) throw error;
    return data.user;
  }

  const { data, error } = await supabase.auth.admin.createUser({
    email: seed.email,
    password: seed.password,
    email_confirm: true,
    app_metadata: {
      role: seed.role,
    },
    user_metadata: {
      role: seed.role,
    },
  });
  if (error) throw error;
  return data.user;
}

for (const seed of users) {
  const user = await createOrUpdateUser(seed);
  const templateId = await permissionTemplateForRole(seed.role);

  const rolePayload = {
    organization_id: orgId,
    user_id: user.id,
    role_id: seed.role,
    permission_template_id: templateId,
    status: 'active',
  };

  const { error: roleError } = await supabase
    .from('role_assignments')
    .upsert(rolePayload, { onConflict: 'user_id' });
  if (roleError) throw roleError;

  const { error: pilotError } = await supabase
    .from('pilot_users')
    .upsert(
      {
        user_id: user.id,
        org_id: orgId,
        role: seed.legacyRole,
        status: 'active',
      },
      { onConflict: 'user_id' },
    );
  if (pilotError) throw pilotError;

  console.log(`Seeded ${seed.email} as ${seed.role}`);
}

console.log('UAT test users seeded.');
