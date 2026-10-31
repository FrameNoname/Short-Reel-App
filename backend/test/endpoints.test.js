// Role matrix for every endpoint, against the real database. Calls that are
// allowed use an id that does not exist (9999), so they answer 400/404 and
// never change data; calls that are not allowed must be refused with 401/403
// before anything else looks at the request.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createTestEnv } = require('./db');

const ENDPOINTS = [
  ['post', '/api/auth/register', 'public'],
  ['post', '/api/auth/login', 'public'],
  ['post', '/api/auth/logout', 'auth'],
  ['get', '/api/auth/me', 'auth'],
  ['put', '/api/auth/me', 'auth'],
  ['get', '/api/films', 'optional'],
  ['get', '/api/films/9999', 'optional'],
  ['post', '/api/films', 'creator'],
  ['put', '/api/films/9999', 'creator'],
  ['delete', '/api/films/9999', 'creator'],
  ['post', '/api/films/9999/episodes', 'creator'],
  ['get', '/api/episodes/9999', 'optional'],
  ['put', '/api/episodes/9999', 'creator'],
  ['delete', '/api/episodes/9999', 'creator'],
  ['get', '/api/episodes/9999/stream', 'optional'],
  ['post', '/api/episodes/9999/unlock', 'auth'],
  ['get', '/api/wallet', 'auth'],
  ['get', '/api/wallet/transactions', 'auth'],
  ['post', '/api/wallet/topup', 'auth'],
  ['get', '/api/coin-packs', 'public'],
  ['get', '/api/lookups', 'public'],
  ['get', '/api/subscription', 'auth'],
  ['post', '/api/subscription', 'auth'],
  ['delete', '/api/subscription', 'auth'],
  ['get', '/api/creator/films', 'creator'],
  ['get', '/api/creator/earnings', 'creator'],
  ['get', '/api/admin/reviews', 'admin'],
  ['get', '/api/admin/films', 'admin'],
  ['post', '/api/admin/films/9999/review', 'admin'],
  ['get', '/api/admin/sales', 'admin'],
  ['get', '/api/admin/settings/revenue-share', 'admin'],
  ['put', '/api/admin/settings/revenue-share', 'admin'],
  ['get', '/api/admin/users', 'admin'],
  ['put', '/api/admin/users/9999/role', 'admin'],
  ['get', '/api/admin/reports', 'admin'],
  ['post', '/api/admin/reports/9999/resolve', 'admin'],
  ['post', '/api/films/9999/like', 'auth'],
  ['delete', '/api/films/9999/like', 'auth'],
  ['get', '/api/watchlist', 'auth'],
  ['post', '/api/films/9999/watchlist', 'auth'],
  ['delete', '/api/films/9999/watchlist', 'auth'],
  ['get', '/api/films/9999/comments', 'optional'],
  ['post', '/api/films/9999/comments', 'auth'],
  ['delete', '/api/comments/9999', 'auth'],
  ['post', '/api/creators/9999/follow', 'auth'],
  ['delete', '/api/creators/9999/follow', 'auth'],
  ['post', '/api/films/9999/reports', 'auth'],
];

// Who is refused (status) and who gets through. null = no token.
const REFUSED = {
  public: [],
  optional: [],
  auth: [[null, 401]],
  creator: [[null, 401], ['viewer01', 403]],
  admin: [[null, 401], ['viewer01', 403], ['mira.lens', 403]],
};
const ALLOWED = {
  public: [null, 'viewer01'],
  optional: [null, 'viewer01'],
  auth: ['viewer01', 'mira.lens'],
  creator: ['mira.lens', 'admin'],
  admin: ['admin'],
};

let env;
test.before(async () => {
  env = await createTestEnv('matrix');
});
test.after(() => env.close());

test('the table lists every endpoint', () => assert.equal(ENDPOINTS.length, 47));

for (const [method, path, access] of ENDPOINTS) {
  test(`${method.toUpperCase()} ${path} is ${access}`, async () => {
    for (const [who, status] of REFUSED[access]) {
      const res = await env.req(method, path, who && (await env.login(who)));
      assert.equal(res.status, status, `${who ?? 'guest'} should be refused`);
    }
    for (const who of ALLOWED[access]) {
      const res = await env.req(method, path, who && (await env.login(who)));
      assert.ok(![401, 403, 501].includes(res.status), `${who ?? 'guest'} got ${res.status}`);
    }
  });
}

test('a bad token is refused even on an optional endpoint', async () => {
  const res = await env.req('get', '/api/films', 'garbage');
  assert.equal(res.status, 401);
});
