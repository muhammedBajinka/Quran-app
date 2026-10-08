-- Draft metadata updates use the caller's existing owner/admin RLS policies.
grant update (title, description, speaker) on public.media_content to authenticated;

-- This is a request queue, not a claim that an account has been removed.
create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'cancelled')),
  created_at timestamptz not null default now()
);
create unique index account_deletion_one_pending_per_user
  on public.account_deletion_requests (user_id) where status = 'pending';
alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from anon, authenticated;
grant select on public.account_deletion_requests to authenticated;
grant insert (user_id) on public.account_deletion_requests to authenticated;
grant update (status) on public.account_deletion_requests to authenticated;

create policy "Owners can read deletion requests"
  on public.account_deletion_requests for select to authenticated
  using (user_id = (select auth.uid())
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false));
create policy "Owners can submit deletion requests"
  on public.account_deletion_requests for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'pending'
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false));
create policy "Owners can cancel pending deletion requests"
  on public.account_deletion_requests for update to authenticated
  using (user_id = (select auth.uid()) and status = 'pending'
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false))
  with check (user_id = (select auth.uid()) and status = 'cancelled'
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false));
create policy "Admins can review deletion requests"
  on public.account_deletion_requests for select to authenticated
  using (exists (select 1 from public.admin_users where user_id = (select auth.uid())));
