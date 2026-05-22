DO $$
DECLARE
    v_user_id UUID;
    v_org_id UUID;
BEGIN
    -- 1. Get the user ID for your admin email
    SELECT id INTO v_user_id 
    FROM auth.users 
    WHERE email = 'shivshaktijagatkalyan@gmail.com';

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found! Please log in via Google on the app first so your account gets created.';
    END IF;

    -- 2. Create or get an organization (Use metadata for type, as type column does not exist)
    INSERT INTO organizations (name, status, metadata)
    VALUES ('Sourcing Manager Operations', 'active', '{"type": "brokerage"}'::jsonb)
    -- Organizations doesn't have a unique constraint on name by default, but let's assume it's created or we just fetch it
    -- A better way if no unique constraint:
    ON CONFLICT DO NOTHING; -- Assuming there's a constraint we don't know about, otherwise it might insert duplicates.

    SELECT id INTO v_org_id FROM organizations WHERE name = 'Sourcing Manager Operations' LIMIT 1;
    
    IF v_org_id IS NULL THEN
        INSERT INTO organizations (name, status, metadata)
        VALUES ('Sourcing Manager Operations', 'active', '{"type": "brokerage"}'::jsonb)
        RETURNING id INTO v_org_id;
    END IF;

    -- 3. Assign the sourcing_manager role in role_assignments
    IF NOT EXISTS (SELECT 1 FROM public.role_assignments WHERE user_id = v_user_id AND organization_id = v_org_id AND status = 'active') THEN
        INSERT INTO role_assignments (organization_id, user_id, role_id, status)
        VALUES (v_org_id, v_user_id, 'sourcing_manager', 'active');
    END IF;

    -- 4. Add to pilot_users to bypass onboarding screens
    INSERT INTO pilot_users (user_id, org_id, role, status)
    VALUES (v_user_id, v_org_id, 'sourcing_manager', 'active')
    ON CONFLICT (user_id, org_id) DO NOTHING;
    
    RAISE NOTICE 'Successfully assigned admin roles to %', v_user_id;
END $$;
