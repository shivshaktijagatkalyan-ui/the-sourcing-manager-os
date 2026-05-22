#!/usr/bin/env node
/**
 * Apply RLS Fix Migration Only
 * Skips problematic pre-existing migrations
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '../.env');
const envContent = fs.readFileSync(envPath, 'utf8');

const getEnv = (key) => {
  const match = envContent.match(new RegExp(`^${key}=(.*)$`, 'm'));
  return match ? match[1].trim() : null;
};

const SUPABASE_URL = getEnv('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = getEnv('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function executeSql(sql) {
  try {
    const { data, error } = await client.rpc('exec', { sql });
    if (error) throw error;
    return { success: true, data };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

async function applyFix() {
  console.log('Applying RLS Fix...\n');

  const sqlFile = path.join(__dirname, '../supabase/migrations/20260518000000_fix_authenticated_broker_rls_CLEAN.sql');
  const sql = fs.readFileSync(sqlFile, 'utf8');

  // Split into individual statements
  const statements = sql.split(';').filter(s => s.trim());

  let success = 0;
  let failed = 0;

  for (const stmt of statements) {
    if (!stmt.trim()) continue;

    console.log(`Executing: ${stmt.substring(0, 60)}...`);
    
    const result = await executeSql(stmt.trim());
    if (result.success) {
      console.log('✅ Success\n');
      success++;
    } else {
      console.log(`❌ Failed: ${result.error}\n`);
      failed++;
    }
  }

  console.log(`\n${'='.repeat(50)}`);
  console.log(`✅ Success: ${success}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`${'='.repeat(50)}\n`);

  if (failed === 0) {
    console.log('🎉 All RLS fixes applied successfully!');
    console.log('\nNext: node scripts/debug-authenticated-broker-rls.mjs');
  } else {
    console.log('⚠️  Some fixes failed. Use Supabase Dashboard SQL Editor:');
    console.log('1. Paste SQL from supabase/migrations/20260518000000_fix_authenticated_broker_rls_CLEAN.sql');
    console.log('2. Run in SQL Editor');
  }

  process.exit(failed > 0 ? 1 : 0);
}

applyFix();
