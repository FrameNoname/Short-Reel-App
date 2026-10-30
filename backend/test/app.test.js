const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { makeApp, failingPool } = require('./helpers');

test('health is 200 when the pool answers', async () => {
  const res = await request(makeApp()).get('/api/health');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: 'ok', db: 'up' });
});

test('health is 503 when the pool fails', async () => {
  const res = await request(makeApp(failingPool)).get('/api/health');
  assert.equal(res.status, 503);
  assert.equal(res.body.error.code, 'DB_UNAVAILABLE');
});

test('unknown route is a 404 in the shared format', async () => {
  const res = await request(makeApp()).get('/api/nope');
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});

test('malformed JSON is a 400, not a 500', async () => {
  const res = await request(makeApp())
    .post('/api/nope')
    .set('Content-Type', 'application/json')
    .send('{bad');
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
});

test('unexpected errors hide their details', async () => {
  const secret = 'db password leaked';
  const outer = require('express')();
  outer.get('/boom', () => {
    throw new Error(secret);
  });
  outer.use(require('../src/middleware/errorHandler'));
  const res = await request(outer).get('/boom');
  assert.equal(res.status, 500);
  assert.equal(res.body.error.code, 'INTERNAL_ERROR');
  assert.ok(!JSON.stringify(res.body).includes(secret));
});
