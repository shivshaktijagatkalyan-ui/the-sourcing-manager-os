-- Sprint 8: Task and Goal Management for Sourcing Managers
-- Purpose: Enable "Sales Intelligence" tracking and goal-oriented task management.

-- 1. Sourcing Goals Table
CREATE TABLE IF NOT EXISTS public.sourcing_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    target_leads INTEGER DEFAULT 0,
    target_visits INTEGER DEFAULT 0,
    target_broker_activations INTEGER DEFAULT 0,
    month_year DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('active', 'completed')) DEFAULT 'active',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, month_year)
);

-- 2. Sourcing Tasks Table
CREATE TABLE IF NOT EXISTS public.sourcing_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    due_at TIMESTAMPTZ,
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'cancelled')) DEFAULT 'pending',
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high')) DEFAULT 'medium',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. RLS Policies for Sourcing Goals
ALTER TABLE public.sourcing_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own goals"
    ON public.sourcing_goals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own goals"
    ON public.sourcing_goals FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. RLS Policies for Sourcing Tasks
ALTER TABLE public.sourcing_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own tasks"
    ON public.sourcing_tasks FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own tasks"
    ON public.sourcing_tasks FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 5. Audit Triggers
CREATE TRIGGER on_sourcing_goals_updated
    BEFORE UPDATE ON public.sourcing_goals
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER on_sourcing_tasks_updated
    BEFORE UPDATE ON public.sourcing_tasks
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 6. Initial Goal for Vinod Gupta (Optional, but helps with "Live" feel)
-- User ID: da81bcf6-2698-4c2c-b8ca-781df9657dc8
-- Org ID: c3802225-8f55-496b-afed-571e09f49eeb
INSERT INTO public.sourcing_goals (user_id, org_id, target_leads, target_visits, target_broker_activations, month_year)
VALUES ('da81bcf6-2698-4c2c-b8ca-781df9657dc8', 'c3802225-8f55-496b-afed-571e09f49eeb', 50, 20, 10, DATE_TRUNC('month', CURRENT_DATE)::DATE)
ON CONFLICT (user_id, month_year) DO NOTHING;
