-- Sprint 8 Part 2: Smart Priority Queue Infrastructure
-- Adding callback support to leads_public

ALTER TABLE public.leads_public 
ADD COLUMN IF NOT EXISTS callback_at TIMESTAMPTZ;

-- Index for efficient priority sorting
CREATE INDEX IF NOT EXISTS idx_leads_public_caller_priority 
ON public.leads_public (assigned_caller_id, call_priority, callback_at)
WHERE assigned_caller_id IS NOT NULL;
