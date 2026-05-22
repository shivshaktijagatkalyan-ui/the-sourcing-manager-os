-- Migration: 20260520000100_seed_sourcing_managers.sql
-- Description: Seed 5 sourcing managers and 5 active real estate developer projects, linking them dynamically to all active brokers.

-- 1. Ensure the default organization exists
INSERT INTO public.organizations (id, name, status)
VALUES ('00000000-0000-0000-0000-000000000001', 'Default Sourcing Org', 'active')
ON CONFLICT (id) DO NOTHING;

-- 2. Seed Developer Users in auth.users
-- Sheth Developer
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'de1a0000-0000-0000-0000-000000000001',
  'developer.sheth@futuretrust.demo',
  '{"provider": "email", "providers": ["email"], "role": "developer"}'::jsonb,
  '{"full_name": "Sheth Developer"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Poddar Developer
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'de1a0000-0000-0000-0000-000000000002',
  'developer.poddar@futuretrust.demo',
  '{"provider": "email", "providers": ["email"], "role": "developer"}'::jsonb,
  '{"full_name": "Poddar Developer"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Kanakia Developer
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'de1a0000-0000-0000-0000-000000000003',
  'developer.kanakia@futuretrust.demo',
  '{"provider": "email", "providers": ["email"], "role": "developer"}'::jsonb,
  '{"full_name": "Kanakia Developer"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Raj Developer
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'de1a0000-0000-0000-0000-000000000004',
  'developer.raj@futuretrust.demo',
  '{"provider": "email", "providers": ["email"], "role": "developer"}'::jsonb,
  '{"full_name": "Raj Developer"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Lodha Developer
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'de1a0000-0000-0000-0000-000000000005',
  'developer.lodha@futuretrust.demo',
  '{"provider": "email", "providers": ["email"], "role": "developer"}'::jsonb,
  '{"full_name": "Lodha Developer"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;


-- 3. Seed Projects
-- Sheth Avalon, Thane
INSERT INTO public.projects (id, developer_id, project_name, city, area, rera_number, latitude, longitude, geofence_radius_meters, status)
VALUES (
  'ec000000-0000-0000-0000-000000000001',
  'de1a0000-0000-0000-0000-000000000001',
  'Sheth Avalon',
  'Thane',
  'Thane West',
  'PRM-SHETH-AVALON-12345',
  19.2155, 72.9734,
  150,
  'active'
) ON CONFLICT (id) DO NOTHING;

-- Poddar Evergreens, Ulhasnagar
INSERT INTO public.projects (id, developer_id, project_name, city, area, rera_number, latitude, longitude, geofence_radius_meters, status)
VALUES (
  'ec000000-0000-0000-0000-000000000002',
  'de1a0000-0000-0000-0000-000000000002',
  'Poddar Evergreens',
  'Ulhasnagar',
  'Ulhasnagar East',
  'PRM-PODDAR-EVER-54321',
  19.2215, 73.1642,
  150,
  'active'
) ON CONFLICT (id) DO NOTHING;

-- Kanakia Silicon Valley, Powai
INSERT INTO public.projects (id, developer_id, project_name, city, area, rera_number, latitude, longitude, geofence_radius_meters, status)
VALUES (
  'ec000000-0000-0000-0000-000000000003',
  'de1a0000-0000-0000-0000-000000000003',
  'Kanakia Silicon Valley',
  'Mumbai',
  'Powai',
  'PRM-KANAKIA-SIL-98765',
  19.1176, 72.9060,
  150,
  'active'
) ON CONFLICT (id) DO NOTHING;

-- Raj Shiv Ganga, Borivali
INSERT INTO public.projects (id, developer_id, project_name, city, area, rera_number, latitude, longitude, geofence_radius_meters, status)
VALUES (
  'ec000000-0000-0000-0000-000000000004',
  'de1a0000-0000-0000-0000-000000000004',
  'Raj Shiv Ganga',
  'Mumbai',
  'Borivali East',
  'PRM-RAJ-SHIV-87654',
  19.2291, 72.8573,
  150,
  'active'
) ON CONFLICT (id) DO NOTHING;

-- Lodha Palava, Dombivli
INSERT INTO public.projects (id, developer_id, project_name, city, area, rera_number, latitude, longitude, geofence_radius_meters, status)
VALUES (
  'ec000000-0000-0000-0000-000000000005',
  'de1a0000-0000-0000-0000-000000000005',
  'Lodha Palava',
  'Dombivli',
  'Dombivli East',
  'PRM-LODHA-PAL-76543',
  19.1678, 73.0890,
  150,
  'active'
) ON CONFLICT (id) DO NOTHING;


-- 4. Seed Sourcing Managers in auth.users
-- Praveen Singh
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'cc000000-0000-0000-0000-000000000001',
  'praveen.singh@sheth.demo',
  '{"provider": "email", "providers": ["email"], "role": "sourcing_manager"}'::jsonb,
  '{"full_name": "Praveen Singh"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (user_id, full_name, professional_id, kyc_status, onboarding_completed_at)
