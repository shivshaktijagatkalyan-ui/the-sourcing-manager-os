-- SPRINT 4: Operational Visibility & Abuse Monitoring
-- Migration: 20240507000000_sprint4_operational_visibility.sql

-- 1. Helper predicates for fail-closed pilot operations.
CREATE OR REPLACE FUNCTION public.is_pilot_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pilot_users pu
    JOIN public.organizations o ON o.id = pu.org_id
    WHERE pu.user_id = p_user_id
      AND pu.role = 'admin'
      AND pu.status = 'active'
      AND o.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.pilot_org_id_for_user(p_user_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT pu.org_id
  FROM public.pilot_users pu
  JOIN public.organizations o ON o.id = pu.org_id
  WHERE pu.user_id = p_user_id
    AND pu.status = 'active'
    AND o.status = 'active'
  ORDER BY pu.created_at ASC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_same_active_pilot_org(p_user_id uuid, p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pilot_users pu
    JOIN public.organizations o ON o.id = pu.org_id
    WHERE pu.user_id = p_user_id
      AND pu.org_id = p_org_id
      AND pu.status = 'active'
      AND o.status = 'active'
  );
$$;

-- 2. Abuse event ledger. No customer identity or contact material belongs here.
CREATE TABLE public.abuse_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES auth.users(id),
  organization_id uuid NOT NULL REFERENCES public.organizations(id),
  lead_id uuid REFERENCES public.leads_public(id),
  site_visit_id uuid REFERENCES public.site_visits(id),
  event_type text NOT NULL CHECK (event_type IN (
    'gps_outside_geofence_repeated',
    'gps_accuracy_failure_repeated',
    'photo_overwrite_attempt',
    'call_after_loan_expiry',
    'revoked_loan_access_attempt',
    'duplicate_lock_attempt',
    'broker_rejection_spike',
    'dispute_frequency_spike',
    'inactive_enabled_user',
    'unusual_activity_window',
    'disabled_user_access_attempt',
    'paused_org_access_attempt'
  )),
  severity text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  risk_score_delta numeric(4,2) NOT NULL DEFAULT 0 CHECK (risk_score_delta >= -5 AND risk_score_delta <= 5),
  evidence_ref jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  CONSTRAINT abuse_events_resolution_check CHECK (
    (status IN ('resolved', 'dismissed') AND resolved_at IS NOT NULL AND resolved_by IS NOT NULL)
    OR status IN ('open', 'investigating')
  )
);

CREATE INDEX idx_abuse_events_org_created ON public.abuse_events (organization_id, created_at DESC);
CREATE INDEX idx_abuse_events_actor_created ON public.abuse_events (actor_id, created_at DESC);
CREATE INDEX idx_abuse_events_open_severity ON public.abuse_events (organization_id, severity, created_at DESC)
  WHERE status IN ('open', 'investigating');
CREATE INDEX idx_abuse_events_visit ON public.abuse_events (site_visit_id)
  WHERE site_visit_id IS NOT NULL;

-- 3. Internal risk notifications. Messages are reason-code based and safe.
CREATE TABLE public.risk_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  abuse_event_id uuid REFERENCES public.abuse_events(id) ON DELETE SET NULL,
  organization_id uuid NOT NULL REFERENCES public.organizations(id),
  recipient_user_id uuid REFERENCES auth.users(id),
  notification_type text NOT NULL CHECK (notification_type IN (
    'critical_abuse_event',
    'duplicate_lock_conflict',
    'gps_rejection_repeated',
    'broker_rejection_spike',
    'org_paused',
    'dispute_opened',
    'dispute_escalated',
    'trust_decay_run'
  )),
  severity text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  reason_code text NOT NULL,
  status text NOT NULL DEFAULT 'unread' CHECK (status IN ('unread', 'acknowledged', 'resolved')),
  created_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  acknowledged_by uuid REFERENCES auth.users(id),
  CONSTRAINT risk_notifications_reason_not_blank CHECK (btrim(reason_code) <> '')
);

CREATE INDEX idx_risk_notifications_org_created ON public.risk_notifications (organization_id, created_at DESC);
CREATE INDEX idx_risk_notifications_recipient ON public.risk_notifications (recipient_user_id, status, created_at DESC)
  WHERE recipient_user_id IS NOT NULL;

-- 4. Explainable trust score history.
CREATE TABLE public.trust_score_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  entity_type text NOT NULL CHECK (entity_type IN ('user', 'organization')),
  organization_id uuid REFERENCES public.organizations(id),
  score_before numeric(3,2) NOT NULL CHECK (score_before >= 0 AND score_before <= 5),
  score_after numeric(3,2) NOT NULL CHECK (score_after >= 0 AND score_after <= 5),
  score_delta numeric(4,2) NOT NULL CHECK (score_delta >= -5 AND score_delta <= 5),
  reason_code text NOT NULL,
  components_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  calculation_run_id uuid NOT NULL DEFAULT gen_random_uuid(),
  calculated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT trust_score_snapshots_reason_not_blank CHECK (btrim(reason_code) <> '')
);

CREATE INDEX idx_trust_score_snapshots_entity ON public.trust_score_snapshots (entity_type, entity_id, calculated_at DESC);
CREATE INDEX idx_trust_score_snapshots_org ON public.trust_score_snapshots (organization_id, calculated_at DESC)
  WHERE organization_id IS NOT NULL;

