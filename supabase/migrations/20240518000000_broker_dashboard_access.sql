-- Broker dashboard access wiring.
-- Links an authenticated broker-side user to one safe brokers_public row.
-- Sensitive broker/customer ciphertext tables remain inaccessible to frontend users.

ALTER TABLE public.brokers_public
  ADD COLUMN IF NOT EXISTS linked_user_id uuid REFERENCES auth.users(id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_brokers_public_linked_user
ON public.brokers_public(linked_user_id)
WHERE linked_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_brokers_public_linked_org
ON public.brokers_public(organization_id, linked_user_id)
WHERE linked_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.protect_broker_user_link_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id uuid;
BEGIN
  v_actor_id := NULLIF(current_setting('app.current_user_id', true), '')::uuid;
  v_actor_id := COALESCE(v_actor_id, auth.uid());

  IF NEW.linked_user_id IS DISTINCT FROM OLD.linked_user_id THEN
    IF v_actor_id IS NULL OR NOT public.has_strict_enterprise_permission(
      v_actor_id,
      'can_manage_org_users',
      NEW.organization_id
    ) THEN
      RAISE EXCEPTION 'broker_user_link_update_denied';
    END IF;

    INSERT INTO public.audit_events (actor_id, event_type, event_context)
    VALUES (
      v_actor_id,
      'broker_user_link_updated',
      jsonb_build_object(
        'broker_id', NEW.id,
        'organization_id', NEW.organization_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_broker_user_link_update ON public.brokers_public;
CREATE TRIGGER protect_broker_user_link_update
BEFORE UPDATE OF linked_user_id ON public.brokers_public
FOR EACH ROW EXECUTE FUNCTION public.protect_broker_user_link_update();

CREATE OR REPLACE FUNCTION public.is_linked_broker_user(
  p_broker_id uuid,
  p_user_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    JOIN public.pilot_users pu
      ON pu.user_id = p_user_id
     AND pu.org_id = bp.organization_id
     AND pu.status = 'active'
    JOIN public.organizations o
      ON o.id = bp.organization_id
     AND o.status = 'active'
    WHERE bp.id = p_broker_id
      AND bp.linked_user_id = p_user_id
      AND bp.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_linked_broker_lead(
  p_lead_id uuid,
  p_user_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.leads_public lp
    WHERE lp.id = p_lead_id
      AND lp.source_broker_id IS NOT NULL
      AND public.is_linked_broker_user(lp.source_broker_id, p_user_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.is_linked_broker_visit(
  p_visit_id uuid,
  p_user_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.site_visits sv
    WHERE sv.id = p_visit_id
      AND sv.source_broker_id IS NOT NULL
      AND public.is_linked_broker_user(sv.source_broker_id, p_user_id)
  );
$$;

REVOKE ALL ON FUNCTION public.is_linked_broker_user(uuid, uuid) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.is_linked_broker_lead(uuid, uuid) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.is_linked_broker_visit(uuid, uuid) FROM anon, authenticated, public;

GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_linked_broker_lead(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_linked_broker_visit(uuid, uuid) TO authenticated, service_role;

DROP POLICY IF EXISTS brokers_public_linked_broker_read ON public.brokers_public;
CREATE POLICY brokers_public_linked_broker_read
ON public.brokers_public
FOR SELECT TO authenticated
USING (public.is_linked_broker_user(id, auth.uid()));

DROP POLICY IF EXISTS broker_activations_linked_broker_read ON public.broker_activations;
CREATE POLICY broker_activations_linked_broker_read
ON public.broker_activations
FOR SELECT TO authenticated
USING (public.is_linked_broker_user(broker_id, auth.uid()));

DROP POLICY IF EXISTS broker_activity_logs_linked_broker_read ON public.broker_activity_logs;
CREATE POLICY broker_activity_logs_linked_broker_read
ON public.broker_activity_logs
FOR SELECT TO authenticated
USING (public.is_linked_broker_user(broker_id, auth.uid()));

DROP POLICY IF EXISTS leads_public_linked_source_broker_read ON public.leads_public;
CREATE POLICY leads_public_linked_source_broker_read
ON public.leads_public
FOR SELECT TO authenticated
USING (public.is_linked_broker_lead(id, auth.uid()));

DROP POLICY IF EXISTS data_loans_linked_source_broker_read ON public.data_loans;
CREATE POLICY data_loans_linked_source_broker_read
ON public.data_loans
FOR SELECT TO authenticated
USING (public.is_linked_broker_lead(lead_id, auth.uid()));

DROP POLICY IF EXISTS call_attempts_linked_source_broker_read ON public.call_attempts;
CREATE POLICY call_attempts_linked_source_broker_read
ON public.call_attempts
FOR SELECT TO authenticated
USING (public.is_linked_broker_lead(lead_id, auth.uid()));

DROP POLICY IF EXISTS site_visits_linked_source_broker_read ON public.site_visits;
CREATE POLICY site_visits_linked_source_broker_read
ON public.site_visits
FOR SELECT TO authenticated
USING (
  source_broker_id IS NOT NULL
  AND public.is_linked_broker_user(source_broker_id, auth.uid())
);

DROP POLICY IF EXISTS broker_locks_linked_source_broker_read ON public.broker_locks;
CREATE POLICY broker_locks_linked_source_broker_read
ON public.broker_locks
FOR SELECT TO authenticated
USING (
  source_site_visit_id IS NOT NULL
  AND public.is_linked_broker_visit(source_site_visit_id, auth.uid())
);
