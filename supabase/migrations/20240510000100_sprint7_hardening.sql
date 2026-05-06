-- Sprint 7 hardening: Enterprise onboarding and role operations
-- This migration is additive over 20240510000000_sprint7_enterprise.sql.

-- 1. Complete role and permission catalogs.
INSERT INTO public.role_definitions (id, name, description) VALUES
  ('platform_admin', 'Platform Admin', 'Cross-organization platform operator'),
  ('admin', 'Legacy Admin Bridge', 'Compatibility role for pre-Sprint-7 pilot admins'),
  ('developer_admin', 'Developer Admin', 'Developer-side operational administrator'),
  ('broker_owner', 'Broker Owner', 'Broker organization owner'),
  ('broker_agent', 'Broker Agent', 'Broker-side operational user'),
  ('sourcing_manager', 'Sourcing Manager', 'Verified visit executor'),
  ('caller', 'Caller', 'Loan-gated call operator'),
  ('compliance_admin', 'Compliance Admin', 'Compliance report reviewer'),
  ('dispute_admin', 'Dispute Admin', 'Dispute workflow administrator'),
  ('finance_admin', 'Finance Admin', 'Payout and statement administrator'),
  ('read_only_auditor', 'Read Only Auditor', 'Read-only operational auditor')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

INSERT INTO public.permission_definitions (id, name, description) VALUES
  ('can_upload_leads', 'Upload Leads', 'Create metadata-only leads through protected upload flow'),
  ('can_grant_data_loans', 'Grant Data Loans', 'Grant time-bound access loans'),
  ('can_call_leads', 'Call Leads', 'Use secure PSTN bridge after active loan validation'),
  ('can_create_site_visits', 'Create Site Visits', 'Create site visit records'),
  ('can_verify_site_visits', 'Verify Site Visits', 'Submit GPS/photo verification through Edge Functions'),
  ('can_review_site_visits', 'Review Site Visits', 'Approve or reject verified site visits'),
  ('can_view_disputes', 'View Disputes', 'Read sanitized dispute records'),
  ('can_resolve_disputes', 'Resolve Disputes', 'Resolve sanitized dispute records'),
  ('can_view_payouts', 'View Payouts', 'Read payout ledger rows allowed by role'),
  ('can_generate_statements', 'Generate Statements', 'Generate sanitized payout statements'),
  ('can_view_compliance_reports', 'View Compliance Reports', 'Read compliance status and audit summaries'),
  ('can_manage_org_users', 'Manage Organization Users', 'Invite, assign, activate, and deactivate organization users'),
  ('can_pause_org', 'Pause Organization', 'Pause or resume organization workflows'),
  ('can_suspend_user', 'Suspend User', 'Suspend users after review'),
  ('can_view_risk_dashboard', 'View Risk Dashboard', 'Read sanitized abuse/risk dashboards')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

DELETE FROM public.role_permissions
WHERE role_id IN (
  'platform_admin',
  'admin',
  'developer_admin',
  'broker_owner',
  'broker_agent',
  'sourcing_manager',
  'caller',
  'compliance_admin',
  'dispute_admin',
  'finance_admin',
  'read_only_auditor'
);

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 'platform_admin', id FROM public.permission_definitions;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 'admin', id FROM public.permission_definitions;

INSERT INTO public.role_permissions (role_id, permission_id) VALUES
  ('developer_admin', 'can_view_disputes'),
  ('developer_admin', 'can_view_compliance_reports'),
  ('developer_admin', 'can_manage_org_users'),
  ('developer_admin', 'can_pause_org'),
  ('developer_admin', 'can_suspend_user'),
  ('developer_admin', 'can_view_risk_dashboard'),
  ('broker_owner', 'can_upload_leads'),
  ('broker_owner', 'can_grant_data_loans'),
  ('broker_owner', 'can_review_site_visits'),
  ('broker_owner', 'can_view_disputes'),
  ('broker_owner', 'can_view_payouts'),
  ('broker_owner', 'can_generate_statements'),
  ('broker_owner', 'can_manage_org_users'),
  ('broker_agent', 'can_upload_leads'),
  ('broker_agent', 'can_view_payouts'),
  ('sourcing_manager', 'can_create_site_visits'),
  ('sourcing_manager', 'can_verify_site_visits'),
  ('caller', 'can_call_leads'),
  ('compliance_admin', 'can_view_compliance_reports'),
  ('compliance_admin', 'can_view_disputes'),
  ('dispute_admin', 'can_view_disputes'),
  ('dispute_admin', 'can_resolve_disputes'),
  ('finance_admin', 'can_view_payouts'),
  ('finance_admin', 'can_generate_statements'),
  ('read_only_auditor', 'can_view_disputes'),
  ('read_only_auditor', 'can_view_payouts'),
  ('read_only_auditor', 'can_view_compliance_reports'),
  ('read_only_auditor', 'can_view_risk_dashboard')
