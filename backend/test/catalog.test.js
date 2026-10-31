const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { createApp } = require('../src/app');
const { createCatalogClient } = require('../src/services/seriesjeen');
const { TEST_SECRET, okPool, tokenFor } = require('./helpers');

function appWith(fetchImpl) {
  const catalog = createCatalogClient({ apiKey: 'k-secret', baseUrl: 'https://up.test', fetchImpl });
  return createApp({ pool: okPool, jwtSecret: TEST_SECRET, catalog });
}

function recorder(status = 200, body = { ok: true }, headers = {}) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url: String(url), auth: init.headers.Authorization });
    return new Response(JSON.stringify(body), { status, headers });
  };
  return { calls, fetchImpl };
}

test('answers 503 when no catalog key is configured', async () => {
  const app = createApp({ pool: okPool, jwtSecret: TEST_SECRET });
  const res = await request(app).get('/api/catalog/platforms');
  assert.equal(res.status, 503);
  assert.equal(res.body.error.code, 'CATALOG_UNAVAILABLE');
});

test('relays platforms with the server-side key', async () => {
  const { calls, fetchImpl } = recorder(200, { total: 1, items: [] });
  const res = await request(appWith(fetchImpl)).get('/api/catalog/platforms');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { total: 1, items: [] });
  assert.equal(calls[0].url, 'https://up.test/api/platforms');
  assert.equal(calls[0].auth, 'Bearer k-secret');
});

test('passes only known drama list parameters', async () => {
  const { calls, fetchImpl } = recorder();
  await request(appWith(fetchImpl))
    .get('/api/catalog/platforms/19/dramas')
    .query({ q: 'รัก', sort: 'episodes', page: 2, page_size: 10, evil: 'x' });
  const url = new URL(calls[0].url);
  assert.equal(url.pathname, '/api/platforms/19/dramas');
  assert.equal(url.searchParams.get('q'), 'รัก');
  assert.equal(url.searchParams.get('page_size'), '10');
  assert.equal(url.searchParams.has('evil'), false);
});

test('rejects bad list parameters before calling upstream', async () => {
  const { calls, fetchImpl } = recorder();
  const app = appWith(fetchImpl);
  for (const query of [{ page_size: 51 }, { page: 0 }, { sort: 'x' }, { q: '' }]) {
    const res = await request(app).get('/api/catalog/platforms/19/dramas').query(query);
    assert.equal(res.status, 400);
  }
  const res = await request(app).get('/api/catalog/platforms/abc/dramas');
  assert.equal(res.status, 400);
  assert.equal(calls.length, 0);
});

test('episode links need a logged-in viewer', async () => {
  const { calls, fetchImpl } = recorder();
  const res = await request(appWith(fetchImpl)).get('/api/catalog/dramas/5/episodes?ep=1');
  assert.equal(res.status, 401);
  assert.equal(calls.length, 0);
});

test('episode links accept one episode or a short range only', async () => {
  const { calls, fetchImpl } = recorder();
  const app = appWith(fetchImpl);
  const auth = { Authorization: `Bearer ${tokenFor('viewer')}` };
  for (const ep of ['1', '2-4']) {
    const res = await request(app).get('/api/catalog/dramas/5/episodes').query({ ep }).set(auth);
    assert.equal(res.status, 200);
  }
  for (const ep of [undefined, '0', '5-3', '1-4', '1-99', 'a']) {
    const res = await request(app).get('/api/catalog/dramas/5/episodes').query({ ep }).set(auth);
    assert.equal(res.status, 400, `ep=${ep}`);
  }
  assert.equal(calls.length, 2);
});

test('maps upstream failures without leaking details', async () => {
  const cases = [
    [401, 502, 'CATALOG_ERROR'],
    [403, 403, 'CATALOG_NO_ACCESS'],
    [404, 404, 'NOT_FOUND'],
    [500, 502, 'CATALOG_ERROR'],
  ];
  for (const [upstream, status, code] of cases) {
    const { fetchImpl } = recorder(upstream, { detail: 'secret detail' });
    const res = await request(appWith(fetchImpl)).get('/api/catalog/dramas/5');
    assert.equal(res.status, status);
    assert.equal(res.body.error.code, code);
    assert.doesNotMatch(JSON.stringify(res.body), /secret detail/);
  }
});

test('forwards Retry-After on rate limits', async () => {
  const { fetchImpl } = recorder(429, {}, { 'Retry-After': '12' });
  const res = await request(appWith(fetchImpl)).get('/api/catalog/platforms');
  assert.equal(res.status, 429);
  assert.equal(res.headers['retry-after'], '12');
});

test('reports an unreachable catalog as 502', async () => {
  const app = appWith(async () => {
    throw new Error('ECONNREFUSED');
  });
  const res = await request(app).get('/api/catalog/platforms');
  assert.equal(res.status, 502);
  assert.equal(res.body.error.code, 'CATALOG_UNREACHABLE');
});

test('guests may fetch episode links only when explicitly allowed', async () => {
  const { fetchImpl } = recorder();
  const catalog = createCatalogClient({ apiKey: 'k', baseUrl: 'https://up.test', fetchImpl });
  const app = createApp({ pool: okPool, jwtSecret: TEST_SECRET, catalog, catalogAllowGuest: true });
  const res = await request(app).get('/api/catalog/dramas/5/episodes?ep=1');
  assert.equal(res.status, 200);
});
