create table public.error_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source text not null check (source in ('quran_app','media_worker','admin_web')),
  error_code text not null check (error_code ~ '^[A-Z0-9_]{1,60}$'),
  technical_code text check (technical_code ~ '^[A-Za-z0-9_-]{1,40}$'),
  platform text not null check (length(platform) between 1 and 20),
  app_version text not null check (length(app_version) between 1 and 40),
  build_number text not null check (length(build_number) <= 40),
  status text not null default 'new' check (status in ('new','reviewed','resolved')),
  created_at timestamptz not null default now()
);
create index error_reports_created_idx on public.error_reports(created_at desc);
create index error_reports_user_idx on public.error_reports(user_id);
alter table public.error_reports enable row level security;
revoke all on public.error_reports from anon, authenticated;
grant insert (source,error_code,technical_code,platform,app_version,build_number) on public.error_reports to authenticated;
grant select on public.error_reports to authenticated;
grant update (status) on public.error_reports to authenticated;
create policy report_own_errors on public.error_reports for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'new');
create policy admins_read_errors on public.error_reports for select to authenticated
  using (exists (select 1 from public.admin_users where user_id = (select auth.uid())));
create policy admins_update_error_status on public.error_reports for update to authenticated
  using (exists (select 1 from public.admin_users where user_id = (select auth.uid())))
  with check (exists (select 1 from public.admin_users where user_id = (select auth.uid())));
comment on table public.error_reports is 'Client-reported diagnostic codes; untrusted observations, not proof of server cause. No exception messages, stack traces or content.';

