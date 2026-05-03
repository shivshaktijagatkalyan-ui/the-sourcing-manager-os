-- Sprint 1 production foundation: enforcement spine for The Sourcing Manager OS.
-- Phone data is stored only as TEXT ciphertext in leads_sensitive.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.leads_public (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  broker_id UUID NOT NULL REFERENCES auth.users(id),
  assigned_manager_id UUID REFERENCES auth.users(id),
  assigned_caller_id UUID REFERENCES auth.users(id),
  alias TEXT NOT NULL,
  area TEXT,
  city TEXT,
  property_name TEXT,
  project_id UUID,
  budget_min NUMERIC,
  budget_max NUMERIC,
  lead_status TEXT NOT NULL DEFAULT 'new',
  consent_status TEXT NOT NULL DEFAULT 'pending',
  dnd_status TEXT NOT NULL DEFAULT 'unknown',
  rera_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  gst_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT leads_public_alias_not_blank CHECK (btrim(alias) <> ''),
  CONSTRAINT leads_public_budget_order CHECK (
    budget_min IS NULL OR budget_max IS NULL OR budget_min <= budget_max
  ),
  CONSTRAINT leads_public_status_check CHECK (
    lead_status IN ('new', 'loan_active', 'call_queued', 'call_blocked', 'visit_scheduled', 'visit_verified', 'locked', 'revoked')
  ),
  CONSTRAINT leads_public_consent_check CHECK (
    consent_status IN ('pending', 'granted', 'denied', 'expired')
  ),
  CONSTRAINT leads_public_dnd_check CHECK (
    dnd_status IN ('unknown', 'clear', 'blocked')
  )
);

CREATE TABLE IF NOT EXISTS public.leads_sensitive (
  lead_id UUID PRIMARY KEY REFERENCES public.leads_public(id) ON DELETE CASCADE,
  phone_ciphertext TEXT NOT NULL,
  encryption_version INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT leads_sensitive_ciphertext_not_blank CHECK (btrim(phone_ciphertext) <> ''),
  CONSTRAINT leads_sensitive_ciphertext_min_length CHECK (length(phone_ciphertext) >= 32)
);

CREATE TABLE IF NOT EXISTS public.data_loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  broker_id UUID NOT NULL REFERENCES auth.users(id),
  granted_to_user_id UUID NOT NULL REFERENCES auth.users(id),
  purpose TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT data_loans_purpose_check CHECK (purpose IN ('call', 'site_visit')),
  CONSTRAINT data_loans_status_check CHECK (status IN ('active', 'expired', 'revoked')),
  CONSTRAINT data_loans_window_check CHECK (expires_at > starts_at),
  CONSTRAINT data_loans_revoked_check CHECK (
    (status = 'revoked' AND revoked_at IS NOT NULL) OR (status <> 'revoked')
  )
);

CREATE TABLE IF NOT EXISTS public.call_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  caller_id UUID NOT NULL REFERENCES auth.users(id),
  data_loan_id UUID REFERENCES public.data_loans(id),
  provider TEXT NOT NULL DEFAULT 'exotel',
  provider_call_id TEXT,
  call_status TEXT NOT NULL,
  duration_seconds INT,
  outcome TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT call_attempts_provider_check CHECK (provider IN ('exotel', 'twilio')),
  CONSTRAINT call_attempts_status_check CHECK (
    call_status IN ('connecting', 'queued', 'blocked', 'expired', 'revoked', 'dnd_blocked', 'consent_required', 'provider_failed', 'completed', 'failed')
  ),
  CONSTRAINT call_attempts_duration_check CHECK (duration_seconds IS NULL OR duration_seconds >= 0)
);

CREATE TABLE IF NOT EXISTS public.audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id),
  lead_id UUID REFERENCES public.leads_public(id),
  event_type TEXT NOT NULL,
  event_context JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_hash TEXT,
  user_agent_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT audit_events_type_not_blank CHECK (btrim(event_type) <> '')
);

