-- MIGRATION: Fix Authenticated Broker RLS Issues
-- Date: 2026-05-18
-- Purpose: Add missing schema elements for broker-to-user linking

-- ============================================================
-- FIX #1: Add missing owner_user_id column to brokers_public
-- ============================================================

ALTER TABLE public.brokers_public
ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id);

CREATE INDEX IF NOT EXISTS idx_brokers_public_owner_user_id
ON public.brokers_public(owner_user_id);

CREATE INDEX IF NOT EXISTS idx_brokers_public_organization_id
ON public.brokers_public(organization_id);

-- ============================================================
-- FIX #2: Create is_linked_broker_user() function
-- Purpose: Check if authenticated user owns a broker profile
-- ============================================================

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

-- Alternative single-param version for backward compatibility
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

-- ============================================================
-- FIX #3: Verify/Create has_active_data_loan() function
-- Purpose: Check if user has valid data loan for a lead
-- ============================================================

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

-- ============================================================
-- FIX #4: Add broker RLS policy for authenticated leads insert
-- Purpose: Allow authenticated brokers to insert leads via RPC
-- ============================================================

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

-- Add INSERT policy for broker-owned leads
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

-- ============================================================
-- FIX #5: Update leads_public RLS policies to handle missing functions gracefully
-- ============================================================

DROP POLICY IF EXISTS leads_public_active_loan_read ON public.leads_public;
CREATE POLICY leads_public_active_loan_read
ON public.leads_public
FOR SELECT
TO authenticated
USING (
  public.has_active_data_loan(id, auth.uid(), 'call')
  OR public.has_active_data_loan(id, auth.uid(), 'site_visit')
  OR broker_id = (
    SELECT bp.id FROM public.brokers_public bp 
    WHERE bp.owner_user_id = auth.uid() LIMIT 1
  )
);

-- ============================================================
-- FIX #6: Create helper function to get broker by user
-- ============================================================

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

-- ============================================================
-- FIX #7: Create RPC for broker lead upload (bypass direct insert)
-- This ensures all business logic runs through service_role
-- ============================================================

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
  v_org_id uuid;
  v_lead_id uuid;
  v_phone_ciphertext text;
  v_encryption_key text;
BEGIN
  -- 1. Verify user is active broker
  IF NOT public.broker_can_insert_lead(auth.uid()) THEN
    RAISE EXCEPTION 'User is not an active broker';
  END IF;

  -- 2. Get broker profile
  SELECT bp.id, bp.organization_id
  INTO v_broker_id, v_org_id
  FROM public.brokers_public bp
  JOIN public.pilot_users pu
    ON pu.user_id = auth.uid()
   AND pu.org_id = bp.organization_id
   AND pu.status = 'active'
  WHERE bp.owner_user_id = auth.uid()
  LIMIT 1;

  IF v_broker_id IS NULL OR v_org_id IS NULL THEN
    RAISE EXCEPTION 'No broker profile linked to user';
  END IF;

  -- 3. Insert into leads_public
  INSERT INTO public.leads_public (
    organization_id, broker_id, source_broker_id, alias, area, city, property_name,
    budget_min, budget_max, lead_status, consent_status, dnd_status
  )
  VALUES (
    v_org_id, auth.uid(), v_broker_id, p_alias, p_area, p_city, p_property_name,
    p_budget_min, p_budget_max, 'new', 'pending', 'unknown'
  )
  RETURNING id INTO v_lead_id;

  -- 4. Encrypt and store phone through the Lead Vault cipher helper.
  -- The key must be supplied through a protected database setting for local
  -- migrations; later production migrations can source it from Supabase Vault.
  v_encryption_key := current_setting('app.phone_encryption_key', true);
  IF v_encryption_key IS NULL OR length(v_encryption_key) < 32 THEN
    RAISE EXCEPTION 'encryption_key_invalid';
  END IF;

  v_phone_ciphertext := public.encrypt_lead_contact(p_phone, v_encryption_key);

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

-- ============================================================
-- DONE
-- ============================================================
