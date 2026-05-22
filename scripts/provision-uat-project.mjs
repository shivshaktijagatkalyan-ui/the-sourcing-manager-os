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
} = process.env;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !UAT_ORGANIZATION_ID) {
  console.error('Usage: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... UAT_ORGANIZATION_ID=... node scripts/provision-uat-project.mjs');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function provision() {
  console.log('Provisioning UAT reference project...');

  const projectData = {
    organization_id: UAT_ORGANIZATION_ID,
    project_name: 'FutureTrust UAT Reference Project',
    city: 'Navi Mumbai',
    area: 'Panvel',
    latitude: 19.0330,
    longitude: 73.0297,
    geofence_radius_meters: 500,
    status: 'active'
  };

  let project = null;
  const { data: existing } = await supabase
    .from('projects')
    .select('id, latitude, longitude')
    .eq('project_name', projectData.project_name)
    .eq('organization_id', projectData.organization_id)
    .maybeSingle();

  if (existing) {
    project = existing;
    console.log('Found existing UAT project.');
  } else {
    const { data: created, error } = await supabase
      .from('projects')
      .insert(projectData)
      .select('id, latitude, longitude')
      .single();

    if (error) {
      console.error('Project provisioning error:', error.message);
      process.exit(1);
    }
    project = created;
    console.log('Created new UAT project.');
  }

  console.log('\nUAT project provisioned.');
  console.log('\nAdd these to your .env file to enable GPS/Photo/Lock UAT:');
  console.log('---------------------------------------------------------');
  console.log(`TRUST_LOOP_PROJECT_ID=${project.id}`);
  console.log(`TRUST_LOOP_PROJECT_LAT=${project.latitude}`);
  console.log(`TRUST_LOOP_PROJECT_LNG=${project.longitude}`);
  console.log('---------------------------------------------------------');
}

provision();
