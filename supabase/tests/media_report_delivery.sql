-- Reporter -> admin integration; never retains real reports or test content.
begin;
create temporary table report_delivery_ids(reporter uuid,admin uuid,post uuid);
insert into report_delivery_ids select (select user_id from profiles where user_id not in(select user_id from admin_users) limit 1),(select user_id from admin_users limit 1),gen_random_uuid();
grant select on report_delivery_ids to authenticated;
insert into public.media_content(id,creator_id,title,content_type,media_type,media_url,published,visibility) select post,reporter,'Rollback report fixture','other','video','https://example.com/test.mp4',true,'public' from report_delivery_ids;
select set_config('request.jwt.claim.sub',reporter::text,true),set_config('request.jwt.claims',json_build_object('sub',reporter,'is_anonymous',false)::text,true) from report_delivery_ids;
set local role authenticated;
insert into public.media_reports(media_id,auth_user_id,anonymous_install_id,reason,status) select post,reporter,gen_random_uuid(),label,'pending' from report_delivery_ids cross join unnest(array['Inappropriate content','Spam','Misleading content','Copyright concern','Other','Harassment']) label;
do $$ begin
begin insert into public.media_reports(media_id,auth_user_id,anonymous_install_id,reason,status) select post,reporter,gen_random_uuid(),'spam','reviewed' from report_delivery_ids;raise exception 'Reporter could self-review';exception when insufficient_privilege then null;end;
if exists(select 1 from public.media_reports where media_id=(select post from report_delivery_ids)) then raise exception 'Reporter can read admin inbox';end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',admin::text,true),set_config('request.jwt.claims',json_build_object('sub',admin,'is_anonymous',false)::text,true) from report_delivery_ids;
set local role authenticated;
do $$ begin
if (select count(*) from public.media_reports where media_id=(select post from report_delivery_ids) and status='pending')<>6 then raise exception 'Admin did not receive all six reasons';end if;
if (select count(distinct reason) from public.media_reports where media_id=(select post from report_delivery_ids))<>6 then raise exception 'Reason normalization failed';end if;
end $$;
reset role;
rollback;
