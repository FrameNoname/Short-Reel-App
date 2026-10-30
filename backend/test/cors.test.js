const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { makeApp } = require('./helpers');

const preflight = (origin) =>
  request(makeApp())
    .options('/api/wallet')
    .set('Origin', origin)
    .set('Access-Control-Request-Method', 'GET')
    .set('Access-Control-Request-Headers', 'authorization');

test('allows a local web app on any port', async () => {
  const res = await preflight('http://localhost:8080');
  assert.equal(res.headers['access-control-allow-origin'], 'http://localhost:8080');
  assert.match(res.headers['access-control-allow-headers'], /authorization/i);
});

test('does not allow other origins', async () => {
  const res = await preflight('https://evil.example');
  assert.equal(res.headers['access-control-allow-origin'], undefined);
});

test('does not allow a lookalike localhost domain', async () => {
  const res = await preflight('http://localhost.evil.example:8080');
  assert.equal(res.headers['access-control-allow-origin'], undefined);
});
