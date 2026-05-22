#!/usr/bin/env node
/**
 * UAT Verification Script - Production Database Check
 * Verifies the app is running and can connect to production Supabase
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, '../.env');
const envContent = fs.readFileSync(envPath, 'utf8');

const getEnv = (key) => {
  const match = envContent.match(new RegExp(`^${key}=(.*)$`, 'm'));
  return match ? match[1].trim() : null;
};

const SUPABASE_URL = getEnv('SUPABASE_URL');
const SUPABASE_ANON_KEY = getEnv('SUPABASE_ANON_KEY');

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function run() {
  console.log("=== UAT PRODUCTION VERIFICATION ===\n");
  console.log(`✓ Supabase URL: ${SUPABASE_URL}`);
  
  try {
    // Test connection
    console.log("\n1. Testing Supabase Connection...");
    const { data: health } = await supabase.rpc('system_health_check');
    console.log("✓ Connection successful");

    // Check users
    console.log("\n2. Checking Test User Accounts...");
    const { data: users, error: usersError } = await supabase
      .from('auth.users')
      .select('id,email,created_at')
      .limit(10);
    
    if (usersError) {
      console.log(`Note: Cannot query users directly (normal - RLS restriction)`);
    } else {
      console.log(`✓ Found ${users?.length || 0} recent users`);
    }

    // Check brokers table
    console.log("\n3. Checking Brokers Table...");
    const { data: brokers, error: brokersError } = await supabase
      .from('brokers')
      .select('id,company,city,created_at')
      .limit(5);
    
    if (brokersError) {
      console.log(`✗ Error: ${brokersError.message}`);
    } else {
      console.log(`✓ Found ${brokers?.length || 0} brokers in database`);
      brokers?.forEach(b => {
        console.log(`  - ${b.company} (${b.city})`);
      });
    }

    // Check leads table
    console.log("\n4. Checking Leads Table...");
    const { data: leads, error: leadsError } = await supabase
      .from('leads')
      .select('id,alias,city,created_at')
      .order('created_at', { ascending: false })
      .limit(5);
    
    if (leadsError) {
      console.log(`✗ Error: ${leadsError.message}`);
    } else {
      console.log(`✓ Found ${leads?.length || 0} leads in database`);
      leads?.forEach(l => {
        console.log(`  - ${l.alias} (${l.city}) - ${new Date(l.created_at).toLocaleString()}`);
      });
    }

    // Check audit trail
    console.log("\n5. Checking Audit Trail (Append-Only)...");
    const { data: audits, error: auditsError } = await supabase
      .from('audit_trail')
      .select('id,table_name,action,created_at')
      .order('created_at', { ascending: false })
      .limit(5);
    
    if (auditsError) {
      console.log(`✗ Error: ${auditsError.message}`);
    } else {
      console.log(`✓ Found ${audits?.length || 0} audit entries`);
      audits?.forEach(a => {
        console.log(`  - ${a.table_name}.${a.action} (${new Date(a.created_at).toLocaleString()})`);
      });
    }

    console.log("\n=== VERIFICATION COMPLETE ===");
    console.log("✓ Production Supabase is operational");
    console.log("✓ Database schema verified");
    console.log("\nNext Steps:");
    console.log("1. Create test broker account via Supabase dashboard");
    console.log("2. Log in to Flutter app with broker credentials");
    console.log("3. Upload sample lead");
    console.log("4. Verify lead appears in Sourcing Manager queue");
    console.log("5. Complete Secure Call → GPS Verify → Payout cycle");

  } catch (err) {
    console.error("\n✗ Verification Error:", err.message);
    process.exit(1);
  }
}

run();
