#!/usr/bin/env node
/**
 * AUTHENTICATED BROKER RLS DEBUG INVESTIGATION
 * Systematic check of user creation → role assignment → lead upload
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

const log = (step, message, details = null) => {
  console.log(`\n${step}`);
  console.log(`   ${message}`);
  if (details) console.log(`   Details: ${JSON.stringify(details, null, 2)}`);
};

async function runDebug() {
  console.log("=== AUTHENTICATED BROKER RLS DEBUG ===\n");
  
  const findings = [];
  let brokerUserId = null;
  let sessionToken = null;

  try {
    // Step 1: Test user authentication
    log("1️⃣  AUTH: Sign in test broker", `Email: ${TEST_BROKER_EMAIL}`);
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: TEST_BROKER_EMAIL,
      password: TEST_BROKER_PASSWORD,
    });

    if (authError) {
      log("❌ AUTH FAILED", authError.message);
      findings.push("BLOCKED: User not found or invalid credentials");
      findings.push(`Error: ${authError.message}`);
      throw authError;
    }

    brokerUserId = authData.user.id;
    sessionToken = authData.session.access_token;
    log("✅ AUTH SUCCESS", `User ID: ${brokerUserId}`);
    findings.push(`✅ User authenticated: ${brokerUserId}`);

    // Create authenticated client
    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${sessionToken}`,
        },
      },
    });

    // Step 2: Check auth.users directly (as anon, will fail, but shows RLS)
    log("2️⃣  AUTH.USERS: Check if user exists in Supabase Auth");
    
    const { data: authUsers, error: authUsersError } = await supabase
      .from('auth.users')
      .select('id,email,created_at')
      .eq('id', brokerUserId)
      .single();

    if (authUsersError) {
      log("ℹ️  AUTH.USERS BLOCKED", `RLS prevents anon access: ${authUsersError.message}`);
      findings.push("ℹ️  auth.users RLS working correctly (blocks anon query)");
    } else {
      log("✅ AUTH.USERS READABLE", `Email: ${authUsers?.email}`);
      findings.push(`✅ auth.users accessible: ${authUsers?.email}`);
    }

    // Step 3: Check role_assignments
    log("3️⃣  ROLE_ASSIGNMENTS: Check role mapping");
    
    const { data: roleAssign, error: roleError } = await authClient
      .from('role_assignments')
      .select('*')
      .eq('user_id', brokerUserId)
      .single();

    if (roleError) {
      log("❌ ROLE_ASSIGNMENTS NOT FOUND", roleError.message);
      findings.push("BLOCKED: No role assignment for this user");
      findings.push(`Query error: ${roleError.message}`);
    } else if (!roleAssign) {
      log("❌ NO ROLE FOUND", `User ${brokerUserId} has no role`);
      findings.push("BLOCKED: role_assignments table empty for user");
    } else {
      log("✅ ROLE FOUND", `Role: ${roleAssign.role_type}`);
      findings.push(`✅ Role assigned: ${roleAssign.role_type}`);
    }

    // Step 4: Check pilot_users status
    log("4️⃣  PILOT_USERS: Check activation status");
    
    const { data: pilotUser, error: pilotError } = await authClient
      .from('pilot_users')
      .select('status,created_at')
      .eq('user_id', brokerUserId)
      .single();

    if (pilotError) {
      log("⚠️  PILOT_USERS ERROR", pilotError.message);
      findings.push(`⚠️  pilot_users query failed: ${pilotError.message}`);
    } else if (pilotUser?.status !== 'active') {
      log("❌ PILOT USER NOT ACTIVE", `Status: ${pilotUser?.status}`);
      findings.push(`BLOCKED: pilot_users.status = ${pilotUser?.status} (not 'active')`);
    } else {
      log("✅ PILOT USER ACTIVE", `Status: active`);
      findings.push("✅ pilot_users.status = active");
    }

    // Step 5: Check brokers_public linkage
    log("5️⃣  BROKERS_PUBLIC: Check broker profile");
    
    const { data: brokerProfiles, error: brokerError } = await authClient
      .from('brokers_public')
      .select('id,owner_user_id,organization_id,company')
      .eq('owner_user_id', brokerUserId);

    if (brokerError) {
      log("❌ BROKERS_PUBLIC ERROR", brokerError.message);
      findings.push(`BLOCKED: brokers_public query failed: ${brokerError.message}`);
    } else if (!brokerProfiles || brokerProfiles.length === 0) {
      log("❌ NO BROKER PROFILE", `User ${brokerUserId} has no broker record`);
      findings.push("BLOCKED: No broker profile in brokers_public table");
    } else {
      const broker = brokerProfiles[0];
      log("✅ BROKER PROFILE FOUND", `Broker ID: ${broker.id}, Company: ${broker.company}`);
      findings.push(`✅ Broker profile linked: ${broker.company}`);
      findings.push(`   - broker_id: ${broker.id}`);
      findings.push(`   - owner_user_id: ${broker.owner_user_id}`);
      findings.push(`   - organization_id: ${broker.organization_id}`);
    }

    // Step 6: Test is_linked_broker_user() function
    log("6️⃣  FUNCTION: Test is_linked_broker_user()");
    
    const { data: isLinked, error: linkedError } = await authClient.rpc('is_linked_broker_user', {
      p_user_id: brokerUserId,
    });

    if (linkedError) {
      log("❌ FUNCTION ERROR", linkedError.message);
      findings.push(`BLOCKED: is_linked_broker_user() failed: ${linkedError.message}`);
    } else if (!isLinked) {
      log("❌ NOT LINKED", `Function returned: ${isLinked}`);
      findings.push("BLOCKED: is_linked_broker_user() returned false");
    } else {
      log("✅ LINKED BROKER", `Function returned: true`);
      findings.push("✅ is_linked_broker_user(user_id) = true");
    }

    // Step 7: Check RLS policies on leads_public
    log("7️⃣  RLS POLICIES: Inspect leads_public policies");
    
    // Try to read leads_public as authenticated
    const { data: existingLeads, error: listError } = await authClient
      .from('leads_public')
      .select('id,alias,broker_id')
      .limit(5);

    if (listError) {
      log("❌ READ POLICY BLOCKED", listError.message);
      findings.push(`⚠️  SELECT policy issue: ${listError.message}`);
    } else {
      log("✅ READ POLICY WORKS", `Found ${existingLeads?.length || 0} leads`);
      findings.push("✅ SELECT policy: Authenticated can read");
    }

    // Step 8: Try direct insert to leads_public (should fail)
    log("8️⃣  RLS TEST: Direct insert to leads_public (should fail)");
    
    const { error: directInsertError } = await authClient
      .from('leads_public')
      .insert([{
        alias: 'TEST_DIRECT_INSERT',
        area: 'Test',
        city: 'Test',
        property_name: 'Test',
      }]);

    if (directInsertError) {
      log("✅ DIRECT INSERT BLOCKED", `RLS working: ${directInsertError.message}`);
      findings.push("✅ INSERT policy: Direct insert blocked (RLS working)");
      findings.push(`   Reason: ${directInsertError.message}`);
    } else {
      log("🚨 DIRECT INSERT ALLOWED", "Security risk!");
      findings.push("🚨 SECURITY RISK: Direct insert allowed (RLS broken)");
    }

    // Step 9: Try calling broker-upload-lead Edge Function
    log("9️⃣  EDGE FUNCTION: Call broker-upload-lead");
    
    const { data: leadResponse, error: functionError } = await authClient.functions.invoke('broker-upload-lead', {
      body: {
        alias: 'UAT_BROKER_TEST',
        phone: '+919988776655',
        area: 'Test Area',
        city: 'Mumbai',
        property_name: 'Test Property',
        budget_min: 5000000,
        budget_max: 10000000,
      },
    });

    if (functionError) {
      log("❌ FUNCTION FAILED", functionError.message);
      findings.push(`BLOCKED: broker-upload-lead function error: ${functionError.message}`);
      findings.push(`   Status: ${functionError.status}`);
    } else if (!leadResponse?.lead_id) {
      log("❌ INVALID RESPONSE", "Function returned no lead_id");
      findings.push("BLOCKED: Function did not return lead_id");
    } else {
      log("✅ FUNCTION SUCCESS", `Lead ID: ${leadResponse.lead_id}`);
      findings.push(`✅ broker-upload-lead succeeded: ${leadResponse.lead_id}`);
      findings.push(`   - Alias: ${leadResponse.alias}`);
      findings.push(`   - Phone visible: ${leadResponse.phone_ciphertext ? 'NO (encrypted)' : 'YES (ERROR!)'}`);
      
      // Try to verify the lead was created
      const { data: newLead } = await authClient
        .from('leads_public')
        .select('*')
        .eq('id', leadResponse.lead_id)
        .single();
      
      if (newLead) {
        findings.push(`   - Lead verified in database ✅`);
      }
    }

    // Step 10: Check audit trail
    log("🔟 AUDIT TRAIL: Check if action logged");
    
    const { data: auditEvents } = await authClient
      .from('audit_events')
      .select('*')
      .eq('actor_id', brokerUserId)
      .order('created_at', { ascending: false })
      .limit(5);

    if (auditEvents && auditEvents.length > 0) {
      log("✅ AUDIT LOGGED", `Found ${auditEvents.length} event(s)`);
      findings.push(`✅ Audit trail: ${auditEvents.length} event(s) recorded`);
      auditEvents.slice(0, 2).forEach(e => {
        findings.push(`   - ${e.event_type} at ${new Date(e.created_at).toLocaleString()}`);
      });
    } else {
      log("ℹ️  NO AUDIT EVENTS", "May appear after trigger execution");
      findings.push("ℹ️  No audit events yet (may appear after trigger)");
    }

  } catch (error) {
    log("❌ DEBUG FAILED", error.message);
    findings.push(`FATAL ERROR: ${error.message}`);
  }

  // Summary
  console.log("\n" + "=".repeat(60));
  console.log("FINDINGS SUMMARY");
  console.log("=".repeat(60));
  findings.forEach(f => console.log(`• ${f}`));

  // Determine verdict
  let verdict = "PASS";
  if (findings.some(f => f.includes("BLOCKED"))) {
    verdict = "BLOCKED — ISSUE FOUND";
  } else if (findings.some(f => f.includes("SECURITY RISK"))) {
    verdict = "BLOCKED — SECURITY RISK";
  }

  console.log("\n" + "=".repeat(60));
  console.log(`VERDICT: ${verdict}`);
  console.log("=".repeat(60) + "\n");

  return {
    verdict,
    findings,
    brokerUserId,
    timestamp: new Date().toISOString(),
  };
}

runDebug().catch(err => {
  console.error("\n❌ DEBUG SCRIPT FAILED:", err.message);
  process.exit(1);
});
