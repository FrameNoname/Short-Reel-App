const test = require('node:test');
const assert = require('node:assert/strict');
const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const controller = require('../src/controllers/auth');
const { fakePool, fakeReq, fakeRes } = require('./helpers/fakes');

const isStatus = (status) => (err) => err.status === status;
const storedUser = (extra = {}) => ({
  id: 7,
  username: 'mira',
  display_name: 'Mira',
  avatar_url: null,
  bio: null,
  role: 'viewer',
  coin_balance: 0,
  created_at: '2026-11-01',
  ...extra,
});

test('register creates a viewer whatever role the body asks for', async () => {
  const pool = fakePool([
    ['INSERT INTO users', { insertId: 7 }],
    ['FROM users WHERE id = ?', [storedUser()]],
  ]);
  const res = fakeRes();
  await controller.register(
    fakeReq({ pool, body: { username: 'mira', password: 'secret123', role: 'admin' } }),
    res,
  );
  assert.equal(res.statusCode, 201);
  const insert = pool.callsMatching('INSERT INTO users')[0].params;
  assert.equal(insert[3], 'viewer');
  assert.notEqual(insert[1], 'secret123', 'the password is stored hashed');
  assert.equal(jwt.verify(res.body.token, 'test-secret').sub, '7');
  assert.equal(res.body.user.password, undefined);
});

test('register checks the username and password rules', async () => {
  const call = (body) => controller.register(fakeReq({ pool: fakePool(), body }), fakeRes());
  await assert.rejects(call({ username: 'ab', password: 'secret123' }), isStatus(400));
  await assert.rejects(call({ username: 'bad name!', password: 'secret123' }), isStatus(400));
  await assert.rejects(call({ username: 'mira', password: 'short1' }), isStatus(400));
  await assert.rejects(call({ username: 'mira', password: 'lettersonly' }), isStatus(400));
  await assert.rejects(call({ username: 'mira', password: '12345678' }), isStatus(400));
  await assert.rejects(call({ username: 'mira', password: `a1${'x'.repeat(71)}` }), isStatus(400));
});

test('register reports a taken username as 409', async () => {
  const pool = fakePool([
    ['INSERT INTO users', () => {
      throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
    }],
  ]);
  await assert.rejects(
    controller.register(fakeReq({ pool, body: { username: 'mira', password: 'secret123' } }), fakeRes()),
    isStatus(409),
  );
});

test('login returns a token for the right password only', async () => {
  const password = await argon2.hash('1111');
  const pool = fakePool([['WHERE username = ?', [storedUser({ password })]]]);
  const res = fakeRes();
  await controller.login(fakeReq({ pool, body: { username: 'mira', password: '1111' } }), res);
  assert.ok(res.body.token);
  assert.equal(res.body.user.password, undefined);

  await assert.rejects(
    controller.login(fakeReq({ pool, body: { username: 'mira', password: '2222' } }), fakeRes()),
    isStatus(401),
  );
});

test('login gives the same answer for an unknown username', async () => {
  const pool = fakePool([['WHERE username = ?', []]]);
  await assert.rejects(
    controller.login(fakeReq({ pool, body: { username: 'ghost', password: '1111' } }), fakeRes()),
    (err) => err.status === 401 && err.message === 'Username or password is wrong',
  );
});

test('updateMe saves the display name and bio', async () => {
  const pool = fakePool([
    ['UPDATE users', { affectedRows: 1 }],
    ['FROM users WHERE id = ?', [storedUser({ display_name: 'New', bio: 'Hi' })]],
  ]);
  const res = fakeRes();
  await controller.updateMe(
    fakeReq({ pool, user: { id: 7, role: 'viewer' }, body: { display_name: ' New ', bio: 'Hi' } }),
    res,
  );
  assert.deepEqual(pool.callsMatching('UPDATE users')[0].params, ['New', 'Hi', 7]);
  assert.equal(res.body.user.display_name, 'New');

  await assert.rejects(
    controller.updateMe(fakeReq({ pool, user: { id: 7 }, body: { display_name: '' } }), fakeRes()),
    isStatus(400),
  );
});
