-- Sprint 8 Part 2: Goal Engine for Brokers and Callers
-- Purpose: Enable target-driven performance tracking for all roles.

-- 1. Broker Goals Table
CREATE TABLE IF NOT EXISTS public.broker_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_id UUID NOT NULL REFERENCES public.brokers_public(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    target_leads INTEGER DEFAULT 0,
    target_visits INTEGER DEFAULT 0,
    target_verified_visits INTEGER DEFAULT 0,
    month_year DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('active', 'completed')) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(broker_id, month_year)
);

-- 2. Caller Goals Table
CREATE TABLE IF NOT EXISTS public.caller_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    target_assigned_calls INTEGER DEFAULT 0,
    target_connected_calls INTEGER DEFAULT 0,
    target_interested_leads INTEGER DEFAULT 0,
    month_year DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('active', 'completed')) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, month_year)
);

-- 3. RLS Policies for Broker Goals
ALTER TABLE public.broker_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Brokers can view their own goals"
    ON public.broker_goals FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.brokers_public 
        WHERE id = broker_goals.broker_id 
        AND linked_user_id = auth.uid()
    ));

CREATE POLICY "Sourcing Managers can view goals of assigned brokers"
    ON public.broker_goals FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.brokers_public 
        WHERE id = broker_goals.broker_id 
        AND assigned_sourcing_manager_id = auth.uid()
    ));

-- 4. RLS Policies for Caller Goals
ALTER TABLE public.caller_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Callers can view their own goals"
    ON public.caller_goals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Admins/SMs can view caller goals"
    ON public.caller_goals FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.role_assignments 
        WHERE user_id = auth.uid() 
        AND role_id IN ('admin', 'sourcing_manager')
    ));

-- 5. Audit Triggers
CREATE TRIGGER set_broker_goals_updated_at
    BEFORE UPDATE ON public.broker_goals
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_caller_goals_updated_at
    BEFORE UPDATE ON public.caller_goals
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
