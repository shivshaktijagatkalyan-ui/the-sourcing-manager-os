-- Enterprise task queue and multi-agent workflow support.
-- Migration: 20260523000000_enterprise_task_queue.sql

-- CREATE EXTENSION IF NOT EXISTS pgvector;

CREATE TABLE IF NOT EXISTS public.enterprise_task_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_key TEXT NOT NULL UNIQUE,
  task_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  priority INT NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'pending',
  reserved_until TIMESTAMPTZ,
  reserved_by TEXT,
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.enterprise_task_workflow (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES public.enterprise_task_queue(id) ON DELETE CASCADE,
  current_state TEXT NOT NULL DEFAULT 'pending',
  last_agent TEXT,
  last_error TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.enterprise_task_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES public.enterprise_task_queue(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  agent_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.enterprise_human_review_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES public.enterprise_task_queue(id) ON DELETE CASCADE,
  review_status TEXT NOT NULL DEFAULT 'pending',
  review_reason TEXT,
  assigned_reviewer UUID REFERENCES auth.users(id),
  review_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_enterprise_task_queue_status_priority ON public.enterprise_task_queue (status, priority, available_at);
CREATE INDEX IF NOT EXISTS idx_enterprise_task_workflow_task_id ON public.enterprise_task_workflow (task_id);
CREATE INDEX IF NOT EXISTS idx_enterprise_human_review_queue_status ON public.enterprise_human_review_queue (review_status);
