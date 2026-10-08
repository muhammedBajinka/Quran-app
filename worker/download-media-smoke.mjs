// Read-only smoke checks against the deployed endpoint. No real user credentials.
import assert from 'node:assert/strict';
const endpoint = 'https://ppolqfsdbsgaocgasnrb.supabase.co/functions/v1/download-media';
const origin = 'https://muhammedbajinka.github.io';
const options = await fetch(endpoint, { method: 'OPTIONS', headers: {
  Origin: origin, 'Access-Control-Request-Method': 'GET',
  'Access-Control-Request-Headers': 'authorization,apikey',
} });
assert.equal(options.status, 204);
assert.equal(options.headers.get('Access-Control-Allow-Origin'), origin);
assert.match(options.headers.get('Access-Control-Allow-Headers'), /authorization/);
assert.match(options.headers.get('Access-Control-Expose-Headers'), /Content-Length/);
const anonymous = await fetch(endpoint, { headers: { Origin: origin } });
assert.equal(anonymous.status, 401);
const expired = await fetch(`${endpoint}?media=12345678-1234-1234-1234-123456789abc`, {
  headers: { Origin: origin, Authorization: 'Bearer invalid-test-token' },
});
assert.equal(expired.status, 401);
console.log('Live download endpoint: browser preflight and authentication rejection passed.');
