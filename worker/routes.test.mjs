import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../cloudflare-worker/src/index.js';
const id = '11111111-1111-4111-8111-111111111111';
const origin = 'https://muhammedbajinka.github.io';
test('browser preflight permits authenticated DELETE on the allowed origin', async () => {
  const response = await worker.fetch(new Request(`https://worker.example/media/${id}`, {
    method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': 'DELETE' },
  }), {});
  assert.equal(response.status, 204);
  assert.match(response.headers.get('Access-Control-Allow-Methods'), /DELETE/);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin);
});
test('unapproved browser origin gets no CORS permission', async () => {
  const response = await worker.fetch(new Request(`https://worker.example/media/${id}`, {
    method: 'OPTIONS', headers: { Origin: 'https://other.example' },
  }), {});
  assert.equal(response.status, 403);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);
});
test('actual DELETE route rejects missing session with JSON and CORS', async () => {
  const response = await worker.fetch(new Request(`https://worker.example/media/${id}`, {
    method: 'DELETE', headers: { Origin: origin },
  }), {});
  assert.equal(response.status, 401);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin);
  assert.equal((await response.json()).error, 'Sign in required');
});
test('malformed DELETE route cannot fall through to a success response', async () => {
  const response = await worker.fetch(new Request('https://worker.example/media/invalid', { method: 'DELETE' }), {});
  assert.equal(response.status, 400);
});
test('existing health route stays available', async () => {
  const response = await worker.fetch(new Request('https://worker.example/health'), {});
  assert.equal(response.status, 200);
  assert.equal((await response.json()).service, 'quran-media-worker');
});