-- 5. Daily pilot activity aggregate for dashboards.
CREATE TABLE public.pilot_activity_daily (
  organization_id uuid NOT NULL REFERENCES public.organizations(id),
  activity_date date NOT NULL,
  active_users_count integer NOT NULL DEFAULT 0 CHECK (active_users_count >= 0),
  disabled_users_count integer NOT NULL DEFAULT 0 CHECK (disabled_users_count >= 0),
  site_visits_started integer NOT NULL DEFAULT 0 CHECK (site_visits_started >= 0),
  site_visits_verified integer NOT NULL DEFAULT 0 CHECK (site_visits_verified >= 0),
  gps_failures integer NOT NULL DEFAULT 0 CHECK (gps_failures >= 0),
  abuse_events_count integer NOT NULL DEFAULT 0 CHECK (abuse_events_count >= 0),
  critical_events_count integer NOT NULL DEFAULT 0 CHECK (critical_events_count >= 0),
  open_disputes_count integer NOT NULL DEFAULT 0 CHECK (open_disputes_count >= 0),
  locks_created_count integer NOT NULL DEFAULT 0 CHECK (locks_created_count >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, activity_date)
);

DROP TRIGGER IF EXISTS set_pilot_activity_daily_updated_at ON public.pilot_activity_daily;
CREATE TRIGGER set_pilot_activity_daily_updated_at
BEFORE UPDATE ON public.pilot_activity_daily
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 6. RLS: default deny, narrow reads for active pilot admins.
ALTER TABLE public.abuse_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.risk_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_notifications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.trust_score_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trust_score_snapshots FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pilot_activity_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pilot_activity_daily FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.abuse_events FROM anon, authenticated, public;
REVOKE ALL ON public.risk_notifications FROM anon, authenticated, public;
REVOKE ALL ON public.trust_score_snapshots FROM anon, authenticated, public;
REVOKE ALL ON public.pilot_activity_daily FROM anon, authenticated, public;

GRANT SELECT ON public.abuse_events TO authenticated;
GRANT SELECT ON public.risk_notifications TO authenticated;
GRANT SELECT ON public.trust_score_snapshots TO authenticated;
GRANT SELECT ON public.pilot_activity_daily TO authenticated;

CREATE POLICY abuse_events_admin_read
ON public.abuse_events
FOR SELECT
TO authenticated
USING (
  public.is_pilot_admin(auth.uid())
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

CREATE POLICY risk_notifications_admin_read
ON public.risk_notifications
FOR SELECT
TO authenticated
USING (
  public.is_pilot_admin(auth.uid())
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

CREATE POLICY risk_notifications_recipient_read
ON public.risk_notifications
FOR SELECT
TO authenticated
USING (
  recipient_user_id = auth.uid()
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

CREATE POLICY trust_score_snapshots_admin_read
ON public.trust_score_snapshots
FOR SELECT
TO authenticated
USING (
  public.is_pilot_admin(auth.uid())
  AND (
    organization_id IS NULL
    OR public.is_same_active_pilot_org(auth.uid(), organization_id)
  )
);

CREATE POLICY trust_score_snapshots_self_read
ON public.trust_score_snapshots
FOR SELECT
TO authenticated
USING (
  entity_type = 'user'
  AND entity_id = auth.uid()
  AND organization_id IS NOT NULL
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

CREATE POLICY pilot_activity_daily_admin_read
ON public.pilot_activity_daily
FOR SELECT
TO authenticated
USING (
  public.is_pilot_admin(auth.uid())
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

-- 7. Summary views. Use invoker rights so table RLS still applies.
CREATE OR REPLACE VIEW public.org_risk_summary
WITH (security_invoker = true)
AS
SELECT
  ae.organization_id,
  count(*) FILTER (WHERE ae.status IN ('open', 'investigating')) AS open_event_count,
  count(*) FILTER (WHERE ae.severity = 'critical' AND ae.status IN ('open', 'investigating')) AS critical_open_count,
  count(*) FILTER (WHERE ae.severity = 'high' AND ae.status IN ('open', 'investigating')) AS high_open_count,
  max(ae.created_at) AS last_event_at,
  COALESCE(avg(ts.score), 3.00)::numeric(3,2) AS average_trust_score
FROM public.abuse_events ae
LEFT JOIN public.pilot_users pu ON pu.org_id = ae.organization_id
LEFT JOIN public.trust_scores ts ON ts.entity_type = 'user' AND ts.entity_id = pu.user_id
GROUP BY ae.organization_id;

CREATE OR REPLACE VIEW public.user_risk_summary
WITH (security_invoker = true)
AS
SELECT
  ae.actor_id AS user_id,
  ae.organization_id,
  count(*) FILTER (WHERE ae.status IN ('open', 'investigating')) AS open_event_count,
  count(*) FILTER (WHERE ae.severity = 'critical' AND ae.status IN ('open', 'investigating')) AS critical_open_count,
  max(ae.created_at) AS last_event_at,
  COALESCE(ts.score, 3.00)::numeric(3,2) AS trust_score
FROM public.abuse_events ae
LEFT JOIN public.trust_scores ts ON ts.entity_type = 'user' AND ts.entity_id = ae.actor_id
WHERE ae.actor_id IS NOT NULL
GROUP BY ae.actor_id, ae.organization_id, ts.score;

GRANT SELECT ON public.org_risk_summary TO authenticated;
GRANT SELECT ON public.user_risk_summary TO authenticated;

REVOKE ALL ON FUNCTION public.is_pilot_admin(uuid) FROM anon, public;
REVOKE ALL ON FUNCTION public.pilot_org_id_for_user(uuid) FROM anon, public;
REVOKE ALL ON FUNCTION public.is_same_active_pilot_org(uuid, uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.is_pilot_admin(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pilot_org_id_for_user(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_same_active_pilot_org(uuid, uuid) TO authenticated, service_role;
