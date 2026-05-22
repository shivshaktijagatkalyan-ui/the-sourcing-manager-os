-- Migration: 20260516000100_ai_data_churn_engine.sql
-- Description: Enables AI-driven lead qualification for bulk cold data.

-- 1. Update lead_status constraints
ALTER TABLE public.leads_public DROP CONSTRAINT IF EXISTS leads_public_status_check;
ALTER TABLE public.leads_public ADD CONSTRAINT leads_public_status_check CHECK (
  lead_status IN (
    'new', 'cold', 'churning', 'interested', 'dead',
    'loan_active', 'call_queued', 'call_blocked', 
    'visit_scheduled', 'visit_verified', 'locked', 'revoked'
  )
);

-- 2. Update call_attempts constraints (if not already expanded)
ALTER TABLE public.call_attempts DROP CONSTRAINT IF EXISTS call_attempts_status_check;
ALTER TABLE public.call_attempts ADD CONSTRAINT call_attempts_status_check CHECK (
  call_status IN (
    'connecting', 'queued', 'blocked', 'expired', 'revoked', 
    'dnd_blocked', 'consent_required', 'provider_failed', 
    'completed', 'failed', 'ai_queued', 'ai_in_progress', 
    'ai_provider_failed', 'config_error', 'ai_churn_active'
  )
);

-- 3. Create Churn Campaign tracking
CREATE TABLE IF NOT EXISTS public.churn_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  project_id UUID REFERENCES public.projects(id), -- Campaigns can be project-specific
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft', -- draft, active, paused, completed
  total_leads INT DEFAULT 0,
  leads_qualified INT DEFAULT 0,
  leads_dead INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT churn_campaigns_status_check CHECK (status IN ('draft', 'active', 'paused', 'completed'))
);

-- 4. Link leads to churn campaigns
ALTER TABLE public.leads_public ADD COLUMN IF NOT EXISTS churn_campaign_id UUID REFERENCES public.churn_campaigns(id);

-- 5. RLS for Churn Campaigns
ALTER TABLE public.churn_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.churn_campaigns FORCE ROW LEVEL SECURITY;

CREATE POLICY churn_campaigns_org_read ON public.churn_campaigns
FOR SELECT TO authenticated
USING (organization_id IN (
  SELECT organization_id FROM public.role_assignments WHERE user_id = auth.uid()
));

-- 6. Audit logging for Churn
COMMENT ON TABLE public.churn_campaigns IS 'Tracks AI-driven lead qualification campaigns for bulk cold data.';
