-- Integration assertions. All fixtures and decisions roll back.
begin;
create temporary table moderation_test_ids(u uuid,a uuid,p uuid);
insert into moderation_test_ids select (select user_id from public.profiles where user_id not in(select user_id from public.admin_users) limit 1),(select user_id from public.admin_users limit 1),gen_random_uuid();
do $$ begin if exists(select 1 from moderation_test_ids where u is null or a is null) then raise exception 'Need existing creator and admin fixtures';end if;end $$;
insert into public.media_content(id,creator_id,title,content_type,media_type,media_url,published,visibility) select p,u,'Rollback moderation fixture','other','video','https://example.com/test.mp4',true,'public' from moderation_test_ids;
select set_config('request.jwt.claim.sub',a::text,true),set_config('request.jwt.claims',json_build_object('sub',a,'is_anonymous',false)::text,true) from moderation_test_ids;
select public.admin_moderate('post',p,'block','Rollback blocking test') from moderation_test_ids;
grant select on moderation_test_ids to authenticated,anon;
select set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{}',true);
set local role anon;
do $$ begin if exists(select 1 from public.media_content where id=(select p from moderation_test_ids)) then raise exception 'Blocked post visible to public';end if;end $$;
reset role;
select set_config('request.jwt.claim.sub',u::text,true),set_config('request.jwt.claims',json_build_object('sub',u,'is_anonymous',false)::text,true) from moderation_test_ids;
set local role authenticated;
do $$ begin
if not exists(select 1 from public.media_content where id=(select p from moderation_test_ids)) then raise exception 'Owner cannot inspect blocked post';end if;
begin update public.media_content set moderation_blocked=false where id=(select p from moderation_test_ids);raise exception 'Owner could unblock';exception when insufficient_privilege then null;end;
begin update public.profiles set is_verified=not is_verified where user_id=(select u from moderation_test_ids);raise exception 'Self verification allowed';exception when insufficient_privilege then null;end;
begin perform public.admin_moderate('creator',(select u from moderation_test_ids),'verify',null);raise exception 'Nonadmin moderation allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',a::text,true),set_config('request.jwt.claims',json_build_object('sub',a,'is_anonymous',false)::text,true) from moderation_test_ids;
select public.admin_moderate('post',p,'unblock',null),public.admin_moderate('creator',u,'suspend','Rollback suspension test') from moderation_test_ids;
select set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claims','{}',true);
set local role anon;
do $$ begin if exists(select 1 from public.media_content where id=(select p from moderation_test_ids)) then raise exception 'Suspended creator visible in public feed';end if;end $$;
reset role;
select set_config('request.jwt.claim.sub',u::text,true),set_config('request.jwt.claims',json_build_object('sub',u,'is_anonymous',false)::text,true) from moderation_test_ids;
set local role authenticated;
do $$ begin
begin update public.profiles set is_suspended=false where user_id=(select u from moderation_test_ids);raise exception 'Self unsuspend allowed';exception when insufficient_privilege then null;end;
begin perform public.finalize_creator_media((select p from moderation_test_ids),'public',true,null);raise exception 'Suspended creator finalized upload';exception when insufficient_privilege then null;end;
update public.media_content set published=false,visibility='private' where id=(select p from moderation_test_ids);
delete from public.media_content where id=(select p from moderation_test_ids);
end $$;
reset role;
rollback;
