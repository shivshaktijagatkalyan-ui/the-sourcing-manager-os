-- Phase 3: Inventory & Unit ERP Module
-- Migration: 20260509000100_phase3_inventory_erp.sql

-- 1. Inventory Units Table
CREATE TABLE IF NOT EXISTS public.inventory_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  tower text NOT NULL,
  floor integer NOT NULL,
  unit_number text NOT NULL,
  configuration text NOT NULL, -- e.g. '1 BHK', '2 BHK', 'Studio'
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'blocked', 'sold', 'ready_to_move', 'under_maintenance')),
  base_price numeric(15,2),
  area_sqft numeric(10,2),
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, tower, unit_number)
);

-- 2. Unit Bookings / Reservations
CREATE TABLE IF NOT EXISTS public.unit_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id uuid NOT NULL REFERENCES public.inventory_units(id) ON DELETE CASCADE,
  lead_id uuid NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  broker_id uuid NOT NULL REFERENCES auth.users(id),
  sourcing_manager_id uuid NOT NULL REFERENCES auth.users(id),
  booking_status text NOT NULL DEFAULT 'provisional' CHECK (booking_status IN ('provisional', 'confirmed', 'cancelled', 'token_received')),
  token_amount numeric(15,2),
  booked_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz, -- for provisional blocks
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. RLS Configuration
ALTER TABLE public.inventory_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unit_bookings ENABLE ROW LEVEL SECURITY;

-- Everyone can view inventory availability
CREATE POLICY inventory_units_read_all ON public.inventory_units
FOR SELECT TO authenticated USING (true);

-- Only admins/developers can manage inventory
CREATE POLICY inventory_units_admin_all ON public.inventory_units
FOR ALL TO authenticated USING (public.has_permission(auth.uid(), 'can_manage_broker_crm'));

-- Bookings are visible to involved parties
CREATE POLICY unit_bookings_participant_read ON public.unit_bookings
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid() 
  OR sourcing_manager_id = auth.uid()
  OR public.has_permission(auth.uid(), 'can_manage_broker_crm')
);

-- 4. Triggers for Updated At
CREATE TRIGGER set_inventory_units_updated_at
BEFORE UPDATE ON public.inventory_units
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_unit_bookings_updated_at
BEFORE UPDATE ON public.unit_bookings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 5. Seed initial data for Wadhwa Wise City if missing
-- This is optional but good for the upgrade demo.
INSERT INTO public.inventory_units (project_id, tower, floor, unit_number, configuration, status, base_price)
SELECT 
  p.id, 
  'Tower A', 
  f, 
  (f * 100 + u)::text, 
  CASE WHEN u % 2 = 0 THEN '2 BHK' ELSE '1 BHK' END,
  'available',
  CASE WHEN u % 2 = 0 THEN 8500000 ELSE 6500000 END
FROM public.projects p, generate_series(1, 10) f, generate_series(1, 4) u
WHERE p.project_name = 'The Wadhwa Wise City'
ON CONFLICT DO NOTHING;
