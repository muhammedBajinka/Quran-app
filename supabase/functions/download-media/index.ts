import { createDownloadHandler } from './handler.mjs';

// The handler validates each bearer token with Auth and queries using caller RLS.
Deno.serve(createDownloadHandler({
  supabaseUrl: Deno.env.get('SUPABASE_URL')!,
  apiKey: Deno.env.get('SUPABASE_ANON_KEY')!,
}));
