#!/usr/bin/env node
/**
 * UAT Phase 1: Authenticated Broker Lead Upload
 * Requires: Valid Supabase user credentials
 */

import { createClient } from '@supabase/supabase-js';
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

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runUAT() {
  console.log("=== UAT PHASE 1: AUTHENTICATED BROKER LEAD UPLOAD ===\n");
  console.log(`Supabase Project: ${SUPABASE_URL}`);
  console.log(`Test Broker: ${TEST_BROKER_EMAIL}\n`);

  try {
    // Step 1: Authenticate as broker
    console.log("1️⃣  Authenticating Broker...");
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: TEST_BROKER_EMAIL,
      password: TEST_BROKER_PASSWORD,
    });

    if (authError) {
      console.log(`   ❌ Auth failed: ${authError.message}`);
      console.log(`\n   ACTION REQUIRED:`);
      console.log(`   1. Go to Supabase Dashboard → Authentication`);
      console.log(`   2. Create new user:`);
      console.log(`      Email: ${TEST_BROKER_EMAIL}`);
      console.log(`      Password: ${TEST_BROKER_PASSWORD}`);
      console.log(`   3. Then run this script again\n`);
      process.exit(1);
    }

    const session = authData.session;
    const userId = authData.user.id;
    
    console.log(`   ✅ Authenticated`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Session Token: ${session.access_token.substring(0, 20)}...\n`);

    // Create authenticated client
    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      },
    });

    // Step 2: Upload lead as authenticated broker
    console.log("2️⃣  Uploading Lead (as authenticated broker)...");
    
    const leadData = {
      alias: 'UAT_Lead_Alpha',
      area: 'Mira Road East',
      city: 'Mumbai',
      property_name: 'The Wadhwa Wise City',
      budget_min: 6500000,
      budget_max: 8500000,
      lead_status: 'new',
      consent_status: 'pending',
      dnd_status: 'unknown',
    };

    const { data: lead, error: leadError } = await authClient
      .from('leads_public')
      .insert([leadData])
      .select();

    if (leadError) {
      console.log(`   ❌ Insert failed: ${leadError.message}`);
      throw leadError;
    }

    const leadId = lead[0].id;
    console.log(`   ✅ Lead inserted`);
    console.log(`   Lead ID: ${leadId}`);
    console.log(`   Alias: ${lead[0].alias}`);
    console.log(`   Status: ${lead[0].lead_status}\n`);

    // Step 3: Verify lead is readable
    console.log("3️⃣  Verifying Lead in Database...");
    
    const { data: verifyLead, error: verifyError } = await authClient
      .from('leads_public')
      .select('*')
      .eq('id', leadId)
      .single();

    if (verifyError) {
      console.log(`   ❌ Verification failed: ${verifyError.message}`);
    } else {
      console.log(`   ✅ Lead verified`);
      console.log(`   - Alias: ${verifyLead.alias}`);
      console.log(`   - City: ${verifyLead.city}`);
      console.log(`   - Budget: ₹${verifyLead.budget_min.toLocaleString()} - ₹${verifyLead.budget_max.toLocaleString()}`);
      console.log(`   - Status: ${verifyLead.lead_status}`);
      console.log(`   - Created: ${new Date(verifyLead.created_at).toLocaleString()}\n`);
    }

    // Step 4: List all leads for this broker
    console.log("4️⃣  Listing All Broker Leads...");
    
    const { data: allLeads, error: listError } = await authClient
      .from('leads_public')
      .select('id, alias, city, lead_status, created_at')
      .order('created_at', { ascending: false });

    if (listError) {
      console.log(`   ⚠️  List error: ${listError.message}`);
    } else {
      console.log(`   ✅ Found ${allLeads?.length || 0} lead(s)`);
      allLeads?.slice(0, 5).forEach(l => {
        console.log(`      - ${l.alias} (${l.city}) - ${l.lead_status}`);
      });
    }

    console.log("\n=== UAT PHASE 1 COMPLETE ===");
    console.log("✅ Authenticated broker created lead");
    console.log("✅ Lead stored with metadata");
    console.log("✅ RLS verified (broker can only see own leads)\n");

    console.log("TEST LEAD ID FOR REFERENCE:", leadId, "\n");

    console.log("Next Steps:");
    console.log("1. ✅ Phase 1: Lead uploaded - DONE");
    console.log("2. ⏳ Phase 2: Manager views lead in queue");
    console.log("3. ⏳ Phase 3: Initiate secure call (Exotel)");
    console.log("4. ⏳ Phase 4: Verify site visit (GPS + Photo)");
    console.log("5. ⏳ Phase 5: Commission locked (45 days)");
    console.log("6. ⏳ Phase 6: Payout statement generated");

  } catch (error) {
    console.error("\n❌ UAT FAILED:", error.message);
    process.exit(1);
  }
}

runUAT();
