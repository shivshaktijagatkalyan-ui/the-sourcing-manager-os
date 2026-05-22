alter table public.call_attempts
  add column if not exists callback_event_hash text,
  add column if not exists callback_received_at timestamptz,
  add column if not exists callback_failure_reason text;

create unique index if not exists idx_call_attempts_callback_event_hash
  on public.call_attempts (callback_event_hash)
  where callback_event_hash is not null;

create index if not exists idx_call_attempts_callback_received_at
  on public.call_attempts (callback_received_at)
  where callback_received_at is not null;
