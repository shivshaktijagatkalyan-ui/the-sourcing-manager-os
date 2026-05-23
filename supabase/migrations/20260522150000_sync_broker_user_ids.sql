-- Migration to sync owner_user_id and linked_user_id on brokers_public
-- Sync existing rows
UPDATE public.brokers_public
SET owner_user_id = linked_user_id
WHERE owner_user_id IS NULL AND linked_user_id IS NOT NULL;

-- Create sync trigger function
CREATE OR REPLACE FUNCTION public.sync_broker_owner_user_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.linked_user_id IS NOT NULL AND NEW.owner_user_id IS NULL THEN
    NEW.owner_user_id := NEW.linked_user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trg_sync_broker_owner_user_id ON public.brokers_public;
CREATE TRIGGER trg_sync_broker_owner_user_id
BEFORE INSERT OR UPDATE ON public.brokers_public
FOR EACH ROW EXECUTE FUNCTION public.sync_broker_owner_user_id();
