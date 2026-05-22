#!/usr/bin/env node
/**
 * Apply RLS Fixes Directly to Production Supabase
 * Executes the 7 fixes needed to unblock authenticated broker lead upload
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
const SUPABASE_SERVICE_ROLE_KEY = getEnv('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ ERROR: SUPABASE_SERVICE_ROLE_KEY not found in .env');
  console.error('   This is required to apply schema changes.');
  console.error('   Add it to your .env file:');
  console.error('   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const fixes = [
  {
    name: "Add owner_user_id column to brokers_public",
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
    name: "Create is_linked_broker_user() function (2-param version)",
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
                AND pu.role IN ('broker', 'broker_owner')
            )
        );
      $$;
      
      GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid, uuid) 
      TO authenticated, service_role;
    `
  },
  {
    name: "Create is_linked_broker_user() function (1-param version)",
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
                AND pu.role IN ('broker', 'broker_owner')
            )
        );
      $$;
      
      GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid) 
      TO authenticated, service_role;
    `
  },
  {
    name: "Create has_active_data_loan() function",
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
    name: "Create broker_can_insert_lead() helper function",
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
    name: "Add INSERT policy for brokers on leads_public",
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
    name: "Create get_user_broker_id() helper function",
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
  },
  {
    name: "Create rpc_broker_upload_lead() RPC function",
    sql: `
      CREATE OR REPLACE FUNCTION public.rpc_broker_upload_lead(
        p_alias text,
        p_phone text,
        p_area text,
        p_city text,
        p_property_name text,
        p_budget_min numeric,
        p_budget_max numeric
      )
      RETURNS TABLE (
        lead_id uuid,
        alias text,
        created_at timestamptz
      )
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public
      AS $$
      DECLARE
        v_broker_id uuid;
        v_lead_id uuid;
        v_phone_ciphertext text;
      BEGIN
        -- 1. Verify user is active broker
        IF NOT public.broker_can_insert_lead(auth.uid()) THEN
          RAISE EXCEPTION 'User is not an active broker';
        END IF;

        -- 2. Get broker profile
        SELECT id INTO v_broker_id
        FROM public.brokers_public
        WHERE owner_user_id = auth.uid()
          AND EXISTS (
            SELECT 1 FROM public.pilot_users pu
            WHERE pu.user_id = auth.uid() AND pu.status = 'active'
          )
        LIMIT 1;

        IF v_broker_id IS NULL THEN
          RAISE EXCEPTION 'No broker profile linked to user';
        END IF;

        -- 3. Insert into leads_public
        INSERT INTO public.leads_public (
          broker_id, alias, area, city, property_name,
          budget_min, budget_max, lead_status, consent_status, dnd_status
        )
        VALUES (
          v_broker_id, p_alias, p_area, p_city, p_property_name,
          p_budget_min, p_budget_max, 'new', 'pending', 'unknown'
        )
        RETURNING id INTO v_lead_id;

        -- 4. Encrypt and store phone (base64 placeholder)
        v_phone_ciphertext := encode(convert(p_phone::bytea, 'UTF8'::name, 'UTF8'::name), 'base64');

        INSERT INTO public.leads_sensitive (
          lead_id, phone_ciphertext, encryption_version
        )
        VALUES (
          v_lead_id, v_phone_ciphertext, 1
        );

        -- 5. Log audit event
        INSERT INTO public.audit_events (
          actor_id, lead_id, event_type, event_context
        )
        VALUES (
          auth.uid(), v_lead_id, 'lead_uploaded_by_broker',
          jsonb_build_object('alias', p_alias, 'area', p_area, 'city', p_city)
        );

        -- 6. Return only lead_id and alias (no phone)
        RETURN QUERY SELECT v_lead_id, p_alias, now();
      END;
      $$;

      GRANT EXECUTE ON FUNCTION public.rpc_broker_upload_lead(text, text, text, text, text, numeric, numeric)
      TO authenticated;
    `
  }
];

async function applyFixes() {
  console.log("=== APPLYING RLS FIXES ===\n");
  
  let successCount = 0;
  let failureCount = 0;

  for (const fix of fixes) {
    console.log(`Applying: ${fix.name}...`);
    
    try {
      const { error } = await supabase.rpc('exec', {
        sql_string: fix.sql
      }).catch(async () => {
        // Fallback: try direct SQL via a different method
        // Since exec might not exist, we'll try via a custom function
        console.log(`   (Using alternative method...)`);
        // For now, just report it couldn't execute
        return { error: 'Could not execute - use Supabase CLI instead' };
      });

      if (error) {
        console.log(`   ⚠️  ${error}`);
        failureCount++;
      } else {
        console.log(`   ✅ Applied`);
        successCount++;
      }
    } catch (err) {
      console.log(`   ❌ Error: ${err.message}`);
      failureCount++;
    }
  }

  console.log(`\n✅ ${successCount} fixes applied`);
  console.log(`⚠️  ${failureCount} fixes need manual execution\n`);

  console.log("=== NEXT STEPS ===\n");
  console.log("1. If you have Supabase CLI access:");
  console.log("   supabase db push\n");
  console.log("2. If using Supabase Dashboard:");
  console.log("   Copy the SQL from supabase/migrations/20260518000000_fix_authenticated_broker_rls.sql");
  console.log("   Paste into SQL Editor in Supabase Dashboard");
  console.log("   Execute\n");
  console.log("3. After applying fixes:");
  console.log("   node scripts/debug-authenticated-broker-rls.mjs\n");
}

applyFixes().catch(err => {
  console.error("❌ Error:", err.message);
  console.error("\nFallback: Apply migrations manually using Supabase CLI:");
  console.error("  supabase db push");
  process.exit(1);
});
