-- Practical MVP v0.1: Sourcing Manager CRM Database Model
-- Focus: External broker management for Vinod @ Wadhwa Wise City, Panvel.

-- 1. Extend Permissions for CRM
INSERT INTO public.permission_definitions (id, name, description) VALUES
  ('can_manage_broker_crm', 'Manage Broker CRM', 'Full CRUD on external brokers and activations within organization'),
  ('can_view_assigned_broker', 'View Assigned Broker', 'Manage activities and activations for assigned brokers')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

-- Grant permissions to default roles
-- sourcing_manager gets can_view_assigned_broker
INSERT INTO public.role_definitions (id, name) VALUES ('admin', 'Admin') ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id) VALUES
  ('sourcing_manager', 'can_view_assigned_broker'),
  ('admin', 'can_manage_broker_crm'),
  ('platform_admin', 'can_manage_broker_crm')
ON CONFLICT DO NOTHING;

-- 2. Create CRM Tables

-- 2.1 Brokers Public (Metadata)
CREATE TABLE IF NOT EXISTS public.brokers_public (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  assigned_sourcing_manager_id uuid NOT NULL REFERENCES auth.users(id),
  broker_alias text NOT NULL,
  broker_name text, -- Nullable if role-safe; use alias first in UI
  company_name text,
  area text,
  city text,
  speciality text,
  category text NOT NULL DEFAULT 'new' CHECK (category IN ('new', 'warm', 'hot', 'active', 'inactive', 'dead')),
  interest_level text NOT NULL DEFAULT 'unknown' CHECK (interest_level IN ('low', 'medium', 'high', 'unknown')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'archived')),
  notes_safe text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT brokers_public_alias_not_blank CHECK (btrim(broker_alias) <> '')
);

-- 2.2 Brokers Sensitive (Ciphertext)
CREATE TABLE IF NOT EXISTS public.brokers_sensitive (
  broker_id uuid PRIMARY KEY REFERENCES public.brokers_public(id) ON DELETE CASCADE,
  phone_ciphertext text,
  email_ciphertext text,
  encryption_version int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 2.3 Broker Activations (Project Pipeline)
CREATE TABLE IF NOT EXISTS public.broker_activations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  broker_id uuid NOT NULL REFERENCES public.brokers_public(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  assigned_sourcing_manager_id uuid NOT NULL REFERENCES auth.users(id),
  activation_stage text NOT NULL DEFAULT 'not_contacted' CHECK (activation_stage IN (
    'not_contacted',
    'first_call_done',
    'project_explained',
    'inventory_shared',
    'offer_shared',
    'interested',
    'meeting_scheduled',
    'lead_expected',
    'active_broker',
    'dead_not_interested'
  )),
  potential_score int DEFAULT 0 CHECK (potential_score >= 0 AND potential_score <= 100),
  last_contacted_at timestamptz,
  next_followup_at timestamptz,
  stage_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, broker_id, project_id)
);

-- 2.4 Broker Activity Logs (History)
CREATE TABLE IF NOT EXISTS public.broker_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  broker_id uuid NOT NULL REFERENCES public.brokers_public(id) ON DELETE CASCADE,
  project_id uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  actor_id uuid NOT NULL REFERENCES auth.users(id),
  activity_type text NOT NULL CHECK (activity_type IN (
    'call_attempt',
    'call_connected',
    'project_pitch',
    'inventory_shared',
    'offer_shared',
    'meeting_scheduled',
    'followup_set',
    'lead_received',
    'inactive_marked',
    'note_added'
  )),
  outcome text,
  notes_safe text,
  next_followup_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 2.5 Broker Followups (Today's Queue)
CREATE TABLE IF NOT EXISTS public.broker_followups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  broker_id uuid NOT NULL REFERENCES public.brokers_public(id) ON DELETE CASCADE,
  project_id uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  assigned_to uuid NOT NULL REFERENCES auth.users(id),
  due_at timestamptz NOT NULL,
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'skipped', 'cancelled')),
  reason text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_brokers_public_org ON public.brokers_public(organization_id, category, status);
