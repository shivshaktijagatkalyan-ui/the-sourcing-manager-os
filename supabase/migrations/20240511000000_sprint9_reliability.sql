-- Sprint 9: Reliability, Monitoring, Backups & Rollback
-- Migration: 20240511000000_sprint9_reliability.sql

-- 1. System Health & Failure Tracking
CREATE TABLE public.system_health_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    status text NOT NULL CHECK (status IN ('healthy', 'degraded', 'incident', 'maintenance')),
    severity text NOT NULL CHECK (severity IN ('info', 'low', 'medium', 'high', 'critical')),
    event_type text NOT NULL, -- e.g. 'edge_function_error', 'provider_outage'
    event_message text,
    event_context jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.edge_function_failures (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    function_name text NOT NULL,
    error_code text,
    error_message text, -- Sanitized
    severity text NOT NULL,
    actor_id uuid REFERENCES auth.users(id),
    organization_id uuid REFERENCES public.organizations(id),
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.provider_failures (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL, -- e.g. 'exotel', 'supabase_storage'
    event_type text NOT NULL,
    status_code integer,
    reason_code text,
    severity text NOT NULL,
    resolved boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- 2. Deployment & Rollback Tracking
CREATE TABLE public.deployment_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version text NOT NULL,
    deployment_type text NOT NULL, -- e.g. 'edge_function', 'migration', 'flutter_build'
    status text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.rollback_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    deployment_id uuid REFERENCES public.deployment_events(id),
    reason text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- 3. Rate Limiting & Abuse Throttling
CREATE TABLE public.rate_limit_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id uuid REFERENCES auth.users(id),
    organization_id uuid REFERENCES public.organizations(id),
    action text NOT NULL,
    limit_key text NOT NULL,
    blocked_at timestamptz DEFAULT now()
);

-- 4. Backup & Restore Records
CREATE TABLE public.backup_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_type text NOT NULL CHECK (run_type IN ('daily', 'manual', 'pre_deployment')),
    status text NOT NULL CHECK (status IN ('success', 'failed')),
    verification_metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.restore_drills (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    drill_date date DEFAULT current_date,
    status text NOT NULL,
    outcome_notes text,
    verified_by uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now()
);

-- 5. RLS for Sprint 9 (Admin Only)
ALTER TABLE public.system_health_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_function_failures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_failures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deployment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rollback_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restore_drills ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_only_reliability ON public.system_health_events
    USING (public.is_pilot_admin(auth.uid()));

CREATE POLICY admin_only_edge_failures ON public.edge_function_failures
    USING (public.is_pilot_admin(auth.uid()));

CREATE POLICY admin_only_provider_failures ON public.provider_failures
    USING (public.is_pilot_admin(auth.uid()));

CREATE POLICY admin_only_deployments ON public.deployment_events
    USING (public.is_pilot_admin(auth.uid()));

CREATE POLICY admin_only_backups ON public.backup_runs
    USING (public.is_pilot_admin(auth.uid()));

-- 6. Helper Function: Record Edge Failure (Sanitized)
CREATE OR REPLACE FUNCTION public.log_edge_failure(
    p_function_name text,
    p_error_code text,
    p_error_message text,
    p_severity text,
    p_actor_id uuid DEFAULT NULL,
    p_org_id uuid DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO public.edge_function_failures (
        function_name, error_code, error_message, severity, actor_id, organization_id
    ) VALUES (
        p_function_name, p_error_code, p_error_message, p_severity, p_actor_id, p_org_id
    ) RETURNING id INTO v_id;

    INSERT INTO public.system_health_events (
        status, severity, event_type, event_message, event_context
    ) VALUES (
        'degraded', p_severity, 'edge_function_error', p_function_name || ': ' || p_error_code,
        jsonb_build_object('failure_id', v_id)
    );

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
