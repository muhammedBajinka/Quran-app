alter function public.admin_moderate(text,uuid,text,text) set schema private;
create function public.admin_moderate(p_type text,p_id uuid,p_action text,p_reason text default null) returns void language sql security invoker set search_path='' as $$ select private.admin_moderate(p_type,p_id,p_action,p_reason) $$;
revoke all on function public.admin_moderate(text,uuid,text,text) from public,anon;
grant execute on function public.admin_moderate(text,uuid,text,text),private.admin_moderate(text,uuid,text,text) to authenticated;
alter policy "Admins can read their own admin record" on public.admin_users using(user_id=(select auth.uid()) and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false));
do $$ declare p record; begin for p in select tablename,policyname,cmd from pg_policies where schemaname='public' and policyname in ('moderator_audit_read','moderator_profiles_update','moderator_reports_read','moderator_reports_update','moderator_comments_read','moderator_comments_delete','feedback_admin_guard','feedback_delete_admin_guard') loop
 execute format('alter policy %I on public.%I using (private.is_moderator() and not coalesce(((select auth.jwt())->>''is_anonymous'')::boolean,false))',p.policyname,p.tablename);
 if p.cmd='UPDATE' then execute format('alter policy %I on public.%I with check (private.is_moderator() and not coalesce(((select auth.jwt())->>''is_anonymous'')::boolean,false))',p.policyname,p.tablename);end if;
end loop;end $$;
alter function public.set_updated_at() set search_path='';
