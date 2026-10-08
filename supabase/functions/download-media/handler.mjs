const appOrigin = "https://muhammedbajinka.github.io";
const r2Host = "pub-eeb6a67046c4422baecb5321c3b21655.r2.dev";

export function createDownloadHandler({ supabaseUrl, apiKey, fetchImpl = fetch }) {
  return async function handle(request) {
    const origin = request.headers.get("Origin");
    const headers = {
      "Access-Control-Allow-Origin": appOrigin,
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "authorization, apikey, x-client-info",
      "Access-Control-Expose-Headers": "Content-Length, Content-Type",
      "Vary": "Origin",
      "Cache-Control": "no-store",
    };
    const fail = (status, message) => new Response(JSON.stringify({ error: message }), {
      status, headers: { ...headers, "Content-Type": "application/json" },
    });
    if (origin && origin !== appOrigin) return fail(403, "Origin is not allowed.");
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (request.method !== "GET") return fail(405, "Use GET.");
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return fail(401, "Sign in before downloading.");
    const id = new URL(request.url).searchParams.get("media");
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id ?? "")) {
      return fail(400, "Invalid post.");
    }
    try {
      // Validate the session, including guests. Never use a service-role key.
      const authHeaders = { apikey: apiKey, Authorization: authorization };
      const user = await fetchImpl(`${supabaseUrl}/auth/v1/user`, { headers: authHeaders, signal: request.signal });
      if (!user.ok) return fail(401, "Your session expired. Refresh and try again.");
      const query = new URL(`${supabaseUrl}/rest/v1/media_content`);
      query.searchParams.set("select", "media_url,downloads_enabled");
      query.searchParams.set("id", `eq.${id}`);
      query.searchParams.set("published", "eq.true");
      // RLS evaluates this request using the caller's session.
      const rowResponse = await fetchImpl(query, { headers: authHeaders, signal: request.signal });
      if (!rowResponse.ok) return fail(403, "This post is unavailable.");
      const rows = await rowResponse.json();
      if (rows.length !== 1) return fail(404, "This post is unavailable.");
      const row = rows[0];
      if (!row.downloads_enabled) return fail(403, "Downloads are off for this post.");
      const source = new URL(row.media_url);
      if (source.protocol !== "https:" || source.username || source.password ||
          (source.port && source.port !== "443") ||
          !(source.hostname === r2Host ||
            (source.origin === supabaseUrl && source.pathname.startsWith("/storage/v1/object/")))) {
        return fail(400, "This media source is not supported.");
      }
      const media = await fetchImpl(source, { redirect: "error", signal: request.signal });
      if (!media.ok || !media.body) return fail(502, "The media file is unavailable. Try again.");
      const length = media.headers.get("Content-Length");
      if (length) headers["Content-Length"] = length;
      headers["Content-Type"] = media.headers.get("Content-Type") ?? "application/octet-stream";
      // Stream without buffering the whole video in the server process.
      return new Response(media.body, { status: 200, headers });
    } catch (_) {
      return fail(502, "Download failed. Please try again.");
    }
  };
}
