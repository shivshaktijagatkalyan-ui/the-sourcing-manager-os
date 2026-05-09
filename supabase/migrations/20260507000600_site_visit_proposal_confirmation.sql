-- Broker-to-Sourcing-Manager Site Visit Proposal and Confirmation Flow
-- Safe operational metadata only. Contact data remains outside these tables.

ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS public.site_visit_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  source_broker_id uuid NOT NULL REFERENCES public.brokers_public(id) ON DELETE CASCADE,
  source_lead_id uuid NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  assigned_sourcing_manager_id uuid NOT NULL REFERENCES auth.users(id),
  proposed_by uuid NOT NULL REFERENCES auth.users(id),
  reviewed_by uuid REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'proposed'
    CHECK (status IN ('proposed', 'accepted', 'scheduled', 'cancelled', 'rejected')),
  proposed_for timestamptz NOT NULL,
  scheduled_at timestamptz,
  notes_safe text,
  review_notes_safe text,
  accepted_at timestamptz,
  rejected_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.site_visits
  ADD COLUMN IF NOT EXISTS proposal_id uuid REFERENCES public.site_visit_proposals(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS property_name text,
  ADD COLUMN IF NOT EXISTS area text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS visit_date timestamptz,
  ADD COLUMN IF NOT EXISTS client_reached_at timestamptz,
  ADD COLUMN IF NOT EXISTS visit_done_at timestamptz,
  ADD COLUMN IF NOT EXISTS no_show_at timestamptz,
  ADD COLUMN IF NOT EXISTS visit_code_hash text,
  ADD COLUMN IF NOT EXISTS qr_code_hash text,
  ADD COLUMN IF NOT EXISTS qr_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS visit_code_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS proof_status text NOT NULL DEFAULT 'pending'
    CHECK (proof_status IN ('pending', 'partial', 'verified', 'rejected'));

ALTER TABLE public.site_visits
  DROP CONSTRAINT IF EXISTS site_visits_status_check;

ALTER TABLE public.site_visits
  ADD CONSTRAINT site_visits_status_check CHECK (status IN (
    'proposed',
    'accepted',
    'scheduled',
    'client_reached_site',
    'gps_verified',
    'qr_verified',
    'photo_uploaded',
    'visit_done',
    'broker_review_pending',
    'completed',
    'no_show',
    'cancelled',
    'rejected',
    'arrived',
    'verified',
    'started',
    'gps_submitted',
    'photo_submitted',
    'photo_verified',
    'invalid',
    'disputed'
  ));

CREATE TABLE IF NOT EXISTS public.site_visit_confirmations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  site_visit_id uuid NOT NULL REFERENCES public.site_visits(id) ON DELETE CASCADE,
  source_broker_id uuid REFERENCES public.brokers_public(id) ON DELETE SET NULL,
  source_lead_id uuid REFERENCES public.leads_public(id) ON DELETE SET NULL,
  project_id uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  sourcing_manager_id uuid NOT NULL REFERENCES auth.users(id),
  proof_type text NOT NULL
    CHECK (proof_type IN ('arrival', 'gps', 'qr', 'visit_code', 'photo', 'visit_done', 'no_show')),
  status text NOT NULL
    CHECK (status IN (
      'client_reached_site',
      'gps_verified',
      'qr_verified',
      'photo_uploaded',
      'visit_done',
      'no_show',
      'rejected'
    )),
  submitted_lat numeric,
  submitted_lng numeric,
  gps_accuracy_meters numeric,
  distance_from_project_meters numeric,
  proof_ref_hash text,
  photo_storage_path text,
  verified_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_site_visit_proposals_org_status
  ON public.site_visit_proposals(organization_id, status, proposed_for);
CREATE INDEX IF NOT EXISTS idx_site_visit_proposals_broker_status
  ON public.site_visit_proposals(source_broker_id, status, proposed_for);
CREATE INDEX IF NOT EXISTS idx_site_visit_proposals_sm_status
  ON public.site_visit_proposals(assigned_sourcing_manager_id, status, proposed_for);
CREATE INDEX IF NOT EXISTS idx_site_visit_confirmations_visit_status
  ON public.site_visit_confirmations(site_visit_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_site_visits_proposal
  ON public.site_visits(proposal_id);
CREATE INDEX IF NOT EXISTS idx_site_visits_safe_status
  ON public.site_visits(organization_id, sourcing_manager_id, status, scheduled_at);

DROP TRIGGER IF EXISTS set_site_visit_proposals_updated_at ON public.site_visit_proposals;
CREATE TRIGGER set_site_visit_proposals_updated_at
BEFORE UPDATE ON public.site_visit_proposals
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.site_visit_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_visit_proposals FORCE ROW LEVEL SECURITY;
ALTER TABLE public.site_visit_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_visit_confirmations FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.site_visit_proposals FROM anon, public;
REVOKE INSERT, UPDATE, DELETE ON public.site_visit_proposals FROM authenticated;
GRANT SELECT ON public.site_visit_proposals TO authenticated;

REVOKE ALL ON public.site_visit_confirmations FROM anon, public;
REVOKE INSERT, UPDATE, DELETE ON public.site_visit_confirmations FROM authenticated;
GRANT SELECT ON public.site_visit_confirmations TO authenticated;

DROP POLICY IF EXISTS site_visit_proposals_linked_broker_read ON public.site_visit_proposals;
CREATE POLICY site_visit_proposals_linked_broker_read
ON public.site_visit_proposals
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.id = source_broker_id
      AND bp.linked_user_id = auth.uid()
      AND bp.organization_id = site_visit_proposals.organization_id
      AND bp.status = 'active'
  )
);

DROP POLICY IF EXISTS site_visit_proposals_sm_read ON public.site_visit_proposals;
CREATE POLICY site_visit_proposals_sm_read
ON public.site_visit_proposals
FOR SELECT TO authenticated
USING (
  assigned_sourcing_manager_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

DROP POLICY IF EXISTS site_visit_confirmations_linked_broker_read ON public.site_visit_confirmations;
CREATE POLICY site_visit_confirmations_linked_broker_read
ON public.site_visit_confirmations
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.id = source_broker_id
      AND bp.linked_user_id = auth.uid()
      AND bp.organization_id = site_visit_confirmations.organization_id
      AND bp.status = 'active'
  )
);

DROP POLICY IF EXISTS site_visit_confirmations_sm_read ON public.site_visit_confirmations;
CREATE POLICY site_visit_confirmations_sm_read
ON public.site_visit_confirmations
FOR SELECT TO authenticated
USING (
  sourcing_manager_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

-- Existing audit_events remains append-only and receives only safe IDs/status context from Edge Functions.