ON CONFLICT DO NOTHING;

-- 2. Organization and user profile hardening.
CREATE TABLE IF NOT EXISTS public.organization_profiles (
  org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
  legal_name text,
  city text,
  state text,
  gstin_hash text,
  rera_registration_hash text,
  kyc_status text NOT NULL DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
  compliance_status text NOT NULL DEFAULT 'pending' CHECK (compliance_status IN ('pending', 'verified', 'rejected')),
  pilot_status text NOT NULL DEFAULT 'pending' CHECK (pilot_status IN ('pending', 'approved', 'rejected')),
  created_by uuid REFERENCES auth.users(id),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS display_alias text,
  ADD COLUMN IF NOT EXISTS profile_completed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS kyc_reference_hash text,
  ADD COLUMN IF NOT EXISTS rera_registration_hash text,
  ADD COLUMN IF NOT EXISTS gstin_hash text,
  ADD COLUMN IF NOT EXISTS compliance_status text NOT NULL DEFAULT 'pending' CHECK (compliance_status IN ('pending', 'verified', 'rejected')),
  ADD COLUMN IF NOT EXISTS pilot_status text NOT NULL DEFAULT 'pending' CHECK (pilot_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE public.organization_invites
  ALTER COLUMN invited_email DROP NOT NULL,
  ALTER COLUMN invited_email SET DEFAULT 'redacted',
  ADD COLUMN IF NOT EXISTS invitee_hash text,
  ADD COLUMN IF NOT EXISTS invite_token_hash text,
  ADD COLUMN IF NOT EXISTS accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_by uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
  ADD COLUMN IF NOT EXISTS revoked_by uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.organization_invites
SET invited_email = 'redacted'
WHERE invited_email IS NOT NULL AND invited_email <> 'redacted';

CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_invites_token_hash
ON public.organization_invites(invite_token_hash)
WHERE invite_token_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_organization_invites_org_status
ON public.organization_invites(organization_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.permission_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_by uuid REFERENCES auth.users(id),
  updated_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT permission_templates_name_not_blank CHECK (btrim(name) <> '')
);

CREATE INDEX IF NOT EXISTS idx_permission_templates_org
ON public.permission_templates(organization_id, status);

CREATE TABLE IF NOT EXISTS public.permission_template_permissions (
  template_id uuid NOT NULL REFERENCES public.permission_templates(id) ON DELETE CASCADE,
  permission_id text NOT NULL REFERENCES public.permission_definitions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (template_id, permission_id)
);

CREATE TABLE IF NOT EXISTS public.role_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id text NOT NULL REFERENCES public.role_definitions(id),
  permission_template_id uuid REFERENCES public.permission_templates(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  assigned_by uuid REFERENCES auth.users(id),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  revoked_by uuid REFERENCES auth.users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_role_assignments_one_active_role
ON public.role_assignments(organization_id, user_id)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_role_assignments_user
ON public.role_assignments(user_id, status);

CREATE TABLE IF NOT EXISTS public.onboarding_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  requested_for_user_id uuid REFERENCES auth.users(id),
  requested_by uuid REFERENCES auth.users(id),
  request_type text NOT NULL CHECK (request_type IN (
    'organization_onboarding',
    'user_invite',
    'role_assignment',
    'user_activation',
    'user_deactivation',
    'organization_pause',
    'organization_resume',
    'permission_template_update'
  )),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'approved', 'rejected', 'closed')),
  reason_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_onboarding_requests_org
ON public.onboarding_requests(organization_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.onboarding_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES auth.users(id),
  organization_id uuid REFERENCES public.organizations(id),
  target_user_id uuid REFERENCES auth.users(id),
  event_type text NOT NULL CHECK (event_type IN (
    'organization_created',
    'invite_created',
    'invite_accepted',
    'role_assigned',
    'permission_template_updated',
    'user_activated',
    'user_deactivated',
    'user_suspended',
    'org_paused',
    'org_resumed'
  )),
  event_context jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_audit_org
ON public.onboarding_audit_events(organization_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.user_activation_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  check_name text NOT NULL,
  passed boolean NOT NULL DEFAULT false,
  evidence_ref jsonb NOT NULL DEFAULT '{}'::jsonb,
  checked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, user_id, check_name)
);

CREATE TABLE IF NOT EXISTS public.org_activation_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  check_name text NOT NULL,
  passed boolean NOT NULL DEFAULT false,
  evidence_ref jsonb NOT NULL DEFAULT '{}'::jsonb,
  checked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, check_name)
);

