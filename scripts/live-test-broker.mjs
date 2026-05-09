
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

// Use the verified pilot email from TEST_CREDENTIALS.md
const TEST_BROKER_EMAIL = 'antigravity.test@gmail.com';
const TEST_BROKER_PASSWORD = 'PilotTest@2026';

async function run() {
  console.log(`Starting live verification for ${TEST_BROKER_EMAIL}...`);
  console.log(`Supabase URL: ${SUPABASE_URL}`);

  // 1. Try to Sign In (assuming Jitu is already signed up)
  console.log('Attempting signin...');
  const signinResponse = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: TEST_BROKER_EMAIL,
      password: TEST_BROKER_PASSWORD,
    }),
  });

  const signinData = await signinResponse.json();
  let accessToken = '';

  if (signinResponse.ok) {
    console.log('Signin successful.');
    accessToken = signinData.access_token;
  } else {
    console.log(`Signin failed: ${signinData.error_description || JSON.stringify(signinData)}`);
    
    // If signin failed, try signup
    console.log('Attempting signup...');
    const signupResponse = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: TEST_BROKER_EMAIL,
        password: TEST_BROKER_PASSWORD,
      }),
    });

    const signupData = await signupResponse.json();
    if (signupResponse.ok) {
      console.log('Signup successful (check email for confirmation if enabled).');
      accessToken = signupData.access_token;
    } else {
      console.log(`Signup failed: ${signupData.msg || signupData.error_description || JSON.stringify(signupData)}`);
      return;
    }
  }

  if (!accessToken) {
    console.log('No access token obtained. Check if email confirmation is required for this Supabase project.');
    return;
  }

  // 2. Call complete-onboarding
  console.log('Calling complete-onboarding...');
  const onboardingResponse = await fetch(`${SUPABASE_URL}/functions/v1/complete-onboarding`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      selected_role: 'broker_owner',
      full_name: 'Jitu Gupta',
      company: 'JSN Enterprise (Live Test)',
      area: 'Mira Road',
      city: 'Mumbai',
      project_interest: 'The Wadhwa Wise City',
    }),
  });

  const onboardingData = await onboardingResponse.json();
  if (onboardingResponse.ok) {
    console.log('Onboarding successful:', JSON.stringify(onboardingData, null, 2));
  } else {
    console.log('Onboarding failed:', JSON.stringify(onboardingData, null, 2));
  }
  
  // 3. Verify Broker Dashboard Access (Data Retrieval)
  console.log('Verifying broker profile data retrieval...');
  const profileResponse = await fetch(`${SUPABASE_URL}/rest/v1/brokers_public?select=*&email=eq.${TEST_BROKER_EMAIL}`, {
    method: 'GET',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  });
  
  const profileData = await profileResponse.json();
  if (profileResponse.ok) {
    console.log('Broker profile found:', JSON.stringify(profileData, null, 2));
  } else {
    console.log('Broker profile retrieval failed:', JSON.stringify(profileData, null, 2));
  }
}

run().catch(err => {
  console.error('Test Execution Error:', err);
});
