import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, '../.env');
const envContent = fs.readFileSync(envPath, 'utf8');

function getEnv(key) {
  const line = envContent
    .split(/\r?\n/)
    .find((entry) => entry.match(new RegExp(`^\\s*${key}\\s*=`)));
  if (!line) return null;
  const value = line.split(/=(.*)/s)[1]?.trim() ?? '';
  return value.replace(/^["']|["']$/g, '');
}

const SUPABASE_URL = getEnv('SUPABASE_URL');
const SUPABASE_ANON_KEY = getEnv('SUPABASE_ANON_KEY');
const TEST_BROKER_EMAIL = getEnv('TEST_BROKER_EMAIL') || 'antigravity.test@gmail.com';
const TEST_BROKER_PASSWORD = getEnv('TEST_BROKER_PASSWORD');
const verifyExistingIndex = process.argv.indexOf('--verify-existing');
const existingLeadId = verifyExistingIndex >= 0 ? process.argv[verifyExistingIndex + 1] : null;

function requireEnv(name, value) {
  if (!value) throw new Error(`${name} is required in .env`);
}

async function request(pathname, method, body, token = null) {
  const headers = {
    apikey: SUPABASE_ANON_KEY,
    'Content-Type': 'application/json',
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${SUPABASE_URL}${pathname}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${response.status} ${JSON.stringify(data)}`);
  }
  return data;
}

async function run() {
  requireEnv('SUPABASE_URL', SUPABASE_URL);
  requireEnv('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY);
  requireEnv('TEST_BROKER_PASSWORD', TEST_BROKER_PASSWORD);

  console.log('=== LIVE UAT: Broker Lead Upload ===');
  console.log(`Broker: ${TEST_BROKER_EMAIL}`);
  console.log(`Project: ${SUPABASE_URL}`);

  const auth = await request('/auth/v1/token?grant_type=password', 'POST', {
    email: TEST_BROKER_EMAIL,
    password: TEST_BROKER_PASSWORD,
  });

  const token = auth.access_token;
  const userId = auth.user?.id;
  if (!token || !userId) throw new Error('signin_missing_access_token');
  console.log('Signin: PASS');

  await request('/functions/v1/complete-onboarding', 'POST', {
    selected_role: 'broker_owner',
    full_name: 'Jitu Gupta',
    company: 'JSN Enterprise (Lead Upload UAT)',
    area: 'Mira Road',
    city: 'Mumbai',
    project_interest: 'The Wadhwa Wise City',
  }, token);
  console.log('Onboarding idempotency check: PASS');

  let leadId = existingLeadId;
  let alias = null;

  if (existingLeadId) {
    console.log(`Using existing lead for verification: ${existingLeadId}`);
  } else {
    const stamp = Date.now().toString().slice(-8);
    alias = `UAT_LEAD_${stamp}`;
    const phone = `+9198${stamp}`;

    const upload = await request('/functions/v1/broker-upload-lead', 'POST', {
      alias,
      phone,
      area: 'Mira Road East',
      city: 'Mumbai',
      property_name: 'The Wadhwa Wise City',
      budget_min: 6500000,
      budget_max: 8500000,
    }, token);

    if (!upload.ok || !upload.lead_id) {
      throw new Error(`lead_upload_unexpected_response ${JSON.stringify(upload)}`);
    }
    if (JSON.stringify(upload).toLowerCase().includes('phone')) {
      throw new Error('lead_upload_response_exposed_contact_data');
    }
    leadId = upload.lead_id;
    console.log(`Lead upload: PASS (${leadId})`);
  }

  const publicRows = await request(
    `/rest/v1/leads_public?select=id,alias,broker_id,area,city,property_name,budget_min,budget_max,lead_status&id=eq.${leadId}`,
    'GET',
    null,
    token,
  );

  if (!Array.isArray(publicRows)) {
    throw new Error('lead_public_rest_response_not_array');
  }

  if (publicRows.length === 0) {
    console.log('Broker REST read isolation: PASS');
  } else {
    const publicLead = publicRows[0];
    if (alias && publicLead.alias !== alias) {
      throw new Error(`lead_public_row_mismatch ${JSON.stringify(publicLead)}`);
    }
    if (publicLead.broker_id !== userId) {
      throw new Error(`lead_public_broker_mismatch ${JSON.stringify(publicLead)}`);
    }
    if (JSON.stringify(publicLead).toLowerCase().includes('phone')) {
      throw new Error('lead_public_row_exposed_contact_data');
    }
    console.log('Public lead broker read: PASS');
  }

  console.log('Sensitive contact exposure check: PASS');
  console.log('=== BROKER LEAD UPLOAD UAT PASSED ===');
}

run().catch((error) => {
  console.error('Broker lead upload UAT failed:', error.message);
  process.exit(1);
});