-- 3. Updated-at triggers.
DROP TRIGGER IF EXISTS set_organization_profiles_updated_at ON public.organization_profiles;
CREATE TRIGGER set_organization_profiles_updated_at
BEFORE UPDATE ON public.organization_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_permission_templates_updated_at ON public.permission_templates;
CREATE TRIGGER set_permission_templates_updated_at
BEFORE UPDATE ON public.permission_templates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 4. Permission and activation helpers.
CREATE OR REPLACE FUNCTION public.legacy_role_for_enterprise_role(p_role text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_role IN ('platform_admin', 'developer_admin', 'compliance_admin', 'dispute_admin', 'finance_admin', 'read_only_auditor') THEN 'admin'
    WHEN p_role IN ('broker_owner', 'broker_agent') THEN 'broker'
    WHEN p_role = 'sourcing_manager' THEN 'sourcing_manager'
    WHEN p_role = 'caller' THEN 'caller'
    ELSE 'caller'
  END;
$$;

CREATE OR REPLACE FUNCTION public.has_active_suspension(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_suspensions us
    WHERE us.user_id = p_user_id
      AND us.starts_at <= now()
      AND (us.ends_at IS NULL OR us.ends_at > now())
  );
$$;

CREATE OR REPLACE FUNCTION public.has_enterprise_permission(
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
    JOIN public.permission_templates pt ON pt.id = ra.permission_template_id
    JOIN public.permission_template_permissions ptp ON ptp.template_id = pt.id
    JOIN public.pilot_users pu ON pu.user_id = ra.user_id AND pu.org_id = ra.organization_id
    JOIN public.organizations o ON o.id = ra.organization_id
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
  )
  OR EXISTS (
    SELECT 1
    FROM public.pilot_users pu
    JOIN public.organizations o ON o.id = pu.org_id
    JOIN public.role_permissions rp ON rp.role_id = pu.role
    WHERE pu.user_id = p_user_id
      AND pu.status = 'active'
      AND o.status = 'active'
      AND rp.permission_id = p_permission
      AND NOT public.has_active_suspension(p_user_id)
      AND (p_org_id IS NULL OR pu.org_id = p_org_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.has_permission(p_user_id uuid, p_permission text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_enterprise_permission(p_user_id, p_permission, NULL);
$$;

CREATE OR REPLACE FUNCTION public.is_pilot_active(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pilot_users pu
    JOIN public.organizations o ON pu.org_id = o.id
    WHERE pu.user_id = p_user_id
      AND pu.status = 'active'
      AND o.status = 'active'
      AND NOT public.has_active_suspension(p_user_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.is_enterprise_admin_for_org(p_user_id uuid, p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_enterprise_permission(p_user_id, 'can_manage_org_users', p_org_id)
    OR public.has_enterprise_permission(p_user_id, 'can_pause_org', p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.safe_hash_text(p_value text, p_salt text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT encode(extensions.digest(COALESCE(p_value, '') || ':' || COALESCE(p_salt, ''), 'sha256'), 'hex');
$$;

CREATE OR REPLACE FUNCTION public.record_onboarding_audit(
  p_actor_id uuid,
  p_organization_id uuid,
  p_target_user_id uuid,
  p_event_type text,
  p_context jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_safe_context jsonb;
BEGIN
  SELECT COALESCE(jsonb_object_agg(key, value), '{}'::jsonb)
  INTO v_safe_context
  FROM jsonb_each(COALESCE(p_context, '{}'::jsonb))
  WHERE key IN (
    'organization_id',
    'target_user_id',
    'role_id',
    'permission_template_id',
    'invite_id',
    'request_id',
    'status',
    'reason_code',
    'check_count',
    'passed_count'
  )
  AND jsonb_typeof(value) IN ('string', 'number', 'boolean', 'null');

  INSERT INTO public.onboarding_audit_events (
    actor_id,
    organization_id,
    target_user_id,
    event_type,
    event_context
  ) VALUES (
    p_actor_id,
    p_organization_id,
    p_target_user_id,
    p_event_type,
    COALESCE(v_safe_context, '{}'::jsonb)
  );

  INSERT INTO public.audit_events (
    actor_id,
    event_type,
    event_context
  ) VALUES (
    p_actor_id,
    p_event_type,
    COALESCE(v_safe_context, '{}'::jsonb) || jsonb_build_object('organization_id', p_organization_id)
  );
END;
$$;

-- 5. RLS hardening.
DROP POLICY IF EXISTS user_profiles_self_manage ON public.user_profiles;
DROP POLICY IF EXISTS org_invites_admin_manage ON public.organization_invites;
DROP POLICY IF EXISTS user_suspensions_admin_manage ON public.user_suspensions;

ALTER TABLE public.role_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_definitions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.permission_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission_definitions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.organization_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invites FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_suspensions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_suspensions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.permission_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission_templates FORCE ROW LEVEL SECURITY;
ALTER TABLE public.permission_template_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission_template_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_audit_events FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_activation_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_activation_checks FORCE ROW LEVEL SECURITY;
ALTER TABLE public.org_activation_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.org_activation_checks FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.role_definitions FROM anon, authenticated, public;
REVOKE ALL ON public.permission_definitions FROM anon, authenticated, public;
REVOKE ALL ON public.role_permissions FROM anon, authenticated, public;
REVOKE ALL ON public.user_profiles FROM anon, authenticated, public;
REVOKE ALL ON public.organization_profiles FROM anon, authenticated, public;
REVOKE ALL ON public.organization_invites FROM anon, authenticated, public;
REVOKE ALL ON public.user_suspensions FROM anon, authenticated, public;
REVOKE ALL ON public.permission_templates FROM anon, authenticated, public;
REVOKE ALL ON public.permission_template_permissions FROM anon, authenticated, public;
REVOKE ALL ON public.role_assignments FROM anon, authenticated, public;
REVOKE ALL ON public.onboarding_requests FROM anon, authenticated, public;
REVOKE ALL ON public.onboarding_audit_events FROM anon, authenticated, public;
REVOKE ALL ON public.user_activation_checks FROM anon, authenticated, public;
REVOKE ALL ON public.org_activation_checks FROM anon, authenticated, public;

GRANT SELECT ON public.role_definitions TO authenticated;
GRANT SELECT ON public.permission_definitions TO authenticated;
GRANT SELECT ON public.role_permissions TO authenticated;
GRANT SELECT ON public.user_profiles TO authenticated;
GRANT SELECT ON public.organization_profiles TO authenticated;
GRANT SELECT ON public.organization_invites TO authenticated;
GRANT SELECT ON public.user_suspensions TO authenticated;
GRANT SELECT ON public.permission_templates TO authenticated;
GRANT SELECT ON public.permission_template_permissions TO authenticated;
GRANT SELECT ON public.role_assignments TO authenticated;
GRANT SELECT ON public.onboarding_requests TO authenticated;
GRANT SELECT ON public.onboarding_audit_events TO authenticated;
GRANT SELECT ON public.user_activation_checks TO authenticated;
GRANT SELECT ON public.org_activation_checks TO authenticated;

CREATE POLICY role_definitions_read
ON public.role_definitions
FOR SELECT TO authenticated
USING (true);

CREATE POLICY permission_definitions_read
ON public.permission_definitions
FOR SELECT TO authenticated
USING (true);

CREATE POLICY role_permissions_read
ON public.role_permissions
FOR SELECT TO authenticated
USING (true);

CREATE POLICY user_profiles_self_read
ON public.user_profiles
FOR SELECT TO authenticated
USING (user_id = auth.uid() AND NOT public.has_active_suspension(auth.uid()));

CREATE POLICY user_profiles_admin_read
ON public.user_profiles
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.role_assignments ra
    WHERE ra.user_id = user_profiles.user_id
      AND public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', ra.organization_id)
  )
);

CREATE POLICY organization_profiles_admin_read
ON public.organization_profiles
FOR SELECT TO authenticated
USING (
  public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', org_id)
  OR public.has_enterprise_permission(auth.uid(), 'can_view_compliance_reports', org_id)
);

CREATE POLICY organization_invites_admin_read
ON public.organization_invites
FOR SELECT TO authenticated
USING (public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id));

CREATE POLICY user_suspensions_admin_read
ON public.user_suspensions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.role_assignments ra
    WHERE ra.user_id = user_suspensions.user_id
      AND public.has_enterprise_permission(auth.uid(), 'can_suspend_user', ra.organization_id)
  )
);

CREATE POLICY permission_templates_admin_read
ON public.permission_templates
FOR SELECT TO authenticated
USING (public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id));

CREATE POLICY permission_template_permissions_admin_read
ON public.permission_template_permissions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.permission_templates pt
    WHERE pt.id = permission_template_permissions.template_id
      AND public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', pt.organization_id)
  )
);

CREATE POLICY role_assignments_admin_read
ON public.role_assignments
FOR SELECT TO authenticated
USING (public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id));

CREATE POLICY role_assignments_self_read
ON public.role_assignments
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  AND NOT public.has_active_suspension(auth.uid())
);

