const test = require('node:test');
const assert = require('node:assert/strict');
const { loadEnv } = require('../src/config/env');

test('loadEnv refuses a missing JWT_SECRET', () => {
  assert.throws(() => loadEnv({}), /JWT_SECRET/);
});

test('loadEnv refuses the .env.example placeholder secret', () => {
  assert.throws(() => loadEnv({ JWT_SECRET: 'change-me' }), /JWT_SECRET/);
});

test('loadEnv applies the defaults', () => {
  const env = loadEnv({ JWT_SECRET: 's' });
  assert.equal(env.port, 3000);
  assert.equal(env.db.database, 'shortreel');
  assert.equal(env.jwtExpiresIn, '7d');
});
