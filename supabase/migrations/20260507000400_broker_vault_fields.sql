-- Migration: Add missing fields for Broker Business Vault

-- leads_public table updates
ALTER TABLE public.leads_public
ADD COLUMN IF NOT EXISTS lead_quality text DEFAULT 'warm',
ADD COLUMN IF NOT EXISTS lead_temperature text DEFAULT 'warm',
ADD COLUMN IF NOT EXISTS buyer_type text,
ADD COLUMN IF NOT EXISTS project_match_status text,
ADD COLUMN IF NOT EXISTS next_followup_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS broker_notes_safe text,
ADD COLUMN IF NOT EXISTS conversion_stage text DEFAULT 'lead_received',
ADD COLUMN IF NOT EXISTS booking_stage text DEFAULT 'not_started',
ADD COLUMN IF NOT EXISTS brokerage_status text DEFAULT 'tracking',
ADD COLUMN IF NOT EXISTS data_quality_score numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS assigned_sourcing_manager_id uuid REFERENCES auth.users(id);

-- brokers_public table updates
ALTER TABLE public.brokers_public
ADD COLUMN IF NOT EXISTS verified_performance_rank text DEFAULT 'Bronze',
ADD COLUMN IF NOT EXISTS trust_score numeric DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS total_leads integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS verified_visits integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS active_locks integer DEFAULT 0;
