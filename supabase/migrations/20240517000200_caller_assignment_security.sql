-- Secure caller assignment through a service-role RPC. This avoids direct
-- frontend mutation while preserving trigger-created data loans and actor
-- attribution for broker activity logs.

CREATE OR REPLACE FUNCTION public.auto_create_data_loan_on_assignment()
RETURNS trigger AS $$
DECLARE
  v_actor_id uuid;
BEGIN
  v_actor_id := NULLIF(current_setting('app.current_user_id', true), '')::uuid;
  v_actor_id := COALESCE(v_actor_id, auth.uid());

  IF (NEW.assigned_caller_id IS NOT NULL AND (OLD.assigned_caller_id IS NULL OR OLD.assigned_caller_id <> NEW.assigned_caller_id)) THEN
    INSERT INTO public.data_loans (
      lead_id,
      broker_id,
      granted_to_user_id,
      purpose,
      status,
      starts_at,
      expires_at
    ) VALUES (
      NEW.id,
      NEW.broker_id,
      NEW.assigned_caller_id,
      'call',
      'active',
      now(),
      now() + interval '24 hours'
    );

    IF (NEW.source_broker_id IS NOT NULL AND v_actor_id IS NOT NULL) THEN
      INSERT INTO public.broker_activity_logs (
        organization_id,
        broker_id,
        project_id,
        actor_id,
        activity_type,
        notes_safe
      ) VALUES (
        NEW.organization_id,
        NEW.source_broker_id,
        NEW.project_id,
        v_actor_id,
        'note_added',
        'Lead assigned to caller for secure calling.'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.assign_lead_to_caller_v1(
  p_lead_id uuid,
  p_caller_id uuid,
  p_actor_id uuid,
  p_org_id uuid
) RETURNS jsonb AS $$
DECLARE
  v_row_count int;
BEGIN
  IF NOT public.has_strict_enterprise_permission(p_actor_id, 'can_grant_data_loans', p_org_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'forbidden');
  END IF;

  IF NOT public.has_strict_enterprise_permission(p_caller_id, 'can_call_leads', p_org_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'caller_not_authorized');
  END IF;

  PERFORM set_config('app.current_user_id', p_actor_id::text, true);

  UPDATE public.leads_public
  SET assigned_caller_id = p_caller_id,
      updated_at = now()
  WHERE id = p_lead_id
    AND organization_id = p_org_id;

  GET DIAGNOSTICS v_row_count = ROW_COUNT;

  IF v_row_count = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'lead_not_found');
  END IF;

  INSERT INTO public.audit_events (actor_id, lead_id, event_type, event_context)
  VALUES (
    p_actor_id,
    p_lead_id,
    'lead_assigned_to_caller',
    jsonb_build_object('organization_id', p_org_id, 'caller_id', p_caller_id)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.assign_lead_to_caller_v1(uuid, uuid, uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.assign_lead_to_caller_v1(uuid, uuid, uuid, uuid) TO service_role;
