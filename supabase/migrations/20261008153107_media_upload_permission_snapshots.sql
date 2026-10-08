-- Preserve existing effective comment permissions once; downloads stay unchanged.
alter table public.media_content add column comment_permission text not null default 'everyone'
  check (comment_permission in ('everyone', 'followers', 'no_one'));
update public.media_content m set comment_permission = s.comment_permission
  from public.creator_privacy_settings s where s.user_id = m.creator_id;
alter table public.creator_privacy_settings alter column allow_downloads set default true;
alter table public.media_content alter column downloads_enabled set default true;

create function public.snapshot_media_upload_permissions() returns trigger
language plpgsql set search_path = '' as $$
begin
  select coalesce(s.allow_downloads, true), coalesce(s.comment_permission, 'everyone')
    into new.downloads_enabled, new.comment_permission
    from (select 1) seed left join public.creator_privacy_settings s
      on s.user_id = new.creator_id;
  return new;
end;
$$;
revoke all on function public.snapshot_media_upload_permissions() from public, anon, authenticated;
create trigger snapshot_media_upload_permissions before insert on public.media_content
  for each row execute function public.snapshot_media_upload_permissions();

create or replace function public.set_creator_privacy(
  p_show_liked_posts boolean, p_show_reposts boolean,
  p_allow_downloads boolean, p_comment_permission text
) returns void language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false)
      or not exists (select 1 from public.profiles p where p.user_id = v_user_id) then
    raise exception 'Creator account required';
  end if;
  if p_comment_permission is null or p_comment_permission not in ('everyone','followers','no_one') then
    raise exception 'Invalid comment permission';
  end if;
  insert into public.creator_privacy_settings(
    user_id, show_liked_posts, show_reposts, allow_downloads, comment_permission, updated_at
  ) values (
    v_user_id, p_show_liked_posts, p_show_reposts, p_allow_downloads, p_comment_permission, now()
  ) on conflict (user_id) do update set
    show_liked_posts = excluded.show_liked_posts,
    show_reposts = excluded.show_reposts,
    allow_downloads = excluded.allow_downloads,
    comment_permission = excluded.comment_permission,
    updated_at = now();
  -- Upload defaults only: never rewrite previously uploaded posts.
end;
$$;

-- Existing comments remain readable on visible posts, including closed posts.
drop policy "Users can read media comments" on public.media_comments;
create policy "Users can read media comments" on public.media_comments for select
  using (exists (select 1 from public.media_content m
    where m.id = media_comments.media_id and m.published));
drop policy "Users can create permitted comments" on public.media_comments;
create policy "Users can create permitted comments" on public.media_comments for insert
  to authenticated with check (
    auth.uid() = auth_user_id and exists (
      select 1 from public.media_content m where m.id = media_comments.media_id
        and m.published and (m.comment_permission = 'everyone' or
          (m.comment_permission = 'followers' and exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = m.creator_id
          )))
    )
  );
-- Prevent reassignment of an existing comment to a closed/inaccessible post.
drop policy "Users can update their own comments" on public.media_comments;
create policy "Users can update their own comments" on public.media_comments for update
  to authenticated using (auth.uid() = auth_user_id) with check (
    auth.uid() = auth_user_id and exists (
      select 1 from public.media_content m where m.id = media_comments.media_id
        and m.published and (m.comment_permission = 'everyone' or
          (m.comment_permission = 'followers' and exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = m.creator_id
          )))
    )
  );

-- Upsert/retry must be able to read an owned thumbnail before finalization
-- attaches its path to a media row. Visitors retain visible-post-only access.
create policy "Creators read own media thumbnails" on storage.objects for select
  to authenticated using (
    bucket_id = 'media-thumbnails' and
    (storage.foldername(name))[1] = (select auth.uid())::text
  );