CREATE TABLE IF NOT EXISTS public.site_visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  broker_id UUID NOT NULL REFERENCES auth.users(id),
  sourcing_manager_id UUID NOT NULL REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'scheduled',
  visit_lat NUMERIC,
  visit_lng NUMERIC,
  geo_hash TEXT,
  live_photo_hash TEXT,
  photo_storage_path TEXT,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT site_visits_status_check CHECK (status IN ('scheduled', 'arrived', 'verified', 'rejected', 'cancelled')),
  CONSTRAINT site_visits_lat_check CHECK (visit_lat IS NULL OR (visit_lat >= -90 AND visit_lat <= 90)),
  CONSTRAINT site_visits_lng_check CHECK (visit_lng IS NULL OR (visit_lng >= -180 AND visit_lng <= 180))
);

CREATE TABLE IF NOT EXISTS public.broker_locks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  broker_id UUID NOT NULL REFERENCES auth.users(id),
  source_site_visit_id UUID REFERENCES public.site_visits(id),
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '45 days'),
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT broker_locks_status_check CHECK (status IN ('active', 'expired', 'released')),
  CONSTRAINT broker_locks_window_check CHECK (expires_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_leads_public_broker ON public.leads_public (broker_id);
CREATE INDEX IF NOT EXISTS idx_data_loans_grantee_active ON public.data_loans (granted_to_user_id, lead_id, purpose, expires_at)
  WHERE status = 'active' AND revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_call_attempts_caller ON public.call_attempts (caller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_attempts_lead ON public.call_attempts (lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_lead ON public.audit_events (lead_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_broker_locks_active_lead_broker
  ON public.broker_locks (lead_id, broker_id)
  WHERE status = 'active';

DROP TRIGGER IF EXISTS set_leads_public_updated_at ON public.leads_public;
CREATE TRIGGER set_leads_public_updated_at
BEFORE UPDATE ON public.leads_public
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_call_attempts_updated_at ON public.call_attempts;
CREATE TRIGGER set_call_attempts_updated_at
BEFORE UPDATE ON public.call_attempts
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.prevent_audit_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_events is append-only';
END;
$$;

DROP TRIGGER IF EXISTS audit_events_append_only ON public.audit_events;
CREATE TRIGGER audit_events_append_only
BEFORE UPDATE OR DELETE ON public.audit_events
FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_event_mutation();

CREATE OR REPLACE FUNCTION public.has_active_data_loan(p_lead_id UUID, p_user_id UUID, p_purpose TEXT)
RETURNS BOOLEAN
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

CREATE OR REPLACE FUNCTION public.encrypt_lead_contact(p_contact TEXT, p_key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_contact IS NULL OR btrim(p_contact) = '' THEN
    RAISE EXCEPTION 'contact_required';
  END IF;

  IF p_key IS NULL OR length(p_key) < 32 THEN
    RAISE EXCEPTION 'encryption_key_invalid';
  END IF;

  RETURN encode(extensions.pgp_sym_encrypt(p_contact, p_key, 'cipher-algo=aes256'), 'base64');
END;
$$;

CREATE OR REPLACE FUNCTION public.decrypt_lead_contact_for_edge(p_ciphertext TEXT, p_key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_key IS NULL OR length(p_key) < 32 THEN
    RAISE EXCEPTION 'encryption_key_invalid';
  END IF;

  RETURN extensions.pgp_sym_decrypt(decode(p_ciphertext, 'base64'), p_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_broker_lock_for_verified_visit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'verified' AND TG_OP = 'INSERT' THEN
    INSERT INTO public.broker_locks (lead_id, broker_id, source_site_visit_id, starts_at)
    VALUES (NEW.lead_id, NEW.broker_id, NEW.id, COALESCE(NEW.verified_at, now()))
    ON CONFLICT DO NOTHING;

    UPDATE public.leads_public
    SET lead_status = 'locked'
    WHERE id = NEW.lead_id;

    INSERT INTO public.audit_events (actor_id, lead_id, event_type, event_context)
    VALUES (
      NEW.sourcing_manager_id,
      NEW.lead_id,
      'broker_lock_created',
      jsonb_build_object('site_visit_id', NEW.id)
    );
  ELSIF NEW.status = 'verified' AND OLD.status <> 'verified' THEN
    INSERT INTO public.broker_locks (lead_id, broker_id, source_site_visit_id, starts_at)
    VALUES (NEW.lead_id, NEW.broker_id, NEW.id, COALESCE(NEW.verified_at, now()))
    ON CONFLICT DO NOTHING;

    UPDATE public.leads_public
    SET lead_status = 'locked'
    WHERE id = NEW.lead_id;

    INSERT INTO public.audit_events (actor_id, lead_id, event_type, event_context)
    VALUES (
      NEW.sourcing_manager_id,
      NEW.lead_id,
      'broker_lock_created',
      jsonb_build_object('site_visit_id', NEW.id)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS site_visit_verified_creates_broker_lock ON public.site_visits;
CREATE TRIGGER site_visit_verified_creates_broker_lock
AFTER INSERT OR UPDATE ON public.site_visits
FOR EACH ROW EXECUTE FUNCTION public.create_broker_lock_for_verified_visit();

ALTER TABLE public.leads_public ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads_public FORCE ROW LEVEL SECURITY;
ALTER TABLE public.leads_sensitive ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads_sensitive FORCE ROW LEVEL SECURITY;
ALTER TABLE public.data_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_loans FORCE ROW LEVEL SECURITY;
ALTER TABLE public.call_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_attempts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.site_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_visits FORCE ROW LEVEL SECURITY;
ALTER TABLE public.broker_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broker_locks FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.leads_sensitive FROM anon, authenticated, public;
REVOKE UPDATE, DELETE ON public.audit_events FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.encrypt_lead_contact(TEXT, TEXT) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.decrypt_lead_contact_for_edge(TEXT, TEXT) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.has_active_data_loan(UUID, UUID, TEXT) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.encrypt_lead_contact(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.decrypt_lead_contact_for_edge(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.has_active_data_loan(UUID, UUID, TEXT) TO service_role;

DROP POLICY IF EXISTS leads_public_broker_read ON public.leads_public;
CREATE POLICY leads_public_broker_read
ON public.leads_public
FOR SELECT
TO authenticated
USING (broker_id = auth.uid());

DROP POLICY IF EXISTS leads_public_active_loan_read ON public.leads_public;
CREATE POLICY leads_public_active_loan_read
ON public.leads_public
FOR SELECT
TO authenticated
USING (
  public.has_active_data_loan(id, auth.uid(), 'call')
  OR public.has_active_data_loan(id, auth.uid(), 'site_visit')
);

DROP POLICY IF EXISTS data_loans_participant_read ON public.data_loans;
CREATE POLICY data_loans_participant_read
ON public.data_loans
FOR SELECT
TO authenticated
USING (broker_id = auth.uid() OR granted_to_user_id = auth.uid());

DROP POLICY IF EXISTS call_attempts_caller_read ON public.call_attempts;
CREATE POLICY call_attempts_caller_read
ON public.call_attempts
FOR SELECT
TO authenticated
USING (caller_id = auth.uid());

DROP POLICY IF EXISTS call_attempts_broker_read ON public.call_attempts;
CREATE POLICY call_attempts_broker_read
ON public.call_attempts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.leads_public lp
    WHERE lp.id = call_attempts.lead_id
      AND lp.broker_id = auth.uid()
  )
);

DROP POLICY IF EXISTS audit_events_actor_read ON public.audit_events;
CREATE POLICY audit_events_actor_read
ON public.audit_events
FOR SELECT
TO authenticated
USING (actor_id = auth.uid());

DROP POLICY IF EXISTS audit_events_broker_lead_read ON public.audit_events;
CREATE POLICY audit_events_broker_lead_read
ON public.audit_events
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.leads_public lp
    WHERE lp.id = audit_events.lead_id
      AND lp.broker_id = auth.uid()
  )
);

DROP POLICY IF EXISTS site_visits_broker_read ON public.site_visits;
CREATE POLICY site_visits_broker_read
ON public.site_visits
FOR SELECT
TO authenticated
USING (broker_id = auth.uid());

DROP POLICY IF EXISTS site_visits_manager_read ON public.site_visits;
CREATE POLICY site_visits_manager_read
ON public.site_visits
FOR SELECT
TO authenticated
USING (sourcing_manager_id = auth.uid());

DROP POLICY IF EXISTS broker_locks_broker_read ON public.broker_locks;
CREATE POLICY broker_locks_broker_read
ON public.broker_locks
FOR SELECT
TO authenticated
USING (broker_id = auth.uid());
