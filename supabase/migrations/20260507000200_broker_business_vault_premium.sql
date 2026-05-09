-- Premium Broker Business Vault fields.
-- Public tables receive safe metadata only. Contact ciphertext stays in sensitive tables.

ALTER TABLE public.brokers_public
  ADD COLUMN IF NOT EXISTS broker_code text,
  ADD COLUMN IF NOT EXISTS verified_status text NOT NULL DEFAULT 'verified_active',
  ADD COLUMN IF NOT EXISTS verified_performance_rank text NOT NULL DEFAULT 'Silver';

CREATE UNIQUE INDEX IF NOT EXISTS idx_brokers_public_broker_code
ON public.brokers_public(broker_code)
WHERE broker_code IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'brokers_public_verified_status_check'
  ) THEN
    ALTER TABLE public.brokers_public
      ADD CONSTRAINT brokers_public_verified_status_check
      CHECK (verified_status IN ('pending_verification', 'verified_active', 'paused', 'rejected'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'brokers_public_verified_performance_rank_check'
  ) THEN
    ALTER TABLE public.brokers_public
      ADD CONSTRAINT brokers_public_verified_performance_rank_check
      CHECK (verified_performance_rank IN ('Unranked', 'Bronze', 'Silver', 'Gold', 'Review'));
  END IF;
END $$;

ALTER TABLE public.leads_public
  ADD COLUMN IF NOT EXISTS assigned_sourcing_manager_id uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS lead_quality text NOT NULL DEFAULT 'warm',
  ADD COLUMN IF NOT EXISTS lead_temperature text NOT NULL DEFAULT 'warm',
  ADD COLUMN IF NOT EXISTS buyer_type text NOT NULL DEFAULT 'end_user',
  ADD COLUMN IF NOT EXISTS project_match_status text NOT NULL DEFAULT 'project_matched',
  ADD COLUMN IF NOT EXISTS next_followup_at timestamptz,
  ADD COLUMN IF NOT EXISTS broker_notes_safe text,
  ADD COLUMN IF NOT EXISTS conversion_stage text NOT NULL DEFAULT 'lead_received',
  ADD COLUMN IF NOT EXISTS booking_stage text NOT NULL DEFAULT 'not_started',
  ADD COLUMN IF NOT EXISTS brokerage_status text NOT NULL DEFAULT 'tracking',
  ADD COLUMN IF NOT EXISTS data_quality_score int NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_leads_public_broker_vault_queue
ON public.leads_public(source_broker_id, conversion_stage, next_followup_at)
WHERE source_broker_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_leads_public_assigned_sm
ON public.leads_public(assigned_sourcing_manager_id)
WHERE assigned_sourcing_manager_id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_lead_quality_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_lead_quality_check
      CHECK (lead_quality IN (
        'hot',
        'warm',
        'cold',
        'investor',
        'end_user',
        'budget_matched',
        'location_matched',
        'project_matched',
        'duplicate_risk',
        'low_quality',
        'loan_required',
        'family_decision_pending',
        'site_visit_ready'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_lead_temperature_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_lead_temperature_check
      CHECK (lead_temperature IN ('hot', 'warm', 'cold'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_buyer_type_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_buyer_type_check
      CHECK (buyer_type IN ('investor', 'end_user', 'unknown'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_project_match_status_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_project_match_status_check
      CHECK (project_match_status IN (
        'budget_matched',
        'location_matched',
        'project_matched',
        'mismatch',
        'unknown'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_conversion_stage_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_conversion_stage_check
      CHECK (conversion_stage IN (
        'lead_received',
        'call_pending',
        'assigned_to_caller',
        'assigned_to_sm',
        'called',
        'interested',
        'call_later',
        'not_reachable',
        'visit_scheduled',
        'visit_verified',
        'booking_discussion',
        'token_discussion',
        'closed',
        'lost'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_booking_stage_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_booking_stage_check
      CHECK (booking_stage IN (
        'not_started',
        'booking_discussion',
        'token_discussion',
        'token_paid',
        'booking_confirmed',
        'loan_legal_started',
        'agreement_pending',
        'payment_pending',
        'closed',
        'lost'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_brokerage_status_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_brokerage_status_check
      CHECK (brokerage_status IN (
        'tracking',
        'pending_visit',
        'locked',
        'eligible',
        'paid',
        'disputed',
        'blocked'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leads_public_data_quality_score_check'
  ) THEN
    ALTER TABLE public.leads_public
      ADD CONSTRAINT leads_public_data_quality_score_check
      CHECK (data_quality_score >= 0 AND data_quality_score <= 100);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.broker_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  broker_id uuid NOT NULL REFERENCES public.brokers_public(id) ON DELETE CASCADE,
  lead_id uuid REFERENCES public.leads_public(id) ON DELETE SET NULL,
  raised_by uuid NOT NULL REFERENCES auth.users(id),
  issue_type text NOT NULL,
  notes_safe text,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT broker_issues_issue_type_check CHECK (
    issue_type IN ('brokerage_credit', 'site_visit_proof', 'caller_support', 'data_access', 'other')
  ),
  CONSTRAINT broker_issues_status_check CHECK (status IN ('open', 'reviewing', 'resolved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_broker_issues_broker_status
ON public.broker_issues(broker_id, status, created_at DESC);

DROP TRIGGER IF EXISTS set_broker_issues_updated_at ON public.broker_issues;
CREATE TRIGGER set_broker_issues_updated_at
BEFORE UPDATE ON public.broker_issues
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.broker_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broker_issues FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS broker_issues_linked_broker_read ON public.broker_issues;
CREATE POLICY broker_issues_linked_broker_read
ON public.broker_issues
FOR SELECT TO authenticated
USING (public.is_linked_broker_user(broker_id, auth.uid()));

DROP POLICY IF EXISTS broker_issues_linked_broker_insert ON public.broker_issues;
CREATE POLICY broker_issues_linked_broker_insert
ON public.broker_issues
FOR INSERT TO authenticated
WITH CHECK (
  raised_by = auth.uid()
  AND public.is_linked_broker_user(broker_id, auth.uid())
);

DROP POLICY IF EXISTS broker_issues_manager_read ON public.broker_issues;
CREATE POLICY broker_issues_manager_read
ON public.broker_issues
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.id = broker_issues.broker_id
      AND (
        bp.assigned_sourcing_manager_id = auth.uid()
        OR public.can_manage_broker_crm(bp.organization_id)
      )
  )
);

DROP POLICY IF EXISTS broker_issues_manager_update ON public.broker_issues;
CREATE POLICY broker_issues_manager_update
ON public.broker_issues
FOR UPDATE TO authenticated
USING (public.can_manage_broker_crm(organization_id))
WITH CHECK (public.can_manage_broker_crm(organization_id));
