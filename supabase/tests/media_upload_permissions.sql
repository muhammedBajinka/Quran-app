-- Synthetic fixtures only. No real uploads or users are modified.
begin;
do $test$
declare
  owner_id uuid := gen_random_uuid();
  visitor_id uuid := gen_random_uuid();
  first_id uuid := gen_random_uuid();
  closed_id uuid := gen_random_uuid();
  followers_id uuid := gen_random_uuid();
  reopened_id uuid := gen_random_uuid();
  blocked boolean;
  count_rows integer;
  owner_thumb text;
  visitor_thumb text;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values (owner_id, 'authenticated', 'authenticated', owner_id::text || '@example.invalid', now(), now()),
         (visitor_id, 'authenticated', 'authenticated', visitor_id::text || '@example.invalid', now(), now());
  insert into public.profiles (user_id) values (owner_id), (visitor_id) on conflict do nothing;
  insert into public.media_content (id, creator_id, content_type, title, media_type, media_url, published, visibility)
  values (first_id, owner_id, 'other', 'Synthetic open post', 'audio', 'https://example.invalid/test.mp3', true, 'public');
  if not exists (select 1 from public.media_content where id=first_id and downloads_enabled and comment_permission='everyone') then
    raise exception 'New uploads must default to open downloads and comments';
  end if;

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  execute 'set local role authenticated';
  perform public.set_creator_privacy(true, true, false, 'no_one');
  -- Exercise the real Worker creation RPC and trigger together.
  perform public.create_creator_media(closed_id, 'other', 'Synthetic closed post', '', 'audio', 'https://example.invalid/test.mp3');
  execute 'reset role';
  update public.media_content set published=true, visibility='public' where id=closed_id;
  if not exists (select 1 from public.media_content where id=closed_id and not downloads_enabled and comment_permission='no_one') then
    raise exception 'New upload did not snapshot closed permissions';
  end if;
  if not exists (select 1 from public.media_content where id=first_id and downloads_enabled and comment_permission='everyone') then
    raise exception 'Changing defaults rewrote existing posts';
  end if;

  perform set_config('request.jwt.claim.sub', visitor_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', visitor_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  execute 'set local role authenticated';
  insert into public.media_comments (media_id, auth_user_id, anonymous_install_id, comment_text)
  values (first_id, visitor_id, gen_random_uuid(), 'Synthetic retained comment');
  blocked := false;
  begin
    insert into public.media_comments (media_id, auth_user_id, anonymous_install_id, comment_text)
    values (closed_id, visitor_id, gen_random_uuid(), 'Must fail');
  exception when insufficient_privilege then blocked := true;
  end;
  if not blocked then raise exception 'Closed post accepted a comment'; end if;
  select count(*) into count_rows from public.media_comments where media_id=first_id;
  if count_rows <> 1 then raise exception 'Existing post comments disappeared'; end if;

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  blocked := false;
  begin
    insert into public.media_comments (media_id, auth_user_id, anonymous_install_id, comment_text)
    values (closed_id, owner_id, gen_random_uuid(), 'Owner must also respect no one');
  exception when insufficient_privilege then blocked := true;
  end;
  if not blocked then raise exception 'Owner bypassed no-one permission'; end if;
  perform public.set_creator_privacy(true, true, true, 'followers');
  perform public.create_creator_media(followers_id, 'other', 'Synthetic followers post', '', 'audio', 'https://example.invalid/test.mp3');
  execute 'reset role';
  update public.media_content set published=true, visibility='public' where id=followers_id;

  perform set_config('request.jwt.claim.sub', visitor_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', visitor_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  execute 'set local role authenticated';
  blocked := false;
  begin
    insert into public.media_comments (media_id, auth_user_id, anonymous_install_id, comment_text)
    values (followers_id, visitor_id, gen_random_uuid(), 'Non-follower must fail');
  exception when insufficient_privilege then blocked := true;
  end;
  if not blocked then raise exception 'Non-follower bypassed permission'; end if;
  insert into public.follows (follower_id, following_id) values (visitor_id, owner_id);
  insert into public.media_comments (media_id, auth_user_id, anonymous_install_id, comment_text)
  values (followers_id, visitor_id, gen_random_uuid(), 'Follower allowed');

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  perform public.set_creator_privacy(true, true, true, 'everyone');
  perform public.create_creator_media(reopened_id, 'other', 'Synthetic reopened post', '', 'audio', 'https://example.invalid/test.mp3');
  execute 'reset role';
  if not exists (select 1 from public.media_content where id=closed_id and not downloads_enabled and comment_permission='no_one') then
    raise exception 'Reopening defaults rewrote a closed post';
  end if;
  if not exists (select 1 from public.media_content where id=reopened_id and downloads_enabled and comment_permission='everyone') then
    raise exception 'Reopened defaults not applied to new upload';
  end if;
  -- Temporary metadata fixtures only, no storage objects are uploaded.
  owner_thumb := owner_id::text || '/' || gen_random_uuid()::text;
  visitor_thumb := visitor_id::text || '/' || gen_random_uuid()::text;
  insert into storage.objects (bucket_id, name) values
    ('media-thumbnails', owner_thumb), ('media-thumbnails', visitor_thumb);
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  execute 'set local role authenticated';
  select count(*) into count_rows from storage.objects
    where bucket_id='media-thumbnails' and name in (owner_thumb, visitor_thumb);
  if count_rows <> 1 then raise exception 'Owner thumbnail read missing or other private thumbnail exposed'; end if;
  if not exists (select 1 from storage.objects where bucket_id='media-thumbnails' and name=owner_thumb) then
    raise exception 'Unfinalized owner thumbnail cannot be read for upsert';
  end if;
  execute 'reset role';
  if has_column_privilege('authenticated', 'public.media_content', 'comment_permission', 'UPDATE') then
    raise exception 'Clients can rewrite post snapshots';
  end if;
end;
$test$;
rollback;
select 'Upload defaults, immutable old posts, comments and follower enforcement passed; all synthetic fixtures rolled back' as result;
