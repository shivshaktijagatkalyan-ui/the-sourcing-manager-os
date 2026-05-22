
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

const TEST_BROKER_EMAIL = getEnv('TEST_BROKER_EMAIL');
const TEST_BROKER_PASSWORD = getEnv('TEST_BROKER_PASSWORD');

async function request(path, method, body, token = null) {
  const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Content-Type': 'application/json',
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  const response = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null,
  });
  
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.msg || data.error_description || JSON.stringify(data));
  }
  return data;
}

async function run() {
  console.log("=== STARTING FULL UAT CYCLE ===");
  console.log(`Supabase URL: ${SUPABASE_URL}`);
  console.log(`Test Broker Email: ${TEST_BROKER_EMAIL}`);

  let token;
  console.log(`1. Authenticating as Broker...`);
  try {
    const authData = await request('/auth/v1/token?grant_type=password', 'POST', {
      email: TEST_BROKER_EMAIL,
      password: TEST_BROKER_PASSWORD,
    });
    token = authData.access_token;
    console.log("✅ Signin Successful.");
  } catch (err) {
    console.log(`Signin failed (${err.message}). Attempting signup...`);
    try {
      const authData = await request('/auth/v1/signup', 'POST', {
        email: TEST_BROKER_EMAIL,
        password: TEST_BROKER_PASSWORD,
      });
      token = authData.access_token;
      console.log("✅ Signup Successful.");
    } catch (err2) {
      console.error(`❌ Signup failed: ${err2.message}`);
      console.log("Please ensure the user is created in the Supabase Dashboard if email confirmation is enabled.");
      return;
    }
  }

  if (!token) {
    console.error("❌ No access token. Check email confirmation requirements.");
    return;
  }

  console.log("2. Completing Onboarding...");
  try {
    await request('/functions/v1/complete-onboarding', 'POST', {
      selected_role: 'broker_owner',
      full_name: 'Jitu Gupta (UAT)',
      company: 'JSN Enterprise (UAT)',
      area: 'Mira Road',
      city: 'Mumbai',
      project_interest: 'The Wadhwa Wise City',
    }, token);
    console.log("✅ Onboarding Complete.");
  } catch (err) {
    console.error(`❌ Onboarding failed: ${err.message}`);
    return;
  }

  console.log("3. Uploading Sample Lead...");
  try {
    const leadData = await request('/functions/v1/broker-upload-lead', 'POST', {
      alias: 'UAT_Lead_Alpha',
      phone: '+919988776655',
      area: 'Mira Road East',
      city: 'Mumbai',
      property_name: 'The Wadhwa Wise City',
      budget_min: 6500000,
      budget_max: 8500000,
    }, token);
    console.log(`✅ Lead Created: ${leadData.lead_id} (Alias: ${leadData.alias})`);
    console.log("\n=== UAT PHASE 1 SUCCESSFUL ===");
    console.log("Verify the lead in the Sourcing Manager dashboard.");
  } catch (err) {
    console.error(`❌ Lead Upload failed: ${err.message}`);
  }
}

run().catch(console.error);
