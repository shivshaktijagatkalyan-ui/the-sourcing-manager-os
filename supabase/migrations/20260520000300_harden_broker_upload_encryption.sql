-- Replace the broker upload RPC placeholder cipher with production encryption.
-- This migration intentionally overrides the earlier function instead of editing
-- historical migration files.

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
  IF NOT public.broker_can_insert_lead(auth.uid()) THEN
    RAISE EXCEPTION 'User is not an active broker';
  END IF;

  SELECT bp.id, bp.organization_id
  INTO v_broker_id, v_org_id
  FROM public.brokers_public bp
  JOIN public.pilot_users pu
    ON pu.user_id = auth.uid()
   AND pu.org_id = bp.organization_id
   AND pu.status = 'active'
  WHERE bp.owner_user_id = auth.uid()
    AND coalesce(bp.status, 'active') = 'active'
  LIMIT 1;

  IF v_broker_id IS NULL OR v_org_id IS NULL THEN
    RAISE EXCEPTION 'No broker profile linked to user';
  END IF;

  BEGIN
    v_encryption_key := public.get_production_vault_secret('PHONE_ENCRYPTION_KEY');
  EXCEPTION WHEN others THEN
    v_encryption_key := current_setting('app.phone_encryption_key', true);
  END;

  IF v_encryption_key IS NULL OR length(v_encryption_key) < 32 THEN
    RAISE EXCEPTION 'encryption_key_invalid';
  END IF;

  INSERT INTO public.leads_public (
    organization_id,
    broker_id,
    source_broker_id,
    alias,
    area,
    city,
    property_name,
    budget_min,
    budget_max,
    lead_status,
    consent_status,
    dnd_status
  )
  VALUES (
    v_org_id,
    auth.uid(),
    v_broker_id,
    p_alias,
    p_area,
    p_city,
    p_property_name,
    p_budget_min,
    p_budget_max,
    'new',
    'pending',
    'unknown'
  )
  RETURNING id INTO v_lead_id;

  v_phone_ciphertext := public.encrypt_lead_contact(p_phone, v_encryption_key);

  INSERT INTO public.leads_sensitive (
    lead_id,
    phone_ciphertext,
    encryption_version
  )
  VALUES (
    v_lead_id,
    v_phone_ciphertext,
    1
  );

  INSERT INTO public.audit_events (
    actor_id,
    lead_id,
    event_type,
    event_context
  )
  VALUES (
    auth.uid(),
    v_lead_id,
    'lead_uploaded_by_broker',
    jsonb_build_object('alias', p_alias, 'area', p_area, 'city', p_city)
  );

  RETURN QUERY SELECT v_lead_id, p_alias, now();
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_broker_upload_lead(text, text, text, text, text, numeric, numeric)
FROM anon, public;

GRANT EXECUTE ON FUNCTION public.rpc_broker_upload_lead(text, text, text, text, text, numeric, numeric)
TO authenticated;

COMMENT ON FUNCTION public.rpc_broker_upload_lead(text, text, text, text, text, numeric, numeric)
IS 'Broker lead upload RPC with PII encrypted via pgcrypto-backed FutureTrust Lead Vault routines.';
