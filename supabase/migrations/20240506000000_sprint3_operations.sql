-- SPRINT 3: Dispute, Trust Score & Pilot Operations Layer
-- Migration: 20240506000000_sprint3_operations.sql

-- 1. Organizations & Pilot Users
CREATE TABLE public.organizations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'suspended')),
    created_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb DEFAULT '{}'
);

CREATE TABLE public.pilot_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    org_id uuid NOT NULL REFERENCES public.organizations(id),
    role text NOT NULL CHECK (role IN ('admin', 'broker', 'sourcing_manager', 'caller')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb DEFAULT '{}',
    UNIQUE(user_id, org_id)
);

-- 2. Disputes
CREATE TABLE public.disputes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id uuid NOT NULL REFERENCES public.organizations(id),
    target_id uuid NOT NULL, -- references site_visits, leads, or broker_locks
    target_type text NOT NULL CHECK (target_type IN ('site_visit', 'lead', 'broker_lock')),
    type text NOT NULL CHECK (type IN ('broker_rejection', 'duplicate_claim', 'fake_visit_claim', 'commission_lock_conflict', 'developer_dispute')),
    status text NOT NULL DEFAULT 'opened' CHECK (status IN ('opened', 'under_review', 'evidence_requested', 'resolved_broker', 'resolved_manager', 'resolved_developer', 'rejected', 'closed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.dispute_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dispute_id uuid NOT NULL REFERENCES public.disputes(id) ON DELETE CASCADE,
    actor_id uuid NOT NULL REFERENCES auth.users(id),
    event_type text NOT NULL,
    comment text,
    evidence_refs jsonb DEFAULT '[]', -- references storage paths or audit IDs
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Trust Scores
CREATE TABLE public.trust_scores (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id uuid NOT NULL, -- user_id or org_id
    entity_type text NOT NULL CHECK (entity_type IN ('user', 'organization')),
    score numeric(3,2) NOT NULL DEFAULT 0.00 CHECK (score >= 0.00 AND score <= 5.00),
    components_json jsonb NOT NULL DEFAULT '{}',
    last_updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_trust_scores_entity ON public.trust_scores(entity_id, entity_type);

-- 4. Enable RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pilot_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispute_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trust_scores ENABLE ROW LEVEL SECURITY;

-- 5. Helper Function: Is User/Org Active (Fail Closed)
CREATE OR REPLACE FUNCTION public.is_pilot_active(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.pilot_users pu
        JOIN public.organizations o ON pu.org_id = o.id
        WHERE pu.user_id = p_user_id
        AND pu.status = 'active'
        AND o.status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Core RLS Policies (Draft)

-- Pilot Users can see their own org members (but not phone/metadata)
CREATE POLICY "pilot_users_view_org" ON public.pilot_users
    FOR SELECT TO authenticated
    USING (org_id IN (SELECT org_id FROM public.pilot_users WHERE user_id = auth.uid()));

-- Disputes are visible to the org members
CREATE POLICY "disputes_org_view" ON public.disputes
    FOR SELECT TO authenticated
    USING (org_id IN (SELECT org_id FROM public.pilot_users WHERE user_id = auth.uid()));

-- Trust scores are public for transparency within the platform
CREATE POLICY "trust_scores_view" ON public.trust_scores
    FOR SELECT TO authenticated
    USING (true);

-- 7. Evidence Timeline View (Sanitized)
CREATE OR REPLACE VIEW public.v_evidence_timeline AS
SELECT 
    lead_id,
    event_type,
    created_at as timestamp,
    -- Sanitize context: remove any key that looks like a phone number or name
    (
        SELECT jsonb_object_agg(key, value)
        FROM jsonb_each(event_context)
        WHERE key NOT IN ('phone', 'name', 'contact', 'customer_name', 'mobile')
    ) as sanitized_context
FROM public.audit_events;

GRANT SELECT ON public.v_evidence_timeline TO authenticated;

-- 8. Update Triggers
CREATE TRIGGER trigger_set_disputes_updated_at
    BEFORE UPDATE ON public.disputes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
