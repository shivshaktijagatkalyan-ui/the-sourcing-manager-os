-- Sprint 5: Commission Automation Triggers
-- Migration: 20240508000100_payout_triggers.sql

CREATE OR REPLACE FUNCTION public.trigger_payout_on_lock()
RETURNS TRIGGER AS $$
DECLARE
    v_org_id uuid;
    v_commission_amount numeric := 500.00; -- Default placeholder commission
BEGIN
    -- 1. Fetch organization_id from the broker's pilot_users record
    SELECT org_id INTO v_org_id 
    FROM public.pilot_users 
    WHERE user_id = NEW.broker_id 
    LIMIT 1;

    -- 2. Create the pending payout entry
    INSERT INTO public.payout_ledger (
        organization_id,
        broker_id,
        broker_lock_id,
        amount,
        eligibility_date,
        status
    ) VALUES (
        v_org_id,
        NEW.broker_id,
        NEW.id,
        v_commission_amount,
        (NEW.starts_at + interval '45 days')::date,
        'pending'
    ) ON CONFLICT (broker_lock_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER broker_lock_payout_trigger
AFTER INSERT ON public.broker_locks
FOR EACH ROW EXECUTE FUNCTION public.trigger_payout_on_lock();
