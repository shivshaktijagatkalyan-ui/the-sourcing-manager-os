do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'leads_public'
      and policyname = 'leads_public_assigned_sourcing_manager_read'
  ) then
    create policy leads_public_assigned_sourcing_manager_read
      on public.leads_public
      for select
      to authenticated
      using (
        not public.has_active_suspension(auth.uid())
        and (
          assigned_sourcing_manager_id = auth.uid()
          or assigned_manager_id = auth.uid()
          or (
            organization_id in (
              select pu.org_id
              from public.pilot_users pu
              where pu.user_id = auth.uid()
                and pu.status = 'active'
            )
            and (
              public.has_permission(auth.uid(), 'can_grant_data_loans'::text)
              or public.has_permission(auth.uid(), 'can_manage_broker_crm'::text)
            )
          )
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'broker_locks'
      and policyname = 'broker_locks_assigned_sourcing_manager_read'
  ) then
    create policy broker_locks_assigned_sourcing_manager_read
      on public.broker_locks
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.leads_public lp
          where lp.id = broker_locks.lead_id
            and (
              lp.assigned_sourcing_manager_id = auth.uid()
              or lp.assigned_manager_id = auth.uid()
            )
        )
      );
  end if;
end $$;
