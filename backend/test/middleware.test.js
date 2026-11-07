const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const { requireAuth, optionalAuth } = require('../src/middleware/auth');
const requireRole = require('../src/middleware/requireRole');
const errorHandler = require('../src/middleware/errorHandler');
const ApiError = require('../src/utils/ApiError');
const { fakePool, fakeReq, fakeRes } = require('./helpers/fakes');

const SECRET = 'test-secret';
const bearer = (payload, secret = SECRET) => ({
  authorization: `Bearer ${jwt.sign(payload, secret, { algorithm: 'HS256' })}`,
});
const usersPool = (rows) => fakePool([['FROM users WHERE id = ?', rows]]);

// Runs a middleware and resolves with what it passed to next().
const run = (mw, req) => new Promise((resolve) => mw(req, fakeRes(), (err) => resolve(err)));

test('requireAuth reads the role from the database, not the token', async () => {
  const req = fakeReq({
    pool: usersPool([{ id: 5, role: 'viewer' }]),
    headers: bearer({ sub: '5', role: 'admin' }),
  });
  assert.equal(await run(requireAuth, req), undefined);
  assert.deepEqual(req.user, { id: 5, role: 'viewer' });
});

test('requireAuth rejects a missing, forged or non-login token', async () => {
  const cases = [
    {},
    { authorization: 'Token abc' },
    bearer({ sub: '5' }, 'wrong-secret'),
    bearer({ sub: '5', typ: 'stream' }),
    bearer({ sub: 'abc' }),
  ];
  for (const headers of cases) {
    const req = fakeReq({ pool: usersPool([{ id: 5, role: 'viewer' }]), headers });
    const err = await run(requireAuth, req);
    assert.equal(err?.status, 401, JSON.stringify(headers));
  }
});

test('requireAuth rejects a token for a deleted account', async () => {
  const err = await run(requireAuth, fakeReq({ pool: usersPool([]), headers: bearer({ sub: '5' }) }));
  assert.equal(err.status, 401);
});

test('optionalAuth lets guests through but still checks a sent token', async () => {
  const guest = fakeReq({ pool: usersPool([]) });
  assert.equal(await run(optionalAuth, guest), undefined);
  assert.equal(guest.user, undefined);

  const bad = fakeReq({ pool: usersPool([]), headers: { authorization: 'Bearer nope' } });
  assert.equal((await run(optionalAuth, bad)).status, 401);
});

test('requireRole lets the listed roles through and blocks the rest', () => {
  const adminOnly = requireRole('admin');
  let passed = false;
  adminOnly({ user: { role: 'admin' } }, fakeRes(), () => {
    passed = true;
  });
  assert.equal(passed, true);
  assert.throws(
    () => adminOnly({ user: { role: 'viewer' } }, fakeRes(), () => {}),
    (err) => err.status === 403 && err.code === 'FORBIDDEN',
  );
});

test('errorHandler turns errors into the API error shape', () => {
  const send = (err) => {
    const res = fakeRes();
    errorHandler(err, {}, res, () => {});
    return res;
  };
  const api = send(new ApiError(404, 'NOT_FOUND', 'Film not found'));
  assert.equal(api.statusCode, 404);
  assert.deepEqual(api.body, { error: { code: 'NOT_FOUND', message: 'Film not found' } });

  assert.equal(send({ type: 'entity.parse.failed' }).statusCode, 400);
  assert.equal(send({ type: 'entity.too.large' }).statusCode, 413);

  const original = console.error;
  console.error = () => {};
  try {
    const crash = send(new Error('boom'));
    assert.equal(crash.statusCode, 500);
    assert.equal(crash.body.error.code, 'INTERNAL_ERROR');
    assert.ok(!JSON.stringify(crash.body).includes('boom'), 'internal details stay hidden');
  } finally {
    console.error = original;
  }
});
