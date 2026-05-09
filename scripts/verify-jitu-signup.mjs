
import fetch from 'node-fetch';
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

async function run() {
  console.log(`Starting verification for ${TEST_BROKER_EMAIL}...`);

  // 1. Try to Sign Up
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
  let accessToken = '';

  if (signupResponse.ok) {
    console.log('Signup successful (or user already exists if email confirmation is on).');
    accessToken = signupData.access_token;
  } else {
    console.log(`Signup failed/skipped: ${signupData.msg || signupData.error_description || JSON.stringify(signupData)}`);
    // Try to Sign In if signup failed (maybe user already exists)
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
    if (signinResponse.ok) {
      console.log('Signin successful.');
      accessToken = signinData.access_token;
    } else {
      console.log(`Signin failed: ${signinData.error_description || JSON.stringify(signinData)}`);
      return;
    }
  }

  if (!accessToken) {
    console.log('No access token obtained. Check if email confirmation is required.');
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
      company: 'Jitu Realty Solutions',
      area: 'Mumbai South',
      city: 'Mumbai',
      project_interest: 'Luxury Residential',
    }),
  });

  const onboardingData = await onboardingResponse.json();
  if (onboardingResponse.ok) {
    console.log('Onboarding successful:', onboardingData);
  } else {
    console.log('Onboarding failed:', onboardingData);
  }
}

run().catch(err => console.error(err));
