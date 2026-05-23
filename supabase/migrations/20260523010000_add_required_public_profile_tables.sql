-- Add missing role profile, proof mirror, and developer lead bank tables.
-- All tables are metadata-only. Restricted buyer contact data remains in the
-- existing sensitive storage and protected Edge Function flows.

CREATE TABLE IF NOT EXISTS public.sourcing_managers_public (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  linked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  manager_name text NOT NULL,
  city text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'suspended', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (linked_user_id),
  CONSTRAINT sourcing_managers_public_name_not_blank CHECK (btrim(manager_name) <> '')
);

CREATE INDEX IF NOT EXISTS idx_sourcing_managers_public_org_status
ON public.sourcing_managers_public(organization_id, status);

CREATE TABLE IF NOT EXISTS public.caller_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  linked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  caller_name text NOT NULL,
  city text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'suspended', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (linked_user_id),
  CONSTRAINT caller_profiles_name_not_blank CHECK (btrim(caller_name) <> '')
);

CREATE INDEX IF NOT EXISTS idx_caller_profiles_org_status
ON public.caller_profiles(organization_id, status);

CREATE TABLE IF NOT EXISTS public.developer_lead_bank (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  project_id uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  lead_id uuid REFERENCES public.leads_public(id) ON DELETE SET NULL,
  source_broker_id uuid REFERENCES public.brokers_public(id) ON DELETE SET NULL,
  assigned_sourcing_manager_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  lead_alias text NOT NULL,
  lifecycle_status text NOT NULL DEFAULT 'new'
    CHECK (lifecycle_status IN (
      'new',
      'assigned',
      'loan_active',
      'call_in_progress',
      'visit_proposed',
      'visit_verified',
      'locked',
      'closed',
      'lost',
      'archived'
    )),
  attribution_status text NOT NULL DEFAULT 'unlocked'
    CHECK (attribution_status IN ('unlocked', 'locked', 'disputed', 'expired')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT developer_lead_bank_alias_not_blank CHECK (btrim(lead_alias) <> '')
);

CREATE INDEX IF NOT EXISTS idx_developer_lead_bank_org_status
ON public.developer_lead_bank(organization_id, lifecycle_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_developer_lead_bank_project
ON public.developer_lead_bank(project_id, lifecycle_status)
WHERE project_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_developer_lead_bank_lead_unique
ON public.developer_lead_bank(lead_id)
WHERE lead_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.site_visit_proofs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  site_visit_id uuid NOT NULL REFERENCES public.site_visits(id) ON DELETE CASCADE,
  confirmation_id uuid UNIQUE REFERENCES public.site_visit_confirmations(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_site_visit_proofs_visit_status
ON public.site_visit_proofs(site_visit_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_site_visit_proofs_org_type
ON public.site_visit_proofs(organization_id, proof_type, created_at DESC);

DROP TRIGGER IF EXISTS set_sourcing_managers_public_updated_at
ON public.sourcing_managers_public;
CREATE TRIGGER set_sourcing_managers_public_updated_at
BEFORE UPDATE ON public.sourcing_managers_public
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_caller_profiles_updated_at
ON public.caller_profiles;
CREATE TRIGGER set_caller_profiles_updated_at
BEFORE UPDATE ON public.caller_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_developer_lead_bank_updated_at
ON public.developer_lead_bank;
CREATE TRIGGER set_developer_lead_bank_updated_at
BEFORE UPDATE ON public.developer_lead_bank
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.mirror_site_visit_confirmation_to_proof()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.site_visit_proofs (
    organization_id,
    site_visit_id,
    confirmation_id,
    source_broker_id,
    source_lead_id,
    project_id,
    sourcing_manager_id,
    proof_type,
    status,
    submitted_lat,
    submitted_lng,
    gps_accuracy_meters,
    distance_from_project_meters,
    proof_ref_hash,
    photo_storage_path,
    verified_by,
    created_at
  )
  VALUES (
    NEW.organization_id,
    NEW.site_visit_id,
    NEW.id,
    NEW.source_broker_id,
    NEW.source_lead_id,
    NEW.project_id,
    NEW.sourcing_manager_id,
    NEW.proof_type,
    NEW.status,
    NEW.submitted_lat,
    NEW.submitted_lng,
    NEW.gps_accuracy_meters,
    NEW.distance_from_project_meters,
    NEW.proof_ref_hash,
    NEW.photo_storage_path,
    NEW.verified_by,
    NEW.created_at
  )
  ON CONFLICT (confirmation_id) DO UPDATE SET
    status = EXCLUDED.status,
    submitted_lat = EXCLUDED.submitted_lat,
    submitted_lng = EXCLUDED.submitted_lng,
    gps_accuracy_meters = EXCLUDED.gps_accuracy_meters,
    distance_from_project_meters = EXCLUDED.distance_from_project_meters,
    proof_ref_hash = EXCLUDED.proof_ref_hash,
    photo_storage_path = EXCLUDED.photo_storage_path,
    verified_by = EXCLUDED.verified_by;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS mirror_site_visit_confirmation_to_proof
ON public.site_visit_confirmations;
CREATE TRIGGER mirror_site_visit_confirmation_to_proof
AFTER INSERT ON public.site_visit_confirmations
FOR EACH ROW EXECUTE FUNCTION public.mirror_site_visit_confirmation_to_proof();

INSERT INTO public.site_visit_proofs (
  organization_id,
  site_visit_id,
  confirmation_id,
  source_broker_id,
  source_lead_id,
  project_id,
  sourcing_manager_id,
  proof_type,
  status,
  submitted_lat,
  submitted_lng,
  gps_accuracy_meters,
  distance_from_project_meters,
  proof_ref_hash,
  photo_storage_path,
  verified_by,
  created_at
)
SELECT
  organization_id,
  site_visit_id,
  id,
  source_broker_id,
  source_lead_id,
  project_id,
  sourcing_manager_id,
  proof_type,
  status,
  submitted_lat,
  submitted_lng,
  gps_accuracy_meters,
  distance_from_project_meters,
  proof_ref_hash,
  photo_storage_path,
  verified_by,
  created_at
FROM public.site_visit_confirmations
ON CONFLICT (confirmation_id) DO NOTHING;

ALTER TABLE public.sourcing_managers_public ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sourcing_managers_public FORCE ROW LEVEL SECURITY;
ALTER TABLE public.caller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caller_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.developer_lead_bank ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.developer_lead_bank FORCE ROW LEVEL SECURITY;
ALTER TABLE public.site_visit_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_visit_proofs FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.sourcing_managers_public FROM anon, public;
REVOKE INSERT, UPDATE, DELETE ON public.sourcing_managers_public FROM authenticated;
GRANT SELECT ON public.sourcing_managers_public TO authenticated;

REVOKE ALL ON public.caller_profiles FROM anon, public;
REVOKE INSERT, UPDATE, DELETE ON public.caller_profiles FROM authenticated;
GRANT SELECT ON public.caller_profiles TO authenticated;

REVOKE ALL ON public.developer_lead_bank FROM anon, public;
REVOKE INSERT, UPDATE, DELETE ON public.developer_lead_bank FROM authenticated;
GRANT SELECT ON public.developer_lead_bank TO authenticated;

REVOKE ALL ON public.site_visit_proofs FROM anon, public;
REVOKE INSERT, UPDATE, DELETE ON public.site_visit_proofs FROM authenticated;
GRANT SELECT ON public.site_visit_proofs TO authenticated;

DROP POLICY IF EXISTS sourcing_managers_public_org_read
ON public.sourcing_managers_public;
CREATE POLICY sourcing_managers_public_org_read
ON public.sourcing_managers_public
FOR SELECT TO authenticated
USING (
  linked_user_id = auth.uid()
  OR organization_id IN (
    SELECT pu.org_id
    FROM public.pilot_users pu
    WHERE pu.user_id = auth.uid()
      AND pu.status = 'active'
  )
);

DROP POLICY IF EXISTS caller_profiles_org_read
ON public.caller_profiles;
CREATE POLICY caller_profiles_org_read
ON public.caller_profiles
FOR SELECT TO authenticated
USING (
  linked_user_id = auth.uid()
  OR organization_id IN (
    SELECT pu.org_id
    FROM public.pilot_users pu
    WHERE pu.user_id = auth.uid()
      AND pu.status = 'active'
  )
);

DROP POLICY IF EXISTS developer_lead_bank_org_read
ON public.developer_lead_bank;
CREATE POLICY developer_lead_bank_org_read
ON public.developer_lead_bank
FOR SELECT TO authenticated
USING (
  organization_id IN (
    SELECT pu.org_id
    FROM public.pilot_users pu
    WHERE pu.user_id = auth.uid()
      AND pu.status = 'active'
  )
);

DROP POLICY IF EXISTS site_visit_proofs_participant_read
ON public.site_visit_proofs;
CREATE POLICY site_visit_proofs_participant_read
ON public.site_visit_proofs
FOR SELECT TO authenticated
USING (
  sourcing_manager_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.id = site_visit_proofs.source_broker_id
      AND bp.linked_user_id = auth.uid()
      AND bp.organization_id = site_visit_proofs.organization_id
      AND bp.status = 'active'
  )
  OR organization_id IN (
    SELECT pu.org_id
    FROM public.pilot_users pu
    WHERE pu.user_id = auth.uid()
      AND pu.status = 'active'
      AND pu.role IN ('admin', 'platform_admin', 'developer_admin')
  )
);
