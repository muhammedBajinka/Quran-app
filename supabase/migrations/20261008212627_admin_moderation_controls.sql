create schema if not exists private;
create or replace function private.is_moderator() returns boolean language sql stable security definer set search_path='' as $$ select auth.uid() is not null and coalesce((auth.jwt()->>'is_anonymous')::boolean,false)=false and exists(select 1 from public.admin_users where user_id=auth.uid()) $$;
revoke all on function private.is_moderator() from public;
grant usage on schema private to authenticated,anon;
grant execute on function private.is_moderator() to authenticated,anon;
alter table public.media_content add column moderation_blocked boolean not null default false;
alter table public.media_content add column moderation_reason text;
alter table public.profiles add column moderation_reason text;
create table public.moderation_actions(id bigint generated always as identity primary key, admin_id uuid not null, target_type text not null, target_id uuid not null, action text not null, reason text, created_at timestamptz not null default now());
alter table public.moderation_actions enable row level security;
revoke all on public.moderation_actions from anon,authenticated;
grant select on public.moderation_actions to authenticated;
create policy moderator_audit_read on public.moderation_actions for select to authenticated using(private.is_moderator());
create policy moderator_profiles_update on public.profiles for update to authenticated using(private.is_moderator()) with check(private.is_moderator());
create or replace function private.guard_profile_moderation() returns trigger language plpgsql security definer set search_path='' as $$ begin
if not private.is_moderator() and auth.uid() is not null then
 if tg_op='INSERT' then
  if new.is_verified or new.is_suspended or new.moderation_reason is not null then raise exception 'Moderation fields are admin only' using errcode='42501'; end if;
 elsif new.is_verified is distinct from old.is_verified or new.is_suspended is distinct from old.is_suspended or new.moderation_reason is distinct from old.moderation_reason then raise exception 'Moderation fields are admin only' using errcode='42501'; end if;
end if; return new; end $$;
create trigger guard_profile_moderation before insert or update on public.profiles for each row execute function private.guard_profile_moderation();
create or replace function private.guard_media_moderation() returns trigger language plpgsql security definer set search_path='' as $$ begin
if not private.is_moderator() and auth.uid() is not null then
 if tg_op='INSERT' then
  if new.moderation_blocked or new.moderation_reason is not null then raise exception 'Moderation fields are admin only' using errcode='42501'; end if;
 elsif new.moderation_blocked is distinct from old.moderation_blocked or new.moderation_reason is distinct from old.moderation_reason or new.creator_id is distinct from old.creator_id then raise exception 'Moderation fields are admin only' using errcode='42501'; end if;
 if new.published and (new.moderation_blocked or exists(select 1 from public.profiles where user_id=new.creator_id and is_suspended)) then raise exception 'This creator or post is blocked from publishing' using errcode='42501'; end if;
end if; return new; end $$;
create trigger guard_media_moderation before insert or update on public.media_content for each row execute function private.guard_media_moderation();
create policy enforce_media_moderation on public.media_content as restrictive for select to anon,authenticated using(private.is_moderator() or creator_id=(select auth.uid()) or (not moderation_blocked and not exists(select 1 from public.profiles where user_id=creator_id and is_suspended)));
alter policy "Creators can update their own media" on public.media_content with check(creator_id=(select auth.uid()) and (not published or exists(select 1 from public.profiles where user_id=(select auth.uid()) and not is_suspended)));
grant select,update on public.media_reports to authenticated;
create policy moderator_reports_read on public.media_reports for select to authenticated using(private.is_moderator());
create policy moderator_reports_update on public.media_reports for update to authenticated using(private.is_moderator()) with check(private.is_moderator());
alter policy "Users can submit reports" on public.media_reports with check(auth.uid()=auth_user_id and status='pending' and reviewed_by is null and reviewed_at is null);
create policy moderator_comments_read on public.media_comments for select to authenticated using(private.is_moderator());
create policy moderator_comments_delete on public.media_comments for delete to authenticated using(private.is_moderator());
create or replace function public.admin_moderate(p_type text,p_id uuid,p_action text,p_reason text default null) returns void language plpgsql security definer set search_path='' as $$
declare affected integer; begin
if not private.is_moderator() then raise exception 'Admin access required' using errcode='42501'; end if;
if length(coalesce(p_reason,''))>1000 then raise exception 'Reason too long'; end if;
if p_action in ('suspend','block','remove') and length(trim(coalesce(p_reason,'')))=0 then raise exception 'A reason is required'; end if;
if p_type='creator' and p_action in ('verify','unverify','suspend','reactivate') then
 update public.profiles set is_verified=case when p_action='verify' then true when p_action='unverify' then false else is_verified end,is_suspended=case when p_action='suspend' then true when p_action='reactivate' then false else is_suspended end,moderation_reason=case when p_action='suspend' then p_reason when p_action='reactivate' then null else moderation_reason end where user_id=p_id;
elsif p_type='post' and p_action in ('block','unblock') then
 update public.media_content set moderation_blocked=p_action='block',moderation_reason=case when p_action='block' then p_reason else null end where id=p_id;
elsif p_type='report' and p_action in ('reviewed','action_taken','dismissed') then
 update public.media_reports set status=p_action,reviewed_by=auth.uid(),reviewed_at=now() where id=p_id;
elsif p_type='comment' and p_action='remove' then delete from public.media_comments where id=p_id;
else raise exception 'Unsupported moderation action'; end if;
get diagnostics affected=row_count; if affected<>1 then raise exception 'Record not found'; end if;
insert into public.moderation_actions(admin_id,target_type,target_id,action,reason) values(auth.uid(),p_type,p_id,p_action,nullif(trim(p_reason),'')); end $$;
revoke all on function public.admin_moderate(text,uuid,text,text) from public,anon;
grant execute on function public.admin_moderate(text,uuid,text,text) to authenticated;
revoke all on function private.guard_profile_moderation(),private.guard_media_moderation() from public,anon,authenticated;
