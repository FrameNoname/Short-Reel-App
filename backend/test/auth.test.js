const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');
const { requireAuth, optionalAuth } = require('../src/middleware/auth');
const requireRole = require('../src/middleware/requireRole');
const errorHandler = require('../src/middleware/errorHandler');
const { TEST_SECRET, tokenFor } = require('./helpers');

const app = express();
app.locals.jwtSecret = TEST_SECRET;
// The role comes from the database, not from the token.
const ROLES = { 1: 'admin', 7: 'viewer' };
app.locals.pool = {
  query: async (sql, [id]) => [ROLES[id] ? [{ id, role: ROLES[id] }] : []],
};
const whoAmI = (req, res) => res.json(req.user ?? null);
app.get('/auth', requireAuth, whoAmI);
app.get('/optional', optionalAuth, whoAmI);
app.get('/admin', requireAuth, requireRole('admin'), whoAmI);
app.use(errorHandler);

const get = (path, header) => {
  const r = request(app).get(path);
  return header === undefined ? r : r.set('Authorization', header);
};
const bearer = (token) => `Bearer ${token}`;

test('requireAuth rejects a missing token', async () => {
  const res = await get('/auth');
  assert.equal(res.status, 401);
  assert.equal(res.body.error.code, 'UNAUTHENTICATED');
});

test('requireAuth rejects an expired token', async () => {
  const res = await get('/auth', bearer(tokenFor('viewer', { expiresIn: -10 })));
  assert.equal(res.status, 401);
});

test('requireAuth rejects a wrong secret', async () => {
  const res = await get('/auth', bearer(tokenFor('viewer', { secret: 'other' })));
  assert.equal(res.status, 401);
});

test('requireAuth rejects alg none', async () => {
  const token = jwt.sign({ sub: '1', role: 'admin' }, '', { algorithm: 'none' });
  const res = await get('/auth', bearer(token));
  assert.equal(res.status, 401);
});

test('requireAuth rejects a bare Bearer header', async () => {
  const res = await get('/auth', 'Bearer ');
  assert.equal(res.status, 401);
});

test('requireAuth exposes id and role', async () => {
  const res = await get('/auth', bearer(tokenFor('viewer', { id: 7 })));
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { id: 7, role: 'viewer' });
});

test('optionalAuth lets guests through', async () => {
  const res = await get('/optional');
  assert.equal(res.status, 200);
  assert.equal(res.body, null);
});

test('optionalAuth rejects an invalid token', async () => {
  const res = await get('/optional', bearer('garbage'));
  assert.equal(res.status, 401);
});

test('requireRole rejects another role', async () => {
  const res = await get('/admin', bearer(tokenFor('viewer', { id: 7 })));
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'FORBIDDEN');
});

test('requireRole accepts a listed role', async () => {
  const res = await get('/admin', bearer(tokenFor('admin', { id: 1 })));
  assert.equal(res.status, 200);
});

test('a token that claims admin does not make a viewer an admin', async () => {
  const res = await get('/admin', bearer(tokenFor('admin', { id: 7 })));
  assert.equal(res.status, 403);
});

test('a token for a deleted account is rejected', async () => {
  const res = await get('/auth', bearer(tokenFor('viewer', { id: 99 })));
  assert.equal(res.status, 401);
});

test('a playback link is not accepted as a login token', async () => {
  const link = jwt.sign({ typ: 'stream', eid: 1, uid: null }, TEST_SECRET, { expiresIn: '10m' });
  assert.equal((await get('/auth', bearer(link))).status, 401);
  const guestLink = jwt.sign({ typ: 'stream', eid: 1, uid: 7, sub: '7' }, TEST_SECRET);
  assert.equal((await get('/auth', bearer(guestLink))).status, 401);
});
