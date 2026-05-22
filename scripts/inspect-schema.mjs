
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, '../.env');
const envContent = fs.readFileSync(envPath, 'utf8');

const getEnv = (key) => {
  const match = envContent.match(new RegExp(`^${key}=(.*)$`, 'm'));
  return match ? match[1].trim() : null;
};

const SUPABASE_URL = getEnv('SUPABASE_URL');
const SUPABASE_ANON_KEY = getEnv('SUPABASE_ANON_KEY');

async function checkTable(tableName) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${tableName}?select=count`, {
    method: 'GET',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
      'Prefer': 'count=exact'
    },
  });
  
  if (response.ok) {
    console.log(`✅ Table '${tableName}' exists.`);
    return true;
  } else {
    console.log(`❌ Table '${tableName}' NOT found or access denied (Status: ${response.status}).`);
    return false;
  }
}

async function run() {
  console.log("Verifying core tables...");
  await checkTable('leads_public');
  await checkTable('brokers_public');
  await checkTable('audit_events');
  await checkTable('site_visits');
}

run().catch(console.error);
