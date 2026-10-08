# Media deletion integration

This is an integration module, not a replacement upload Worker. The existing deployed Worker source is outside this repository.

Import `deleteMedia` from `delete-media.mjs` into its existing `src/index.js` and call `await deleteMedia(request, env)` before the fallback route. If it returns a response, return it through the Worker's existing restricted CORS response wrapper. Add `DELETE` to its allowed preflight methods. Keep existing upload/auth routes.

The module needs `QURAN_MEDIA`, `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the project's publishable legacy anon key). It authenticates the caller with Supabase, rejects anonymous users, checks database ownership under RLS, and verifies the stored R2 object path and custom metadata. It does not trust caller-supplied storage paths or use a service-role key.

Verify the live upload layout and thumbnail path prefix before deploying. Only `media/<user-id>/<media-id>/...` R2 paths and `<user-id>/...` thumbnail paths are accepted. Other layouts fail closed and require migration. On cleanup failure the row remains hidden in Drafts for retry. Drafts can be opened via the shared viewer's Delete action.

Run `node --test worker/delete-media.test.mjs` and the existing Worker's checks, then deploy with its existing Wrangler configuration. This module has **not** been deployed by this change; the app handles an unavailable endpoint as a failed deletion.
