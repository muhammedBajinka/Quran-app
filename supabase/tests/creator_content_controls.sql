-- Synthetic fixtures only. Every write is rolled back, including auth users.
begin;
do $test$
declare
  owner_id uuid := gen_random_uuid();
  other_id uuid := gen_random_uuid();
  media_id uuid := gen_random_uuid();
  affected integer;
  blocked boolean;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values (owner_id, 'authenticated', 'authenticated', owner_id::text || '@example.invalid', now(), now()),
         (other_id, 'authenticated', 'authenticated', other_id::text || '@example.invalid', now(), now());
  insert into public.profiles (user_id) values (owner_id), (other_id)
    on conflict (user_id) do nothing;
  insert into public.media_content (id, creator_id, content_type, title, media_type, media_url, published, visibility)
  values (media_id, owner_id, 'other', 'Temporary draft', 'audio', 'https://example.invalid/test.mp3', false, 'private');

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  execute 'set local role authenticated';
  update public.media_content set title = 'Edited draft', description = 'Updated description', speaker = 'Updated speaker'
    where id = media_id and creator_id = owner_id and published = false;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Owner draft edit failed'; end if;
  insert into public.account_deletion_requests (user_id) values (owner_id);
  blocked := false;
  begin
    insert into public.account_deletion_requests (user_id) values (owner_id);
  exception when unique_violation then blocked := true;
  end;
  if not blocked then raise exception 'Duplicate pending request allowed'; end if;

  perform set_config('request.jwt.claim.sub', other_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', other_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  update public.media_content set title = 'Wrong owner' where id = media_id;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Other user edited owner draft'; end if;
  select count(*) into affected from public.account_deletion_requests where user_id = owner_id;
  if affected <> 0 then raise exception 'Other user read owner deletion request'; end if;
  update public.account_deletion_requests set status = 'cancelled' where user_id = owner_id;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Other user cancelled owner deletion request'; end if;
  blocked := false;
  begin
    insert into public.account_deletion_requests (user_id) values (owner_id);
  exception when insufficient_privilege then blocked := true;
  end;
  if not blocked then raise exception 'Other user submitted a request for owner'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', other_id, 'role', 'authenticated', 'is_anonymous', true)::text, true);
  blocked := false;
  begin
    insert into public.account_deletion_requests (user_id) values (other_id);
  exception when insufficient_privilege then blocked := true;
  end;
  if not blocked then raise exception 'Anonymous session submitted deletion request'; end if;

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id, 'role', 'authenticated', 'is_anonymous', false)::text, true);
  update public.account_deletion_requests set status = 'cancelled' where user_id = owner_id and status = 'pending';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Owner cancellation failed'; end if;
  insert into public.account_deletion_requests (user_id) values (owner_id);
  update public.media_content set published = true, visibility = 'private' where id = media_id;
  update public.media_content set title = 'Stale draft edit' where id = media_id and published = false;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Draft filter edited already published content'; end if;
  execute 'reset role';
  if has_table_privilege('anon', 'public.account_deletion_requests', 'SELECT')
      or has_column_privilege('anon', 'public.media_content', 'title', 'UPDATE')
      or has_column_privilege('authenticated', 'public.account_deletion_requests', 'user_id', 'UPDATE')
      or has_column_privilege('authenticated', 'public.media_content', 'creator_id', 'UPDATE') then
    raise exception 'Unexpected anonymous/ownership write privileges';
  end if;
end;
$test$;
rollback;
select 'Owner edits, draft guard, request ownership, duplicate prevention, anonymous denial and cancellation passed; all fixtures rolled back' as result;
