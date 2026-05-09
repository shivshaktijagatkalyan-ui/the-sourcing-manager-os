CREATE TABLE IF NOT EXISTS public.broker_issues (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    organization_id uuid NOT NULL,
    broker_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    raised_by uuid NOT NULL,
    issue_type text NOT NULL,
    notes_safe text,
    status text DEFAULT 'open',
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.broker_issues ENABLE ROW LEVEL SECURITY;
