create function private.admin_save_release(p_version text,p_build integer,p_notes text,p_distribution text,p_url text,p_required boolean) returns uuid language plpgsql security definer set search_path='' as $$ declare release_id uuid; begin
if not private.is_moderator() then raise exception 'Admin access required' using errcode='42501';end if;
if p_version is null or p_version!~'^[0-9]+[.][0-9]+[.][0-9]+$' or p_build is null or p_build<1 or length(coalesce(p_notes,''))>5000 or p_distribution not in ('apk','play_store','website','external') or p_url is null or p_url!~'^https://[^[:space:]]+$' then raise exception 'Provide a version, positive build number and HTTPS download link';end if;
perform pg_advisory_xact_lock(hashtext('quran-android-release'));
update public.app_releases set is_current=false where platform='android' and is_current;
insert into public.app_releases(platform,version,build_number,release_notes,distribution_type,download_url,is_current,is_required) values('android',p_version,p_build,coalesce(p_notes,''),p_distribution,p_url,true,coalesce(p_required,false)) on conflict(platform,build_number) do update set version=excluded.version,release_notes=excluded.release_notes,distribution_type=excluded.distribution_type,download_url=excluded.download_url,is_current=true,is_required=excluded.is_required returning id into release_id;
insert into public.moderation_actions(admin_id,target_type,target_id,action,reason) values(auth.uid(),'release',release_id,'publish_release',p_version||' ('||p_build||')');return release_id;end $$;
revoke all on function private.admin_save_release(text,integer,text,text,text,boolean) from public,anon;
grant execute on function private.admin_save_release(text,integer,text,text,text,boolean) to authenticated;
create function public.admin_save_release(p_version text,p_build integer,p_notes text,p_distribution text,p_url text,p_required boolean default false) returns uuid language sql security invoker set search_path='' as $$ select private.admin_save_release(p_version,p_build,p_notes,p_distribution,p_url,p_required) $$;
revoke all on function public.admin_save_release(text,integer,text,text,text,boolean) from public,anon;
grant execute on function public.admin_save_release(text,integer,text,text,text,boolean) to authenticated;
