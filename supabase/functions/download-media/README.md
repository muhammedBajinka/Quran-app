# Media download endpoint

The app calls this endpoint with its current bearer token. The handler validates the token with Supabase Auth, queries the published post under the caller's RLS, checks its saved download permission, and streams only an approved media-storage URL. It uses no service-role key.

Gateway `verify_jwt` is disabled because authentication is performed inside the handler with Auth (including modern signing keys). Keep that custom authentication check in place. Deployment:

```
supabase functions deploy download-media --no-verify-jwt
```

This endpoint avoids relying on R2 browser CORS and exposes Content-Length for progress. `worker/download-media.test.mjs` covers authentication, visibility, permission checks, URL restrictions and streamed bytes.
