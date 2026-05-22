-- Migration: 20260510000200_harden_broker_locks.sql
-- Description: Adds brokerage status and metadata to broker_locks for transparency.

-- 1. Add brokerage_status column
ALTER TABLE public.broker_locks 
ADD COLUMN IF NOT EXISTS brokerage_status TEXT NOT NULL DEFAULT 'tracking' 
CHECK (brokerage_status IN ('tracking', 'eligible', 'paid', 'disputed', 'blocked'));

-- 2. Add metadata column for proof and verification details
ALTER TABLE public.broker_locks 
ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- 3. Update status check to include 'disputed'
ALTER TABLE public.broker_locks DROP CONSTRAINT IF EXISTS broker_locks_status_check;
ALTER TABLE public.broker_locks 
ADD CONSTRAINT broker_locks_status_check 
CHECK (status IN ('active', 'expired', 'disputed', 'released'));

-- 4. Audit Log for the upgrade
COMMENT ON COLUMN public.broker_locks.brokerage_status IS 'Tracks the payment lifecycle of the locked lead.';
COMMENT ON COLUMN public.broker_locks.metadata IS 'Stores proof_status like gps_verified, photo_uploaded, etc.';
