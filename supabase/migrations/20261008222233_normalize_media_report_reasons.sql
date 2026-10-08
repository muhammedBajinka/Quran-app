-- Accept reason labels used by already-installed apps, while storing only the
-- canonical moderation codes. Existing reporter/admin RLS remains unchanged.
create function private.normalize_media_report_reason() returns trigger
language plpgsql set search_path='' as $$ begin
new.reason=case lower(trim(new.reason))
 when 'inappropriate content' then 'inappropriate'
 when 'misleading content' then 'misleading'
 when 'copyright concern' then 'copyright'
 else lower(trim(new.reason)) end;
return new; end $$;
revoke all on function private.normalize_media_report_reason() from public,anon,authenticated;
create trigger normalize_media_report_reason before insert on public.media_reports
for each row execute function private.normalize_media_report_reason();
