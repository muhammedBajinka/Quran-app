-- RLS remains responsible for row ownership. Only grant the operations used
-- by the authenticated Worker deletion flow; do not grant other updates.
grant update (published, visibility) on public.media_content to authenticated;
grant delete on public.media_content to authenticated;
