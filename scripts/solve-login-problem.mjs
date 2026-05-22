import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function loadEnvFile(name) {
  const file = path.join(root, name);
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match || line.trim().startsWith('#')) continue;
    if (process.env[match[1]] === undefined) {
      process.env[match[1]] = match[2].replace(/^"(.*)"$/, '$1');
    }
  }
}

loadEnvFile('.env.local');
loadEnvFile('.env');

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  UAT_ORGANIZATION_ID,
  UAT_ACTOR_USER_ID,
} = process.env;

if (!SUPABASE_URL) {
  throw new Error('SUPABASE_URL is required');
}

if (!SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_SERVICE_ROLE_KEY is required; do not use database passwords or anon keys for this script');
}

if (!UAT_ORGANIZATION_ID) {
  throw new Error('UAT_ORGANIZATION_ID is required');
}

if (!UAT_ACTOR_USER_ID) {
  throw new Error('UAT_ACTOR_USER_ID is required');
}

const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false, autoRefreshToken: false } }
);

const testUsers = [
  { email: 'jitu.broker.uat@sourcing-manager-os.test', password: 'PilotTest@2026!Secure', role: 'broker_owner' },
  { email: 'vinod.sourcing-manager@sourcing-manager-os.test', password: 'PilotTest@2026!Secure', role: 'sourcing_manager' },
  { email: 'rahul.caller.uat@sourcing-manager-os.test', password: 'PilotTest@2026!Secure', role: 'caller' },
];

async function solveLoginProblem() {
  console.log('Fixing login for production UAT users.');

  for (const user of testUsers) {
    console.log(`\nProcessing ${user.email}...`);
    
    // 1. Create User in Auth (Bypass Email Confirmation)
    const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
      email: user.email,
      password: user.password,
      email_confirm: true, // AUTO-CONFIRM
      user_metadata: { role: user.role }
    });

    if (authError) {
      if (authError.message.includes('already exists') || authError.message.includes('already been registered')) {
        console.log('User already exists in Auth.');
      } else {
        console.error('Auth error:', authError.message);
        continue;
      }
    } else {
      console.log('User created in Auth.');
    }

    // 2. Fetch User ID (either newly created or existing)
    const { data: users } = await supabase.auth.admin.listUsers();
    const target = users.users.find(u => u.email === user.email);
    
    if (!target) {
      console.error('Could not find user after creation.');
      continue;
    }

    const orgId = UAT_ORGANIZATION_ID;
    const actorId = UAT_ACTOR_USER_ID;

    // 3. Ensure Permission Template exists for this role in this Org
    let templateId = null;
    const templateName = `${user.role}_default_uat`;
    
    const { data: existingTemplate } = await supabase
      .from('permission_templates')
      .select('id')
      .eq('organization_id', orgId)
      .eq('name', templateName)
      .maybeSingle();

    if (existingTemplate) {
      templateId = existingTemplate.id;
    } else {
      const { data: newTemplate, error: tError } = await supabase
        .from('permission_templates')
        .insert({
          organization_id: orgId,
          name: templateName,
          status: 'active',
          created_by: actorId,
          updated_by: actorId
        })
        .select('id')
        .single();
      
      if (tError) {
        console.error(`Template creation error for ${user.role}:`, tError.message);
      } else {
        templateId = newTemplate.id;
        console.log(`Template created for ${user.role}.`);

        // Populate permissions
        const { data: rolePerms } = await supabase
          .from('role_permissions')
          .select('permission_id')
          .eq('role_id', user.role);
        
        if (rolePerms && rolePerms.length > 0) {
          const rows = rolePerms.map(p => ({ template_id: templateId, permission_id: p.permission_id }));
          await supabase.from('permission_template_permissions').insert(rows);
          console.log(`${rows.length} permissions linked to template.`);
        } else {
          console.error(`No permissions found for role ${user.role}; refusing to assign a blank template.`);
          continue;
        }
      }
    }

    if (!templateId) {
      console.error(`No permission template available for ${user.role}.`);
      continue;
    }

    // 4. Ensure Role Assignment
    const { error: roleError } = await supabase
      .from('role_assignments')
      .upsert({
        user_id: target.id,
        role_id: user.role,
        organization_id: orgId,
        permission_template_id: templateId,
        status: 'active',
        assigned_by: actorId
      }, { onConflict: 'user_id' });

    if (roleError) {
      console.error('Role assignment error:', roleError.message);
    } else {
      console.log(`Role '${user.role}' assigned in role_assignments (Template: ${templateId}).`);
    }

    // 5. Sync to pilot_users (Legacy/Parallel table check)
    const { error: pilotError } = await supabase
      .from('pilot_users')
      .upsert({
        user_id: target.id,
        org_id: orgId,
        role: user.role,
        status: 'active',
        metadata: { onboarding_status: 'active' }
      }, { onConflict: 'user_id' });

    if (pilotError) {
      console.error('Pilot user sync error:', pilotError.message);
    } else {
      console.log('User synced to pilot_users table.');
    }
  }

  console.log('\nUAT user sync finished.');
}

solveLoginProblem();
