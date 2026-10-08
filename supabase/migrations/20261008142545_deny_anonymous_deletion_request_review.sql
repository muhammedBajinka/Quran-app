alter policy "Admins can review deletion requests" on public.account_deletion_requests
  using (not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
    and exists (select 1 from public.admin_users where user_id = (select auth.uid())));
