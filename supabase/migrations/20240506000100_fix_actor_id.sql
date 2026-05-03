-- Fix: Capture actor_id in triggers when using Service Role Edge Functions
CREATE OR REPLACE FUNCTION public.log_site_visit_transition()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_id uuid;
BEGIN
  v_actor_id := COALESCE(
    auth.uid(), 
    NULLIF(current_setting('app.current_user_id', true), '')::uuid
  );

  IF (OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.audit_events (actor_id, event_type, lead_id, event_context)
    VALUES (v_actor_id, 'site_visit_state_change', NEW.lead_id, jsonb_build_object(
      'site_visit_id', NEW.id,
      'old_status', OLD.status,
      'new_status', NEW.status,
      'timestamp', now()
    ));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
