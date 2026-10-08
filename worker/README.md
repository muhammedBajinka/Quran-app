# Media Worker deletion

The existing Worker source is in `cloudflare-worker/src/index.js`. Its DELETE route imports `src/delete-media.mjs`, uses the existing QURAN_MEDIA R2 binding and SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY secrets, and shares the existing restricted CORS wrapper. No new service-role or R2 secret is required.

Run `node --test worker/*.test.mjs` from the repository root. Deploy from `cloudflare-worker` using the existing authenticated Wrangler installation: `npx wrangler deploy`. Existing Cloudflare secrets remain configured on the same Worker.

Deletion authenticates the caller, rejects anonymous users, verifies database ownership under RLS, and verifies the exact R2 host, upload path and object custom metadata. Post and thumbnail deletion use existing owner policies. The original object and owned thumbnail are cleaned before the database row is removed. The server confirms the ID only after cleanup succeeds.

The post is hidden before storage cleanup. If cleanup fails, its row remains in Drafts for retry using More → Delete. Legacy storage layouts fail closed and must be verified/migrated separately. No legacy object is guessed or deleted.

Deployment and phone tests must be verified separately from source tests and compilation.
