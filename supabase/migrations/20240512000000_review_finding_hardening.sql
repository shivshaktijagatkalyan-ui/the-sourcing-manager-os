-- Review finding hardening: enforce real state transitions and strict enterprise permissions.
-- This migration intentionally redefines existing RPCs so deployed databases receive the fix.

CREATE OR REPLACE FUNCTION public.has_strict_enterprise_permission(
  p_user_id uuid,
  p_permission text,
  p_org_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.role_assignments ra
    JOIN public.permission_templates pt
      ON pt.id = ra.permission_template_id
     AND pt.organization_id = ra.organization_id
    JOIN public.permission_template_permissions ptp
      ON ptp.template_id = pt.id
    JOIN public.pilot_users pu
      ON pu.user_id = ra.user_id
     AND pu.org_id = ra.organization_id
    JOIN public.organizations o
      ON o.id = ra.organization_id
    WHERE ra.user_id = p_user_id
      AND ra.status = 'active'
      AND pt.status = 'active'
      AND ptp.permission_id = p_permission
      AND pu.status = 'active'
      AND o.status = 'active'
      AND NOT public.has_active_suspension(p_user_id)
      AND (
        p_org_id IS NULL
        OR ra.organization_id = p_org_id
        OR ra.role_id = 'platform_admin'
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.verify_site_gps_v2(
  p_visit_id uuid,
  p_actor_id uuid,
  p_is_inside boolean,
  p_lat numeric,
  p_lng numeric,
  p_accuracy numeric,
  p_distance numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row_count integer;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_id::text, true);

  UPDATE public.site_visits
  SET
    gps_status = CASE WHEN p_is_inside THEN 'verified' ELSE 'rejected' END,
    submitted_lat = p_lat,
    submitted_lng = p_lng,
    gps_accuracy_meters = p_accuracy,
    distance_from_project_meters = p_distance,
    gps_verified_at = CASE WHEN p_is_inside THEN now() ELSE NULL END,
    status = CASE WHEN p_is_inside THEN 'gps_verified' ELSE 'invalid' END
  WHERE id = p_visit_id
    AND sourcing_manager_id = p_actor_id
    AND status IN ('scheduled', 'started');

  GET DIAGNOSTICS v_row_count = ROW_COUNT;

  IF v_row_count = 1 THEN
    RETURN jsonb_build_object('ok', true);
  END IF;

  RETURN jsonb_build_object('ok', false, 'reason', 'invalid_state');
END;
$$;

CREATE OR REPLACE FUNCTION public.upload_site_photo_v2(
  p_visit_id uuid,
  p_actor_id uuid,
  p_photo_sha256 text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row_count integer;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_id::text, true);

  UPDATE public.site_visits
  SET
    photo_sha256 = p_photo_sha256,
    photo_uploaded_at = now(),
    photo_verification_status = 'verified',
    status = 'photo_verified'
  WHERE id = p_visit_id
    AND sourcing_manager_id = p_actor_id
    AND status = 'gps_verified';

  GET DIAGNOSTICS v_row_count = ROW_COUNT;

  IF v_row_count = 1 THEN
    RETURN jsonb_build_object('ok', true);
  END IF;

  RETURN jsonb_build_object('ok', false, 'reason', 'invalid_state');
END;
$$;

CREATE OR REPLACE FUNCTION public.broker_review_site_visit_v2(
  p_visit_id uuid,
  p_actor_id uuid,
  p_action text,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row_count integer;
BEGIN
  IF p_action NOT IN ('approve', 'reject') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_input');
  END IF;

  PERFORM set_config('app.current_user_id', p_actor_id::text, true);

  UPDATE public.site_visits
  SET
    broker_review_status = CASE WHEN p_action = 'approve' THEN 'approved' ELSE 'rejected' END,
    broker_reviewed_at = now(),
    broker_rejection_reason = CASE WHEN p_action = 'reject' THEN p_reason ELSE NULL END,
    status = CASE WHEN p_action = 'approve' THEN 'completed' ELSE 'invalid' END
  WHERE id = p_visit_id
    AND broker_id = p_actor_id
    AND status = 'photo_verified';

  GET DIAGNOSTICS v_row_count = ROW_COUNT;

  IF v_row_count = 1 THEN
    RETURN jsonb_build_object('ok', true);
  END IF;

  RETURN jsonb_build_object('ok', false, 'reason', 'invalid_state');
END;
$$;

REVOKE ALL ON FUNCTION public.has_strict_enterprise_permission(uuid, text, uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.has_strict_enterprise_permission(uuid, text, uuid) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.verify_site_gps_v2(uuid, uuid, boolean, numeric, numeric, numeric, numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.upload_site_photo_v2(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.broker_review_site_visit_v2(uuid, uuid, text, text) TO service_role;
