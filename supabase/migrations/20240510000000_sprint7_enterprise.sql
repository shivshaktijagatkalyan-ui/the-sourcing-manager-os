-- Sprint 7: Enterprise Onboarding & Role Operations
-- Migration: 20240510000000_sprint7_enterprise.sql

-- 1. Role and Permission Definitions
CREATE TABLE public.role_definitions (
    id text PRIMARY KEY, -- e.g. 'broker_owner', 'caller'
    name text NOT NULL,
    description text,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.permission_definitions (
    id text PRIMARY KEY, -- e.g. 'can_call_leads', 'can_view_payouts'
    name text NOT NULL,
    description text,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.role_permissions (
    role_id text REFERENCES public.role_definitions(id) ON DELETE CASCADE,
    permission_id text REFERENCES public.permission_definitions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 2. User Profiles (Role-Gated Metadata)
CREATE TABLE public.user_profiles (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    avatar_url text,
    professional_id text, -- RERA ID / Emp ID
    kyc_status text DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
    onboarding_completed_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 3. Organization Invites
CREATE TABLE public.organization_invites (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    invited_email text NOT NULL,
    target_role text NOT NULL REFERENCES public.role_definitions(id),
    inviter_user_id uuid NOT NULL REFERENCES auth.users(id),
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
    expires_at timestamptz NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- 4. User Suspensions (Fail-Closed)
CREATE TABLE public.user_suspensions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    suspended_by uuid NOT NULL REFERENCES auth.users(id),
    reason text NOT NULL,
    starts_at timestamptz NOT NULL DEFAULT now(),
    ends_at timestamptz, -- NULL means permanent until manual lift
    created_at timestamptz DEFAULT now()
);

-- 5. Helper Function: Check Permission
CREATE OR REPLACE FUNCTION public.has_permission(p_user_id uuid, p_permission text)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.pilot_users pu
        JOIN public.role_permissions rp ON pu.role = rp.role_id
        WHERE pu.user_id = p_user_id
          AND pu.status = 'active'
          AND rp.permission_id = p_permission
    ) AND NOT EXISTS (
        SELECT 1 FROM public.user_suspensions
        WHERE user_id = p_user_id
          AND starts_at <= now()
          AND (ends_at IS NULL OR ends_at > now())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Seed Core Roles & Permissions
INSERT INTO public.role_definitions (id, name) VALUES 
('platform_admin', 'Platform Admin'),
('developer_admin', 'Developer Admin'),
('broker_owner', 'Broker Owner'),
('broker_agent', 'Broker Agent'),
('sourcing_manager', 'Sourcing Manager'),
('caller', 'Caller'),
('compliance_admin', 'Compliance Admin'),
('read_only_auditor', 'Auditor');

INSERT INTO public.permission_definitions (id, name) VALUES 
('can_upload_leads', 'Upload Leads'),
('can_grant_data_loans', 'Grant Data Loans'),
('can_call_leads', 'Call Leads'),
('can_create_site_visits', 'Create Site Visits'),
('can_verify_site_visits', 'Verify Site Visits'),
('can_review_site_visits', 'Review Site Visits'),
('can_view_payouts', 'View Payouts'),
('can_manage_org_users', 'Manage Org Users'),
('can_pause_org', 'Pause Organization');

-- Seed Standard Role Permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 'broker_owner', id FROM public.permission_definitions; -- All except system-wide ones?

-- 7. RLS for Sprint 7
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_suspensions ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_profiles_self_manage ON public.user_profiles
    FOR ALL TO authenticated USING (auth.uid() = user_id);

CREATE POLICY org_invites_admin_manage ON public.organization_invites
    FOR ALL TO authenticated USING (public.has_permission(auth.uid(), 'can_manage_org_users'));

CREATE POLICY user_suspensions_admin_manage ON public.user_suspensions
    FOR ALL TO authenticated USING (public.has_permission(auth.uid(), 'can_manage_org_users'));

-- 8. Updated At Triggers
CREATE TRIGGER set_user_profiles_updated_at
BEFORE UPDATE ON public.user_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
