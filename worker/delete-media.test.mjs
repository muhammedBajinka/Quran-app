import test from 'node:test';
import assert from 'node:assert/strict';
import { deleteMedia } from './delete-media.mjs';
const id = '11111111-1111-4111-8111-111111111111';
const userId = '22222222-2222-4222-8222-222222222222';
function setup({ user = { id: userId }, rows, metadata, storageFailure = false, dbFailure = false } = {}) {
  const actions = [];
  const row = { id, creator_id: userId, media_url: `https://media.example/media/${userId}/${id}/original.mp3` };
  const fetcher = async (url, options) => {
    actions.push(options.method ?? 'GET');
    if (url.endsWith('/auth/v1/user')) return Response.json(user);
    if (options.method === 'PATCH') return Response.json([row]);
    if (options.method === 'DELETE') return Response.json(dbFailure ? { error: 'failed' } : [row], { status: dbFailure ? 500 : 200 });
    return Response.json(rows ?? [row]);
  };
  const env = { SUPABASE_URL: 'https://project.example', SUPABASE_ANON_KEY: 'public-key', QURAN_MEDIA: {
    head: async () => ({ customMetadata: metadata ?? { creatorId: userId, mediaId: id } }),
    delete: async () => { actions.push('R2 DELETE'); if (storageFailure) throw Error('storage failure'); },
  } };
  const request = new Request(`https://worker.example/media/${id}`, { method: 'DELETE', headers: { Authorization: 'Bearer test' } });
  return { env, fetcher, request, actions };
}
test('rejects unauthenticated and anonymous requests without storage writes', async () => {
  const s = setup();
  assert.equal((await deleteMedia(new Request(s.request.url, { method: 'DELETE' }), s.env, s.fetcher)).status, 401);
  assert.deepEqual(s.actions, []);
  const a = setup({ user: { id: userId, is_anonymous: true } });
  assert.equal((await deleteMedia(a.request, a.env, a.fetcher)).status, 403);
  assert.deepEqual(a.actions, ['GET']);
});
test('non-owner cannot delete an object', async () => {
  const s = setup({ rows: [{ id, creator_id: 'other' }] });
  assert.equal((await deleteMedia(s.request, s.env, s.fetcher)).status, 404);
  assert.deepEqual(s.actions, ['GET', 'GET']);
});
test('tampered storage path and metadata fail before mutation', async () => {
  for (const args of [ { rows: [{ id, creator_id: userId, media_url: 'https://media.example/other/file.mp3' }] }, { metadata: { creatorId: 'other', mediaId: id } } ]) {
    const s = setup(args);
    assert.equal((await deleteMedia(s.request, s.env, s.fetcher)).status, 409);
    assert.deepEqual(s.actions, ['GET', 'GET']);
  }
});
test('owner hides post, cleans R2, then removes database row', async () => {
  const s = setup();
  assert.equal((await deleteMedia(s.request, s.env, s.fetcher)).status, 200);
  assert.deepEqual(s.actions, ['GET', 'GET', 'PATCH', 'R2 DELETE', 'DELETE']);
});
test('storage failure retains row for retry and never reports success', async () => {
  const s = setup({ storageFailure: true });
  assert.equal((await deleteMedia(s.request, s.env, s.fetcher)).status, 502);
  assert.deepEqual(s.actions, ['GET', 'GET', 'PATCH', 'R2 DELETE']);
});
test('database deletion failure reports failure', async () => {
  const s = setup({ dbFailure: true });
  assert.equal((await deleteMedia(s.request, s.env, s.fetcher)).status, 502);
});