CREATE INDEX IF NOT EXISTS idx_brokers_public_manager ON public.brokers_public(assigned_sourcing_manager_id);
CREATE INDEX IF NOT EXISTS idx_broker_activations_status ON public.broker_activations(organization_id, project_id, activation_stage);
CREATE INDEX IF NOT EXISTS idx_broker_activity_logs_broker ON public.broker_activity_logs(broker_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_broker_followups_due ON public.broker_followups(assigned_to, status, due_at ASC);

-- 4. Updated At Triggers
DROP TRIGGER IF EXISTS set_brokers_public_updated_at ON public.brokers_public;
CREATE TRIGGER set_brokers_public_updated_at
BEFORE UPDATE ON public.brokers_public
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_broker_activations_updated_at ON public.broker_activations;
CREATE TRIGGER set_broker_activations_updated_at
BEFORE UPDATE ON public.broker_activations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_broker_followups_updated_at ON public.broker_followups;
CREATE TRIGGER set_broker_followups_updated_at
BEFORE UPDATE ON public.broker_followups
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 5. RLS Configuration
ALTER TABLE public.brokers_public ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brokers_public FORCE ROW LEVEL SECURITY;
ALTER TABLE public.brokers_sensitive ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brokers_sensitive FORCE ROW LEVEL SECURITY;
ALTER TABLE public.broker_activations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broker_activations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.broker_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broker_activity_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.broker_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.broker_followups FORCE ROW LEVEL SECURITY;

-- 6. Helper Functions for CRM
CREATE OR REPLACE FUNCTION public.can_manage_broker_crm(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT public.has_enterprise_permission(auth.uid(), 'can_manage_broker_crm', p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_view_assigned_broker(p_broker_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.brokers_public
    WHERE id = p_broker_id
      AND (
        assigned_sourcing_manager_id = auth.uid()
        OR public.can_manage_broker_crm(organization_id)
      )
  );
$$;

-- 7. RLS Policies

-- Brokers Public
CREATE POLICY brokers_public_manager_read ON public.brokers_public
FOR SELECT TO authenticated
USING (
  assigned_sourcing_manager_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

CREATE POLICY brokers_public_manager_insert ON public.brokers_public
FOR INSERT TO authenticated
WITH CHECK (
  public.has_permission(auth.uid(), 'can_view_assigned_broker')
  AND organization_id IN (SELECT org_id FROM public.pilot_users WHERE user_id = auth.uid())
);

CREATE POLICY brokers_public_manager_update ON public.brokers_public
FOR UPDATE TO authenticated
USING (
  assigned_sourcing_manager_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

-- Brokers Sensitive (NO SELECT FOR AUTHENTICATED)
-- Access only via Service Role (Edge Functions)
REVOKE SELECT ON public.brokers_sensitive FROM authenticated;

-- Broker Activations
CREATE POLICY broker_activations_manager_all ON public.broker_activations
FOR ALL TO authenticated
USING (
  assigned_sourcing_manager_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

-- Broker Activity Logs
CREATE POLICY broker_activity_logs_manager_all ON public.broker_activity_logs
FOR ALL TO authenticated
USING (
  actor_id = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

-- Broker Followups
CREATE POLICY broker_followups_manager_all ON public.broker_followups
FOR ALL TO authenticated
USING (
  assigned_to = auth.uid()
  OR public.can_manage_broker_crm(organization_id)
);

-- 8. Audit Logging Triggers
CREATE OR REPLACE FUNCTION public.audit_broker_crm_event()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    PERFORM public.record_audit(
      NEW.created_by,
      'broker_created',
      jsonb_build_object(
        'broker_id', NEW.id,
        'organization_id', NEW.organization_id,
        'alias', NEW.broker_alias
      )
    );
  ELSIF (TG_OP = 'UPDATE') THEN
    IF (TG_TABLE_NAME = 'broker_activations' AND OLD.activation_stage <> NEW.activation_stage) THEN
      PERFORM public.record_audit(
        auth.uid(),
        'broker_activation_updated',
        jsonb_build_object(
          'broker_id', NEW.broker_id,
          'organization_id', NEW.organization_id,
          'old_stage', OLD.activation_stage,
          'new_stage', NEW.activation_stage
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_broker_created
AFTER INSERT ON public.brokers_public
FOR EACH ROW EXECUTE FUNCTION public.audit_broker_crm_event();

CREATE TRIGGER audit_broker_activation_change
AFTER UPDATE ON public.broker_activations
FOR EACH ROW EXECUTE FUNCTION public.audit_broker_crm_event();

-- Activity logging trigger for specific events
CREATE OR REPLACE FUNCTION public.log_broker_activity_on_create()
RETURNS trigger AS $$
BEGIN
  PERFORM public.record_audit(
    NEW.actor_id,
    'broker_activity_logged',
    jsonb_build_object(
      'broker_id', NEW.broker_id,
      'activity_type', NEW.activity_type,
      'project_id', NEW.project_id
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_broker_activity
AFTER INSERT ON public.broker_activity_logs
FOR EACH ROW EXECUTE FUNCTION public.log_broker_activity_on_create();
