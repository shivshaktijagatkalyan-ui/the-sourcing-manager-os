-- The Sourcing Manager OS - Sprint 2: Site Visit Verification Engine
-- Migration: 20240504000100_sprint2_verification.sql

-- 1. Helper: Haversine distance calculation (returns meters)
-- Used for server-side GPS geofence validation.
CREATE OR REPLACE FUNCTION public.haversine_distance(
  lat1 numeric, lon1 numeric,
  lat2 numeric, lon2 numeric
) RETURNS numeric AS $$
DECLARE
  phi1 numeric := radians(lat1);
  phi2 numeric := radians(lat2);
  dphi numeric := radians(lat2 - lat1);
  dlambda numeric := radians(lon2 - lon1);
  a numeric;
  c numeric;
  R numeric := 6371000; -- Earth's radius in meters
BEGIN
  a := sin(dphi/2)^2 + cos(phi1) * cos(phi2) * sin(dlambda/2)^2;
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  RETURN R * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Projects Geofence Registry
CREATE TABLE public.projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  developer_id uuid REFERENCES auth.users(id),
  project_name text NOT NULL,
  city text NOT NULL,
  area text NOT NULL,
  rera_number text,
  rera_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  geofence_radius_meters integer NOT NULL DEFAULT 150,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add missing columns to Sprint 1 tables
ALTER TABLE public.site_visits 
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.broker_locks
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

DROP TRIGGER IF EXISTS set_site_visits_updated_at ON public.site_visits;
CREATE TRIGGER set_site_visits_updated_at
BEFORE UPDATE ON public.site_visits
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_broker_locks_updated_at ON public.broker_locks;
CREATE TRIGGER set_broker_locks_updated_at
BEFORE UPDATE ON public.broker_locks
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3. Extend Site Visits for Verification
-- We modify the status check to include the new Sprint 2 states.
ALTER TABLE public.site_visits 
  DROP CONSTRAINT IF EXISTS site_visits_status_check;

ALTER TABLE public.site_visits
  ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES public.projects(id),
  ADD COLUMN IF NOT EXISTS gps_status text DEFAULT 'pending' CHECK (gps_status IN ('pending', 'verified', 'rejected', 'weak_accuracy')),
  ADD COLUMN IF NOT EXISTS submitted_lat numeric,
  ADD COLUMN IF NOT EXISTS submitted_lng numeric,
  ADD COLUMN IF NOT EXISTS gps_accuracy_meters numeric,
  ADD COLUMN IF NOT EXISTS distance_from_project_meters numeric,
  ADD COLUMN IF NOT EXISTS gps_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS photo_sha256 text,
  ADD COLUMN IF NOT EXISTS photo_uploaded_at timestamptz,
  ADD COLUMN IF NOT EXISTS photo_verification_status text DEFAULT 'pending' CHECK (photo_verification_status IN ('pending', 'verified', 'rejected')),
  ADD COLUMN IF NOT EXISTS broker_review_status text DEFAULT 'pending' CHECK (broker_review_status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS broker_reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS broker_rejection_reason text,
  ADD CONSTRAINT site_visits_status_check CHECK (status IN (
    'scheduled', 'started', 'gps_submitted', 'gps_verified', 'photo_submitted', 
    'photo_verified', 'broker_review_pending', 'completed', 'invalid', 'disputed'
  ));

-- 4. RLS for Projects
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

-- Everyone can see projects (for scheduling)
CREATE POLICY "projects_read_all" ON public.projects
  FOR SELECT TO authenticated USING (status = 'active');

-- Only admins or developers can manage projects
CREATE POLICY "projects_admin_manage" ON public.projects
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM auth.users 
      WHERE auth.uid() = id AND (raw_app_meta_data->>'role' IN ('admin', 'developer'))
    )
  );

-- 5. RLS for Site Visits (Sprint 2 Hardening)
-- We DO NOT allow direct UPDATE on site_visits. 
-- All mutations (GPS, Photo, Review) MUST happen via Edge Functions.
-- This prevents users from manually setting status = 'completed'.
DROP POLICY IF EXISTS "site_visits_manager_update" ON public.site_visits;
DROP POLICY IF EXISTS "site_visits_broker_review" ON public.site_visits;

-- 6. Trigger: Automate Broker Lock on Verified Completion
-- We ensure the lock is ONLY created when all verification conditions are met.
CREATE OR REPLACE FUNCTION public.trigger_create_broker_lock()
RETURNS TRIGGER AS $$
BEGIN
  -- Logic: Only approved verified visits trigger a lock.
  IF (NEW.status = 'completed' AND OLD.status != 'completed') THEN
    IF (NEW.gps_status != 'verified' OR NEW.photo_verification_status != 'verified' OR NEW.broker_review_status != 'approved') THEN
      RAISE EXCEPTION 'Cannot complete visit without full GPS, Photo, and Broker verification.';
    END IF;

    INSERT INTO public.broker_locks (
      broker_id,
      lead_id,
      source_site_visit_id,
      expires_at,
      status
    ) VALUES (
      NEW.broker_id,
      NEW.lead_id,
      NEW.id,
      now() + interval '45 days',
      'active'
    ) ON CONFLICT (lead_id, broker_id) WHERE status = 'active' DO UPDATE
    SET expires_at = now() + interval '45 days';
        
    -- Audit the lock creation (using event_context from Sprint 1)
    INSERT INTO public.audit_events (actor_id, event_type, lead_id, event_context)
    VALUES (NEW.broker_id, 'broker_lock_created', NEW.lead_id, jsonb_build_object(
      'site_visit_id', NEW.id,
      'reason', 'verified_site_visit_completion'
    ));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER site_visit_verified_lock_trigger
  BEFORE UPDATE ON public.site_visits
  FOR EACH ROW EXECUTE FUNCTION public.trigger_create_broker_lock();

-- 7. Audit Event: State Transition Log
CREATE OR REPLACE FUNCTION public.log_site_visit_transition()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_id uuid;
BEGIN
  -- Get actor from auth.uid() or session variable
  v_actor_id := COALESCE(
    auth.uid(), 
    NULLIF(current_setting('app.current_user_id', true), '')::uuid
  );

  IF (OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.audit_events (actor_id, event_type, lead_id, event_context)
    VALUES (v_actor_id, 'site_visit_state_change', NEW.lead_id, jsonb_build_object(
      'site_visit_id', NEW.id,
      'old_status', OLD.status,
      'new_status', NEW.status,
      'timestamp', now()
    ));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER site_visit_audit_trigger
  AFTER UPDATE ON public.site_visits
  FOR EACH ROW EXECUTE FUNCTION public.log_site_visit_transition();
