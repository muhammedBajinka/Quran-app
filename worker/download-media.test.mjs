import test from 'node:test';
import assert from 'node:assert/strict';
import { createDownloadHandler } from '../supabase/functions/download-media/handler.mjs';

const id = '12345678-1234-1234-1234-123456789abc';
const url = `https://example.supabase.co/functions/v1/download-media?media=${id}`;
const mediaUrl = 'https://pub-eeb6a67046c4422baecb5321c3b21655.r2.dev/test.mp4';
const request = (extra = {}) => new Request(url, {
  headers: { Authorization: 'Bearer guest-session', Origin: 'https://muhammedbajinka.github.io' }, ...extra,
});
function handler({ auth = 200, rows = [{ media_url: mediaUrl, downloads_enabled: true }], status = 200 } = {}) {
  const calls = [];
  const handle = createDownloadHandler({ supabaseUrl: 'https://example.supabase.co', apiKey: 'public-key',
    fetchImpl: async (input, options) => {
      const target = String(input); calls.push({ target, options });
      if (target.endsWith('/auth/v1/user')) return new Response('{}', { status: auth });
      if (target.includes('/rest/v1/media_content')) return Response.json(rows);
      return new Response(new Uint8Array([1, 2, 3]), {
        status, headers: { 'Content-Length': '3', 'Content-Type': 'video/mp4' },
      });
    },
  });
  return { handle, calls };
}
test('streams actual bytes with browser CORS, progress headers and caller RLS', async () => {
  const { handle, calls } = handler();
  const result = await handle(request());
  assert.equal(result.status, 200);
  assert.deepEqual([...new Uint8Array(await result.arrayBuffer())], [1, 2, 3]);
  assert.equal(result.headers.get('Access-Control-Allow-Origin'), 'https://muhammedbajinka.github.io');
  assert.match(result.headers.get('Access-Control-Expose-Headers'), /Content-Length/);
  assert.equal(result.headers.get('Content-Length'), '3');
  assert.equal(calls[1].options.headers.Authorization, 'Bearer guest-session');
  assert.match(calls[1].target, /published=eq.true/);
  assert.equal(calls[2].options.redirect, 'error');
});
test('rejects missing or expired sessions before accessing media', async () => {
  const missing = handler();
  assert.equal((await missing.handle(request({ headers: {} }))).status, 401);
  assert.equal(missing.calls.length, 0);
  const expired = handler({ auth: 401 });
  assert.equal((await expired.handle(request())).status, 401);
  assert.equal(expired.calls.length, 1);
});
test('inaccessible posts and disabled downloads never fetch the file', async () => {
  for (const rows of [[], [{ media_url: mediaUrl, downloads_enabled: false }]]) {
    const { handle, calls } = handler({ rows });
    assert.ok([403, 404].includes((await handle(request())).status));
    assert.equal(calls.length, 2);
  }
});
test('rejects arbitrary URLs and redirects to avoid a general proxy', async () => {
  for (const media_url of ['https://evil.example/file', 'http://127.0.0.1/file',
    'https://user:secret@pub-eeb6a67046c4422baecb5321c3b21655.r2.dev/file']) {
    const { handle, calls } = handler({ rows: [{ media_url, downloads_enabled: true }] });
    assert.equal((await handle(request())).status, 400);
    assert.equal(calls.length, 2);
  }
});
test('upstream failures never return a successful download', async () => {
  assert.equal((await handler({ status: 404 }).handle(request())).status, 502);
});
test('preflight permits the app and blocks unrelated origins', async () => {
  const { handle, calls } = handler();
  assert.equal((await handle(request({ method: 'OPTIONS' }))).status, 204);
  assert.equal((await handle(request({ headers: { Origin: 'https://evil.example' } }))).status, 403);
  assert.equal(calls.length, 0);
});
