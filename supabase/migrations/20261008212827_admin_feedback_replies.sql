alter table public.feedback add column auth_user_id uuid default auth.uid();
alter table public.feedback add column admin_reply text check(char_length(admin_reply)<=2000);
alter table public.feedback add column replied_at timestamptz;
alter table public.feedback add column replied_by uuid;
create policy feedback_owner_read on public.feedback for select to authenticated using(auth_user_id=(select auth.uid()));
create or replace function private.guard_feedback() returns trigger language plpgsql security definer set search_path='' as $$ begin
if tg_op='INSERT' and not private.is_moderator() then new.auth_user_id=auth.uid();new.admin_reply=null;new.replied_at=null;new.replied_by=null;
elsif tg_op='UPDATE' then
 if new.auth_user_id is distinct from old.auth_user_id then raise exception 'Feedback identity cannot change' using errcode='42501'; end if;
 if new.admin_reply is distinct from old.admin_reply then
  if not private.is_moderator() then raise exception 'Admin reply requires moderator' using errcode='42501'; end if;
  new.replied_at=now();new.replied_by=auth.uid();
 end if;
end if;return new;end $$;
create trigger guard_feedback before insert or update on public.feedback for each row execute function private.guard_feedback();
revoke all on function private.guard_feedback() from public,anon,authenticated;
create policy feedback_admin_guard on public.feedback as restrictive for update to authenticated using(private.is_moderator()) with check(private.is_moderator());
create policy feedback_delete_admin_guard on public.feedback as restrictive for delete to authenticated using(private.is_moderator());
do $$ declare t text; begin foreach t in array array['media_comments','media_likes','media_reposts','follows'] loop
 execute format('create policy suspended_user_insert_guard on public.%I as restrictive for insert to authenticated with check(not exists(select 1 from public.profiles where user_id=(select auth.uid()) and is_suspended))',t);
 end loop; end $$;
create policy suspended_comment_update_guard on public.media_comments as restrictive for update to authenticated using(private.is_moderator() or not exists(select 1 from public.profiles where user_id=(select auth.uid()) and is_suspended)) with check(private.is_moderator() or not exists(select 1 from public.profiles where user_id=(select auth.uid()) and is_suspended));
