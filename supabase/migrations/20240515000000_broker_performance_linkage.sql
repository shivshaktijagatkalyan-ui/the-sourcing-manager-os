-- Practical MVP v0.1: Step 6 - Site Visit Tracker Connection
-- Migration: 20240515000000_broker_performance_linkage.sql

-- 1. Extend leads_public to link to external brokers
ALTER TABLE public.leads_public
  ADD COLUMN IF NOT EXISTS source_broker_id uuid REFERENCES public.brokers_public(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

-- 2. Extend site_visits to link to external brokers and leads
ALTER TABLE public.site_visits
  ADD COLUMN IF NOT EXISTS source_broker_id uuid REFERENCES public.brokers_public(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS source_lead_id uuid REFERENCES public.leads_public(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

-- 3. Update Indexes for Performance Reporting
CREATE INDEX IF NOT EXISTS idx_leads_public_source_broker ON public.leads_public(source_broker_id, lead_status);
CREATE INDEX IF NOT EXISTS idx_site_visits_source_broker ON public.site_visits(source_broker_id, status);
CREATE INDEX IF NOT EXISTS idx_site_visits_org_status ON public.site_visits(organization_id, status, scheduled_at);

-- 4. RLS for Site Visits (Updated for Organization Scoping)
DROP POLICY IF EXISTS site_visits_manager_read ON public.site_visits;
CREATE POLICY site_visits_manager_read ON public.site_visits
FOR SELECT TO authenticated
USING (
  sourcing_manager_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

-- 5. Audit Logging for Performance Connections
CREATE OR REPLACE FUNCTION public.audit_site_visit_linkage()
RETURNS trigger AS $$
BEGIN
  IF (NEW.source_broker_id IS NOT NULL AND (OLD.source_broker_id IS NULL OR OLD.source_broker_id <> NEW.source_broker_id)) THEN
    PERFORM public.record_audit(
      auth.uid(),
      'site_visit_broker_linked',
      jsonb_build_object(
        'site_visit_id', NEW.id,
        'broker_id', NEW.source_broker_id,
        'lead_id', NEW.lead_id
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_site_visit_broker_link
AFTER UPDATE ON public.site_visits
FOR EACH ROW EXECUTE FUNCTION public.audit_site_visit_linkage();
