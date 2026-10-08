create or replace function private.follows_creator(p_creator uuid) returns boolean language sql stable security definer set search_path='' as $$ select auth.uid() is not null and exists(select 1 from public.follows where following_id=p_creator and follower_id=auth.uid()) $$;
revoke all on function private.follows_creator(uuid) from public;
grant execute on function private.follows_creator(uuid) to anon,authenticated;
alter policy "Visible published media can be read" on public.media_content using(published and (visibility='public' or creator_id=(select auth.uid()) or (visibility='followers' and private.follows_creator(creator_id))));
create index if not exists media_reports_review_queue on public.media_reports(status,created_at desc);
create index if not exists feedback_session_history on public.feedback(auth_user_id,created_at desc);
create index if not exists moderation_actions_created on public.moderation_actions(created_at desc);
