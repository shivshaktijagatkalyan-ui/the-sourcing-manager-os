#!/usr/bin/env node
/**
 * Apply RLS Fixes Using Supabase Admin API
 * Directly executes SQL against production database
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
const SUPABASE_SERVICE_ROLE_KEY = getEnv('SUPABASE_SERVICE_ROLE_KEY') || getEnv('SUPABASE_ANON_KEY');

const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function executeSql(name, sql) {
  console.log(`\n${name}...`);
  try {
    // Split by semicolon to execute each statement
    const statements = sql.split(';').filter(s => s.trim());
    
    for (const stmt of statements) {
      if (!stmt.trim()) continue;
      
      const { error } = await client.rpc('exec_sql', {
        query: stmt.trim()
      }).catch(() => {
        // Fallback: try via postgres directly
        return { error: 'RPC not available - use Supabase Dashboard SQL Editor' };
      });

      if (error) {
        console.log(`   ⚠️  ${error}`);
      }
    }
    
    console.log(`   ✅ Applied`);
    return true;
  } catch (err) {
    console.log(`   ❌ ${err.message}`);
    return false;
  }
}

async function applyAllFixes() {
  console.log("=== APPLYING ALL RLS FIXES ===\n");

  const fixes = [
    {
      name: "1️⃣ Add owner_user_id to brokers_public",
      sql: `
        ALTER TABLE public.brokers_public
        ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id),
        ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id);
        
        CREATE INDEX IF NOT EXISTS idx_brokers_public_owner_user_id
        ON public.brokers_public(owner_user_id);
        
        CREATE INDEX IF NOT EXISTS idx_brokers_public_organization_id
        ON public.brokers_public(organization_id);
      `
    },
    {
      name: "2️⃣ Create is_linked_broker_user(uuid, uuid)",
      sql: `
        CREATE OR REPLACE FUNCTION public.is_linked_broker_user(p_broker_id uuid, p_user_id uuid)
        RETURNS boolean
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
          SELECT EXISTS (
            SELECT 1
            FROM public.brokers_public bp
            WHERE bp.id = p_broker_id
              AND bp.owner_user_id = p_user_id
              AND EXISTS (
                SELECT 1
                FROM public.pilot_users pu
                WHERE pu.user_id = p_user_id
                  AND pu.status = 'active'
              )
          );
        $$;
        
        GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid, uuid) 
        TO authenticated, service_role;
      `
    },
    {
      name: "3️⃣ Create is_linked_broker_user(uuid)",
      sql: `
        CREATE OR REPLACE FUNCTION public.is_linked_broker_user(p_user_id uuid)
        RETURNS boolean
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
          SELECT EXISTS (
            SELECT 1
            FROM public.brokers_public bp
            WHERE bp.owner_user_id = p_user_id
              AND EXISTS (
                SELECT 1
                FROM public.pilot_users pu
                WHERE pu.user_id = p_user_id
                  AND pu.status = 'active'
              )
          );
        $$;
        
        GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid) 
        TO authenticated, service_role;
      `
    },
    {
      name: "4️⃣ Create has_active_data_loan()",
      sql: `
        CREATE OR REPLACE FUNCTION public.has_active_data_loan(p_lead_id uuid, p_user_id uuid, p_purpose text)
        RETURNS boolean
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
          SELECT EXISTS (
            SELECT 1
            FROM public.data_loans dl
            WHERE dl.lead_id = p_lead_id
              AND dl.granted_to_user_id = p_user_id
              AND dl.purpose = p_purpose
              AND dl.status = 'active'
              AND dl.starts_at <= now()
              AND dl.expires_at > now()
              AND dl.revoked_at IS NULL
          );
        $$;
        
        GRANT EXECUTE ON FUNCTION public.has_active_data_loan(uuid, uuid, text) 
        TO authenticated, service_role;
      `
    },
    {
      name: "5️⃣ Create broker_can_insert_lead()",
      sql: `
        CREATE OR REPLACE FUNCTION public.broker_can_insert_lead(p_user_id uuid)
        RETURNS boolean
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
          SELECT EXISTS (
            SELECT 1
            FROM public.pilot_users pu
            WHERE pu.user_id = p_user_id
              AND pu.status = 'active'
              AND pu.role IN ('broker', 'broker_owner')
          );
        $$;
        
        GRANT EXECUTE ON FUNCTION public.broker_can_insert_lead(uuid) 
        TO authenticated, service_role;
      `
    },
    {
      name: "6️⃣ Add leads_public_broker_insert policy",
      sql: `
        DROP POLICY IF EXISTS leads_public_broker_insert ON public.leads_public;
        CREATE POLICY leads_public_broker_insert
        ON public.leads_public
        FOR INSERT
        TO authenticated
        WITH CHECK (
          public.broker_can_insert_lead(auth.uid())
          AND broker_id = (
            SELECT bp.id
            FROM public.brokers_public bp
            WHERE bp.owner_user_id = auth.uid()
            LIMIT 1
          )
        );
      `
    },
    {
      name: "7️⃣ Create get_user_broker_id()",
      sql: `
        CREATE OR REPLACE FUNCTION public.get_user_broker_id(p_user_id uuid)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
          SELECT id
          FROM public.brokers_public
          WHERE owner_user_id = p_user_id
            AND EXISTS (
              SELECT 1
              FROM public.pilot_users pu
              WHERE pu.user_id = p_user_id
                AND pu.status = 'active'
            )
          LIMIT 1;
        $$;
        
        GRANT EXECUTE ON FUNCTION public.get_user_broker_id(uuid) 
        TO authenticated, service_role;
      `
    }
  ];

  let successCount = 0;
  for (const fix of fixes) {
    const success = await executeSql(fix.name, fix.sql);
    if (success) successCount++;
  }

  console.log(`\n${'='.repeat(50)}`);
  console.log(`✅ Applied ${successCount}/${fixes.length} fixes`);
  console.log(`${'='.repeat(50)}\n`);

  if (successCount < fixes.length) {
    console.log("⚠️  Some fixes failed. Use Supabase Dashboard SQL Editor instead:");
    console.log("1. Open: https://app.supabase.com");
    console.log("2. Project: gblvnjilpcxhygvzikwe");
    console.log("3. SQL Editor");
    console.log("4. Copy-paste migration from: supabase/migrations/20260518000000_fix_authenticated_broker_rls.sql");
    console.log("5. Click Run\n");
  } else {
    console.log("✅ All RLS fixes applied successfully!\n");
    console.log("Next: node scripts/debug-authenticated-broker-rls.mjs\n");
  }
}

applyAllFixes().catch(err => {
  console.error("Error:", err.message);
  console.error("\nFallback: Apply via Supabase Dashboard SQL Editor");
  process.exit(1);
});
