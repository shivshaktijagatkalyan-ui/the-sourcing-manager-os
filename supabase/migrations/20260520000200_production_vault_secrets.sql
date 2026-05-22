-- FutureTrust production vault secret separation and offline sync fallback gates.
-- Secrets are stored in Supabase Vault and can be read only through security
-- definer routines granted to service_role.

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;

CREATE TABLE IF NOT EXISTS public.production_secret_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  secret_name text NOT NULL UNIQUE,
  vault_secret_id uuid NOT NULL,
  description text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  rotated_at timestamptz
);

ALTER TABLE public.production_secret_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_secret_registry FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS production_secret_registry_no_client_access
  ON public.production_secret_registry;
CREATE POLICY production_secret_registry_no_client_access
ON public.production_secret_registry
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.register_production_vault_secret(
  p_secret_name text,
  p_secret_value text,
  p_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_name text := btrim(coalesce(p_secret_name, ''));
  v_secret_id uuid;
BEGIN
  IF v_name = '' OR p_secret_value IS NULL OR length(p_secret_value) < 16 THEN
    RAISE EXCEPTION 'invalid_secret_input';
  END IF;

  SELECT id INTO v_secret_id
  FROM vault.decrypted_secrets
  WHERE name = v_name
  LIMIT 1;

  IF v_secret_id IS NULL THEN
    v_secret_id := vault.create_secret(p_secret_value, v_name, p_description);
  ELSE
    PERFORM vault.update_secret(v_secret_id, p_secret_value, v_name, p_description);
  END IF;

  INSERT INTO public.production_secret_registry (
    secret_name,
    vault_secret_id,
    description,
    created_by,
    rotated_at
  )
  VALUES (
    v_name,
    v_secret_id,
    p_description,
    auth.uid(),
    now()
  )
  ON CONFLICT (secret_name)
  DO UPDATE SET
    vault_secret_id = EXCLUDED.vault_secret_id,
    description = EXCLUDED.description,
    rotated_at = now();

  RETURN v_secret_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_production_vault_secret(
  p_secret_name text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  v_secret text;
BEGIN
  SELECT ds.decrypted_secret
  INTO v_secret
  FROM public.production_secret_registry psr
  JOIN vault.decrypted_secrets ds
    ON ds.id = psr.vault_secret_id
  WHERE psr.secret_name = btrim(coalesce(p_secret_name, ''))
  LIMIT 1;

  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'production_secret_not_found';
  END IF;

  RETURN v_secret;
END;
$$;

ALTER TABLE public.site_visits
  ADD COLUMN IF NOT EXISTS offline_sync_status text,
  ADD COLUMN IF NOT EXISTS offline_captured_at timestamptz,
  ADD COLUMN IF NOT EXISTS offline_synced_at timestamptz,
  ADD COLUMN IF NOT EXISTS offline_sync_reason text,
  ADD COLUMN IF NOT EXISTS delayed_sync_review_required boolean NOT NULL DEFAULT false;

ALTER TABLE public.site_visits
  DROP CONSTRAINT IF EXISTS site_visits_offline_sync_status_check;

ALTER TABLE public.site_visits
  ADD CONSTRAINT site_visits_offline_sync_status_check CHECK (
    offline_sync_status IS NULL
    OR offline_sync_status IN ('queued', 'synced', 'delayed_sync', 'held_for_admin_review')
  );

ALTER TABLE public.site_visits
  DROP CONSTRAINT IF EXISTS site_visits_status_check;

ALTER TABLE public.site_visits
  ADD CONSTRAINT site_visits_status_check CHECK (status IN (
    'proposed',
    'accepted',
    'scheduled',
    'client_reached_site',
    'gps_verified',
    'qr_verified',
    'photo_uploaded',
    'visit_done',
    'broker_review_pending',
    'completed',
    'no_show',
    'cancelled',
    'rejected',
    'arrived',
    'verified',
    'started',
    'gps_submitted',
    'photo_submitted',
    'photo_verified',
    'invalid',
    'disputed',
    'delayed_sync'
  ));

CREATE OR REPLACE FUNCTION public.apply_offline_site_visit_sync(
  p_visit_id uuid,
  p_actor_id uuid,
  p_is_inside boolean,
  p_lat numeric,
  p_lng numeric,
  p_accuracy numeric,
  p_distance numeric,
  p_captured_at timestamptz,
  p_synced_at timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visit public.site_visits%ROWTYPE;
  v_window_at timestamptz;
  v_delayed boolean;
BEGIN
  SELECT * INTO v_visit
  FROM public.site_visits
  WHERE id = p_visit_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'site_visit_not_found');
  END IF;

  IF v_visit.sourcing_manager_id IS DISTINCT FROM p_actor_id THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'forbidden_not_assigned');
  END IF;

  v_window_at := coalesce(v_visit.visit_date, v_visit.created_at + interval '24 hours');
  v_delayed := p_synced_at > (v_window_at + interval '2 hours');

  IF v_delayed THEN
    UPDATE public.site_visits
    SET
      status = 'delayed_sync',
      proof_status = 'partial',
      visit_lat = p_lat,
      visit_lng = p_lng,
      offline_sync_status = 'held_for_admin_review',
      offline_captured_at = p_captured_at,
      offline_synced_at = p_synced_at,
      offline_sync_reason = 'sync_after_visit_window',
      delayed_sync_review_required = true
    WHERE id = p_visit_id;

    INSERT INTO public.audit_events(actor_id, lead_id, event_type, event_context)
    VALUES (
      p_actor_id,
      v_visit.lead_id,
      'site_visit_delayed_sync_held',
      jsonb_build_object(
        'site_visit_id', p_visit_id,
        'distance_meters', p_distance,
        'accuracy_meters', p_accuracy,
        'captured_at', p_captured_at,
        'synced_at', p_synced_at
      )
    );

    RETURN jsonb_build_object('ok', false, 'reason', 'delayed_sync_held_for_admin_review');
  END IF;

  UPDATE public.site_visits
  SET
    visit_lat = p_lat,
    visit_lng = p_lng,
    status = CASE WHEN p_is_inside THEN 'gps_verified' ELSE 'invalid' END,
    proof_status = CASE WHEN p_is_inside THEN 'partial' ELSE proof_status END,
    offline_sync_status = 'synced',
    offline_captured_at = p_captured_at,
    offline_synced_at = p_synced_at,
    delayed_sync_review_required = false
  WHERE id = p_visit_id;

  RETURN jsonb_build_object('ok', p_is_inside, 'status', CASE WHEN p_is_inside THEN 'gps_verified' ELSE 'invalid' END);
END;
$$;

REVOKE ALL ON TABLE public.production_secret_registry FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.register_production_vault_secret(text, text, text) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.get_production_vault_secret(text) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.apply_offline_site_visit_sync(uuid, uuid, boolean, numeric, numeric, numeric, numeric, timestamptz, timestamptz) FROM anon, authenticated, public;

GRANT EXECUTE ON FUNCTION public.register_production_vault_secret(text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_production_vault_secret(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_offline_site_visit_sync(uuid, uuid, boolean, numeric, numeric, numeric, numeric, timestamptz, timestamptz) TO service_role;

COMMENT ON FUNCTION public.register_production_vault_secret(text, text, text)
IS 'Service-role only helper for moving provider tokens, API keys, HMAC secrets, and salts into Supabase Vault.';

COMMENT ON FUNCTION public.get_production_vault_secret(text)
IS 'Service-role only secret lookup for security definer routines and Edge Function RPC paths.';

COMMENT ON FUNCTION public.apply_offline_site_visit_sync(uuid, uuid, boolean, numeric, numeric, numeric, numeric, timestamptz, timestamptz)
IS 'Applies offline GPS sync when inside the allowed visit window; delayed syncs are held for Super Admin review.';
