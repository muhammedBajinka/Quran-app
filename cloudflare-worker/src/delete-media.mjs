// Integrate this route into the existing Worker's fetch before its fallback.
// Required existing bindings: QURAN_MEDIA, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY.
// No service-role key is used: every database operation uses the caller's RLS.
export async function deleteMedia(request, env, fetcher = fetch) {
  const match = new URL(request.url).pathname.match(/^\/media\/([0-9a-f-]{36})$/i);
  if (request.method !== 'DELETE' || !match) return null;
  const json = (body, status = 200) => Response.json(body, { status });
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'Sign in required' }, 401);
  const headers = { Authorization: authorization, apikey: env.SUPABASE_PUBLISHABLE_KEY };
  const base = env.SUPABASE_URL.replace(/\/$/, '');
  const auth = await fetcher(`${base}/auth/v1/user`, { headers });
  if (!auth.ok) return json({ error: 'Invalid session' }, 401);
  const user = await auth.json();
  if (!user.id || user.is_anonymous) return json({ error: 'Account required' }, 403);
  const id = match[1];
  const endpoint = `${base}/rest/v1/media_content?id=eq.${id}&creator_id=eq.${user.id}`;
  const result = await fetcher(`${endpoint}&select=id,creator_id,media_url,thumbnail_path`, { headers });
  if (!result.ok) return json({ error: 'Ownership lookup failed' }, 502);
  const rows = await result.json();
  // Missing/non-owner rows use the same response; don't leak private posts.
  if (rows.length !== 1 || rows[0].creator_id !== user.id) return json({ error: 'Post unavailable' }, 404);
  const row = rows[0];
  let key;
  try {
    const mediaUrl = new URL(row.media_url);
    if (mediaUrl.origin !== env.MEDIA_PUBLIC_BASE_URL) return json({ error: "Storage host mismatch" }, 409);
    key = decodeURIComponent(mediaUrl.pathname.slice(1));
  } catch {
    return json({ error: 'Invalid stored media URL' }, 409);
  }
  // Never accept a key, URL or creator ID from the caller. Support only the
  // verified upload layout; legacy layouts require explicit migration.
  if (!key.startsWith(`media/${user.id}/${id}/`) || key.includes('..')) {
    return json({ error: 'Media needs storage migration before deletion' }, 409);
  }
  if (row.thumbnail_path && !row.thumbnail_path.startsWith(`${user.id}/`)) {
    return json({ error: 'Thumbnail ownership mismatch' }, 409);
  }
  const object = await env.QURAN_MEDIA.head(key);
  if (object && (object.customMetadata?.creatorId !== user.id || object.customMetadata?.mediaId !== id)) {
    return json({ error: 'Storage ownership mismatch' }, 409);
  }
  // Hide before cleanup. If any later step fails, retain the owned row for a
  // safe retry from Drafts instead of falsely reporting a successful deletion.
  const hidden = await fetcher(endpoint, {
    method: 'PATCH', headers: { ...headers, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: JSON.stringify({ published: false, visibility: 'private' }),
  });
  if (!hidden.ok || (await hidden.json()).length !== 1) return json({ error: 'Could not hide post' }, 502);
  try {
    await env.QURAN_MEDIA.delete(key); // Missing objects are safe to retry.
    if (row.thumbnail_path) {
      const thumbnail = await fetcher(`${base}/storage/v1/object/media-thumbnails`, {
        method: 'DELETE', headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: [row.thumbnail_path] }),
      });
      if (!thumbnail.ok) return json({ error: 'Thumbnail cleanup failed; retry from Drafts' }, 502);
    }
    const removed = await fetcher(endpoint, {
      method: 'DELETE', headers: { ...headers, Prefer: 'return=representation' },
    });
    if (!removed.ok || (await removed.json()).length !== 1) return json({ error: 'Post cleanup failed; retry from Drafts' }, 502);
    return json({ deleted: id });
  } catch {
    return json({ error: 'Storage cleanup failed; retry from Drafts' }, 502);
  }
}
