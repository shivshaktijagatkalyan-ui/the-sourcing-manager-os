-- Restore the audit helper expected by existing broker CRM triggers.
-- This helper stores only safe event metadata and never writes contact data.

CREATE OR REPLACE FUNCTION public.record_audit(
  p_actor_id uuid,
  p_event_type text,
  p_event_context jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_audit_id uuid;
BEGIN
  INSERT INTO public.audit_events (
    id,
    actor_id,
    lead_id,
    event_type,
    event_context,
    created_at,
    idempotency_key
  )
  VALUES (
    gen_random_uuid(),
    p_actor_id,
    NULL,
    p_event_type,
    COALESCE(p_event_context, '{}'::jsonb),
    now(),
    gen_random_uuid()
  )
  RETURNING id INTO v_audit_id;

  RETURN v_audit_id;
END;
$$;
