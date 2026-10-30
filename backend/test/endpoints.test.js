const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { makeApp, tokenFor } = require('./helpers');

const ENDPOINTS = [
  ['post', '/api/auth/register', 'public'],
  ['post', '/api/auth/login', 'public'],
  ['post', '/api/auth/logout', 'auth'],
  ['get', '/api/auth/me', 'auth'],
  ['get', '/api/films', 'optional'],
  ['get', '/api/films/1', 'optional'],
  ['post', '/api/films', 'creator'],
  ['put', '/api/films/1', 'creator'],
  ['delete', '/api/films/1', 'creator'],
  ['post', '/api/films/1/episodes', 'creator'],
  ['get', '/api/episodes/1', 'optional'],
  ['put', '/api/episodes/1', 'creator'],
  ['delete', '/api/episodes/1', 'creator'],
  ['get', '/api/episodes/1/stream', 'optional'],
  ['post', '/api/episodes/1/unlock', 'auth'],
  ['get', '/api/wallet', 'auth'],
  ['get', '/api/wallet/transactions', 'auth'],
  ['post', '/api/wallet/topup', 'auth'],
  ['get', '/api/coin-packs', 'public'],
  ['get', '/api/subscription', 'auth'],
  ['post', '/api/subscription', 'auth'],
  ['get', '/api/creator/films', 'creator'],
  ['get', '/api/creator/earnings', 'creator'],
  ['get', '/api/admin/reviews', 'admin'],
  ['post', '/api/admin/films/1/review', 'admin'],
  ['get', '/api/admin/sales', 'admin'],
  ['put', '/api/admin/settings/revenue-share', 'admin'],
  ['get', '/api/admin/users', 'admin'],
  ['put', '/api/admin/users/1/role', 'admin'],
  ['get', '/api/admin/reports', 'admin'],
  ['post', '/api/admin/reports/1/resolve', 'admin'],
  ['post', '/api/films/1/like', 'auth'],
  ['delete', '/api/films/1/like', 'auth'],
  ['get', '/api/watchlist', 'auth'],
  ['post', '/api/films/1/watchlist', 'auth'],
  ['delete', '/api/films/1/watchlist', 'auth'],
  ['get', '/api/films/1/comments', 'public'],
  ['post', '/api/films/1/comments', 'auth'],
  ['delete', '/api/comments/1', 'auth'],
  ['post', '/api/creators/1/follow', 'auth'],
  ['delete', '/api/creators/1/follow', 'auth'],
  ['post', '/api/films/1/reports', 'auth'],
];

const app = makeApp();

async function expectStatus(method, path, role, status) {
  const r = request(app)[method](path);
  const res = await (role ? r.set('Authorization', `Bearer ${tokenFor(role)}`) : r);
  assert.equal(res.status, status);
  if (status === 501) assert.equal(res.body.error.code, 'NOT_IMPLEMENTED');
}

// [role, expected status]; null means no token.
const CHECKS = {
  public: [[null, 501]],
  optional: [[null, 501], ['viewer', 501]],
  auth: [[null, 401], ['viewer', 501]],
  creator: [[null, 401], ['viewer', 403], ['creator', 501], ['admin', 501]],
  admin: [[null, 401], ['creator', 403], ['admin', 501]],
};

test('the table lists all 42 endpoints', () => assert.equal(ENDPOINTS.length, 42));

for (const [method, path, access] of ENDPOINTS) {
  test(`${method.toUpperCase()} ${path} is ${access}`, async () => {
    for (const [role, status] of CHECKS[access]) {
      await expectStatus(method, path, role, status);
    }
  });
}