CREATE POLICY onboarding_requests_admin_read
ON public.onboarding_requests
FOR SELECT TO authenticated
USING (
  organization_id IS NOT NULL
  AND public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id)
);

CREATE POLICY onboarding_audit_admin_read
ON public.onboarding_audit_events
FOR SELECT TO authenticated
USING (
  organization_id IS NOT NULL
  AND (
    public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id)
    OR public.has_enterprise_permission(auth.uid(), 'can_view_compliance_reports', organization_id)
  )
);

CREATE POLICY user_activation_checks_admin_read
ON public.user_activation_checks
FOR SELECT TO authenticated
USING (public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id));

CREATE POLICY user_activation_checks_self_read
ON public.user_activation_checks
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  AND NOT public.has_active_suspension(auth.uid())
);

CREATE POLICY org_activation_checks_admin_read
ON public.org_activation_checks
FOR SELECT TO authenticated
USING (public.has_enterprise_permission(auth.uid(), 'can_manage_org_users', organization_id));

-- 6. Function privileges.
REVOKE ALL ON FUNCTION public.has_active_suspension(uuid) FROM anon, public;
REVOKE ALL ON FUNCTION public.has_enterprise_permission(uuid, text, uuid) FROM anon, public;
REVOKE ALL ON FUNCTION public.has_permission(uuid, text) FROM anon, public;
REVOKE ALL ON FUNCTION public.is_pilot_active(uuid) FROM anon, public;
REVOKE ALL ON FUNCTION public.is_enterprise_admin_for_org(uuid, uuid) FROM anon, public;
REVOKE ALL ON FUNCTION public.record_onboarding_audit(uuid, uuid, uuid, text, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.has_active_suspension(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_enterprise_permission(uuid, text, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_permission(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_pilot_active(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_enterprise_admin_for_org(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_onboarding_audit(uuid, uuid, uuid, text, jsonb) TO service_role;