VALUES (
  'cc000000-0000-0000-0000-000000000001',
  'Praveen Singh',
  'EMP-SHETH-SM1',
  'verified',
  now()
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.pilot_users (id, user_id, org_id, role, status)
VALUES (
  'bb000000-0000-0000-0000-000000000001',
  'cc000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'sourcing_manager',
  'active'
) ON CONFLICT (user_id, org_id) DO NOTHING;


-- Jayesh Bhatija
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'cc000000-0000-0000-0000-000000000002',
  'jayesh.bhatija@poddar.demo',
  '{"provider": "email", "providers": ["email"], "role": "sourcing_manager"}'::jsonb,
  '{"full_name": "Jayesh Bhatija"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (user_id, full_name, professional_id, kyc_status, onboarding_completed_at)
VALUES (
  'cc000000-0000-0000-0000-000000000002',
  'Jayesh Bhatija',
  'EMP-PODDAR-SM2',
  'verified',
  now()
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.pilot_users (id, user_id, org_id, role, status)
VALUES (
  'bb000000-0000-0000-0000-000000000002',
  'cc000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'sourcing_manager',
  'active'
) ON CONFLICT (user_id, org_id) DO NOTHING;


-- Raju Shinde
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'cc000000-0000-0000-0000-000000000003',
  'raju.shinde@kanakia.demo',
  '{"provider": "email", "providers": ["email"], "role": "sourcing_manager"}'::jsonb,
  '{"full_name": "Raju Shinde"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (user_id, full_name, professional_id, kyc_status, onboarding_completed_at)
VALUES (
  'cc000000-0000-0000-0000-000000000003',
  'Raju Shinde',
  'EMP-KANAKIA-SM3',
  'verified',
  now()
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.pilot_users (id, user_id, org_id, role, status)
VALUES (
  'bb000000-0000-0000-0000-000000000003',
  'cc000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  'sourcing_manager',
  'active'
) ON CONFLICT (user_id, org_id) DO NOTHING;


-- Mohan Gupta
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'cc000000-0000-0000-0000-000000000004',
  'mohan.gupta@raj.demo',
  '{"provider": "email", "providers": ["email"], "role": "sourcing_manager"}'::jsonb,
  '{"full_name": "Mohan Gupta"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (user_id, full_name, professional_id, kyc_status, onboarding_completed_at)
VALUES (
  'cc000000-0000-0000-0000-000000000004',
  'Mohan Gupta',
  'EMP-RAJ-SM4',
  'verified',
  now()
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.pilot_users (id, user_id, org_id, role, status)
VALUES (
  'bb000000-0000-0000-0000-000000000004',
  'cc000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000001',
  'sourcing_manager',
  'active'
) ON CONFLICT (user_id, org_id) DO NOTHING;


-- Amit Patel
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, is_super_admin, aud, role)
VALUES (
  'cc000000-0000-0000-0000-000000000005',
  'amit.patel@lodha.demo',
  '{"provider": "email", "providers": ["email"], "role": "sourcing_manager"}'::jsonb,
  '{"full_name": "Amit Patel"}'::jsonb,
  false,
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (user_id, full_name, professional_id, kyc_status, onboarding_completed_at)
VALUES (
  'cc000000-0000-0000-0000-000000000005',
  'Amit Patel',
  'EMP-LODHA-SM5',
  'verified',
  now()
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.pilot_users (id, user_id, org_id, role, status)
VALUES (
  'bb000000-0000-0000-0000-000000000005',
  'cc000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000001',
  'sourcing_manager',
  'active'
) ON CONFLICT (user_id, org_id) DO NOTHING;


-- 5. Link all existing active brokers to the 5 seeded projects and sourcing managers
INSERT INTO public.broker_activations (organization_id, broker_id, project_id, assigned_sourcing_manager_id, activation_stage)
SELECT 
  bp.organization_id,
  bp.id AS broker_id,
  proj.id AS project_id,
  sm.id AS assigned_sourcing_manager_id,
  'active_broker' AS activation_stage
FROM public.brokers_public bp
CROSS JOIN (
  VALUES 
    ('ec000000-0000-0000-0000-000000000001'::uuid, 'cc000000-0000-0000-0000-000000000001'::uuid),
    ('ec000000-0000-0000-0000-000000000002'::uuid, 'cc000000-0000-0000-0000-000000000002'::uuid),
    ('ec000000-0000-0000-0000-000000000003'::uuid, 'cc000000-0000-0000-0000-000000000003'::uuid),
    ('ec000000-0000-0000-0000-000000000004'::uuid, 'cc000000-0000-0000-0000-000000000004'::uuid),
    ('ec000000-0000-0000-0000-000000000005'::uuid, 'cc000000-0000-0000-0000-000000000005'::uuid)
) AS mappings(project_id, assigned_sourcing_manager_id)
JOIN public.projects proj ON proj.id = mappings.project_id
JOIN auth.users sm ON sm.id = mappings.assigned_sourcing_manager_id
ON CONFLICT (organization_id, broker_id, project_id) DO NOTHING;
