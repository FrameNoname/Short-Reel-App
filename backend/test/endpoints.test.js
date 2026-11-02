// Role matrix for every endpoint, against the real database. Calls that are
// allowed use an id that does not exist (9999), so they answer 400/404 and
// never change data; calls that are not allowed must be refused with 401/403
// before anything else looks at the request.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
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
  ['get', '/api/wallet/unlocked', 'auth'],
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
// What an allowed caller gets back for each request (ids 9999 do not exist, bodies are empty).
const EXPECTED = {
  'DELETE /api/comments/9999': 404,
  'DELETE /api/creators/9999/follow': 200,
  'DELETE /api/episodes/9999': 404,
  'DELETE /api/films/9999': 404,
  'DELETE /api/films/9999/like': 404,
  'DELETE /api/films/9999/watchlist': 200,
  'DELETE /api/subscription': 200,
  'GET /api/admin/films': 200,
  'GET /api/admin/reports': 200,
  'GET /api/admin/reviews': 200,
  'GET /api/admin/sales': 200,
  'GET /api/admin/settings/revenue-share': 200,
  'GET /api/admin/users': 200,
  'GET /api/auth/me': 200,
  'GET /api/coin-packs': 200,
  'GET /api/creator/earnings': 200,
  'GET /api/creator/films': 200,
  'GET /api/episodes/9999': 404,
  'GET /api/episodes/9999/stream': 404,
  'GET /api/films': 200,
  'GET /api/films/9999': 404,
  'GET /api/films/9999/comments': 404,
  'GET /api/lookups': 200,
  'GET /api/subscription': 200,
  'GET /api/wallet': 200,
  'GET /api/wallet/transactions': 200,
  'GET /api/wallet/unlocked': 200,
  'GET /api/watchlist': 200,
  'POST /api/admin/films/9999/review': 400,
  'POST /api/admin/reports/9999/resolve': 404,
  'POST /api/auth/login': 400,
  'POST /api/auth/logout': 200,
  'POST /api/auth/register': 400,
  'POST /api/creators/9999/follow': 404,
  'POST /api/episodes/9999/unlock': 404,
  'POST /api/films': 400,
  'POST /api/films/9999/comments': 404,
  'POST /api/films/9999/episodes': 404,
  'POST /api/films/9999/like': 404,
  'POST /api/films/9999/reports': 404,
  'POST /api/films/9999/watchlist': 404,
  'POST /api/subscription': 201,
  'POST /api/wallet/topup': 400,
  'PUT /api/admin/settings/revenue-share': 400,
  'PUT /api/admin/users/9999/role': 400,
  'PUT /api/auth/me': 400,
  'PUT /api/episodes/9999': 404,
  'PUT /api/films/9999': 404,
};

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

// The table must cover every route the app mounts (catalog is an optional,
// separately tested add-on; /api/lookups lives in app.js, /api/health is probed elsewhere).
test('the table lists every mounted endpoint', () => {
  const dir = path.join(__dirname, '..', 'src', 'routes');
  let mounted = 1;
  for (const file of fs.readdirSync(dir)) {
    if (file === 'catalog.js') continue;
    const source = fs.readFileSync(path.join(dir, file), 'utf8');
    mounted += (source.match(/^\s*[A-Za-z]*[rR]outer\.(get|post|put|delete)\(/gm) ?? []).length;
  }
  assert.equal(ENDPOINTS.length, mounted);
});

for (const [method, path, access] of ENDPOINTS) {
  test(`${method.toUpperCase()} ${path} is ${access}`, async () => {
    for (const [who, status] of REFUSED[access]) {
      const res = await env.req(method, path, who && (await env.login(who)));
      assert.equal(res.status, status, `${who ?? 'guest'} should be refused`);
    }
    for (const who of ALLOWED[access]) {
      const res = await env.req(method, path, who && (await env.login(who)));
      const want = EXPECTED[`${method.toUpperCase()} ${path}`];
      assert.equal(res.status, want, `${who ?? 'guest'}: ${method} ${path} should answer ${want}, got ${res.status}`);
      if (want >= 400) assert.ok(res.body.error?.code, 'a refusal carries a machine-readable error code');
      else assert.equal(typeof res.body, 'object', 'a success carries a JSON body');
    }
  });
}

test('a bad token is refused even on an optional endpoint', async () => {
  const res = await env.req('get', '/api/films', 'garbage');
  assert.equal(res.status, 401);
});
