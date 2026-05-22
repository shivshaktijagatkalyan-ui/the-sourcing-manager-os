
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

const TEST_EMAIL = 'shivshaktijagatkalyan@gmail.com';
const TEST_PASSWORD = 'nevermorezxcR12345';

async function run() {
  console.log("🚀 Starting Step 2: Stress-Testing Lead Intake & Broker Lock...");

  // 1. Auth
  let signinResponse = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'apikey': SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
  });
  
  if (!signinResponse.ok) {
    console.log("Signin failed, attempting signup...");
    const signupResponse = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
      method: 'POST',
      headers: { 'apikey': SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
    });
    
    if (signupResponse.ok) {
      console.log("Signup successful. Retrying signin...");
      signinResponse = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: { 'apikey': SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
      });
    }
  }

  const signinData = await signinResponse.json();
  if (!signinResponse.ok) throw new Error("Auth failed: " + JSON.stringify(signinData));
  const token = signinData.access_token;
  const userId = signinData.user.id;

  // 2. Get Org and Broker Info
  const orgResponse = await fetch(`${SUPABASE_URL}/rest/v1/pilot_users?select=org_id&user_id=eq.${userId}`, {
    headers: { 'apikey': SUPABASE_ANON_KEY, 'Authorization': `Bearer ${token}` }
  });
  const orgData = await orgResponse.json();
  const orgId = orgData[0].org_id;

  const brokerResponse = await fetch(`${SUPABASE_URL}/rest/v1/brokers_public?select=id,broker_alias&organization_id=eq.${orgId}&limit=1`, {
    headers: { 'apikey': SUPABASE_ANON_KEY, 'Authorization': `Bearer ${token}` }
  });
  const brokerData = await brokerResponse.json();
  if (!brokerData.length) throw new Error("No broker found for testing");
  const brokerId = brokerData[0].id;
  const brokerAlias = brokerData[0].broker_alias;

  console.log(`Using Broker: ${brokerAlias} (${brokerId}) for Org: ${orgId}`);

  // 3. Stress Test Intake (Parallel Requests)
  const leadsToCreate = [
    { alias: 'STRESS-001', area: 'Thane', budget: 5000000 },
    { alias: 'STRESS-002', area: 'Kalyan', budget: 4500000 },
    { alias: 'STRESS-003', area: 'Dombivli', budget: 6000000 }
  ];

  console.log(`Ingesting ${leadsToCreate.length} leads in parallel...`);

  const results = await Promise.all(leadsToCreate.map(lead => 
    fetch(`${SUPABASE_URL}/functions/v1/lead-from-broker`, {
      method: 'POST',
      headers: { 
        'apikey': SUPABASE_ANON_KEY, 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        action: 'create_lead_from_broker',
        organization_id: orgId,
        source_broker_id: brokerId,
        lead_alias: lead.alias,
        area: lead.area,
        city: 'Mumbai',
        budget_min: lead.budget,
        budget_max: lead.budget + 1000000,
        phone: '9988776655', // Test phone
        notes_safe: 'Stress test automated entry.'
      })
    }).then(r => r.json())
  ));

  results.forEach((res, i) => {
    if (res.ok) {
      console.log(`✅ Lead ${leadsToCreate[i].alias} created: ${res.lead_id}`);
    } else {
      console.error(`❌ Lead ${leadsToCreate[i].alias} failed: ${res.reason}`);
    }
  });

  // 4. Verify Activity Logs
  console.log("Verifying Broker Activity Logs...");
  const logResponse = await fetch(`${SUPABASE_URL}/rest/v1/broker_activity_logs?select=*&broker_id=eq.${brokerId}&order=created_at.desc&limit=3`, {
    headers: { 'apikey': SUPABASE_ANON_KEY, 'Authorization': `Bearer ${token}` }
  });
  const logs = await logResponse.json();
  console.log(`Retrieved ${logs.length} recent activity logs.`);
  
  if (logs.length >= leadsToCreate.length) {
    console.log("✅ Activity Log Integrity: PASSED");
  } else {
    console.error("❌ Activity Log Integrity: FAILED (Missing logs)");
  }

  console.log("Step 2 Stress Test Complete.");
}

run().catch(e => console.error("Test failed:", e));
