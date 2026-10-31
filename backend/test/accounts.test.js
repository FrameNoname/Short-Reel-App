const test = require('node:test');
const assert = require('node:assert/strict');
const { createTestEnv } = require('./db');

let env;
test.before(async () => {
  env = await createTestEnv('accounts');
});
test.after(() => env.close());

const register = (body) => env.req('post', '/api/auth/register').send(body);

test('register stores an argon2id hash and returns a token', async () => {
  const res = await register({ username: 'new_viewer', password: 'secret123' });
  assert.equal(res.status, 201);
  assert.equal(res.body.user.role, 'viewer');
  assert.equal(res.body.user.coin_balance, 0);
  assert.equal(res.body.user.password, undefined);
  const [[row]] = await env.pool.query("SELECT password FROM users WHERE username = 'new_viewer'");
  assert.match(row.password, /^\$argon2id\$/);
  const me = await env.req('get', '/api/auth/me', res.body.token);
  assert.equal(me.body.user.username, 'new_viewer');
});

test('a person can register as a creator', async () => {
  const res = await register({ username: 'new_creator', password: 'secret123', role: 'creator' });
  assert.equal(res.status, 201);
  assert.equal(res.body.user.role, 'creator');
});

test('nobody can register as admin', async () => {
  const res = await register({ username: 'sneaky', password: 'secret123', role: 'admin' });
  assert.equal(res.status, 403);
  const [rows] = await env.pool.query("SELECT id FROM users WHERE username = 'sneaky'");
  assert.equal(rows.length, 0);
});

test('register validates username, password and role', async () => {
  for (const body of [
    { username: 'ab', password: 'secret123' },
    { username: 'bad name!', password: 'secret123' },
    { username: 'okname', password: '123' },
    { username: 'okname', password: 'secret123', role: 'wizard' },
    {},
  ]) {
    const res = await register(body);
    assert.equal(res.status, 400, JSON.stringify(body));
    assert.equal(res.body.error.code, 'VALIDATION_ERROR');
  }
});

test('a taken username is a 409, whatever its letter case', async () => {
  assert.equal((await register({ username: 'dupe_user', password: 'secret123' })).status, 201);
  assert.equal((await register({ username: 'dupe_user', password: 'secret123' })).status, 409);
  assert.equal((await register({ username: 'DUPE_user', password: 'secret123' })).status, 409);
});

test('login accepts the right password and rejects the wrong one', async () => {
  const ok = await env.req('post', '/api/auth/login').send({ username: 'viewer01', password: '6666' });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.user.role, 'viewer');
  for (const body of [
    { username: 'viewer01', password: 'wrong' },
    { username: 'nobody', password: '6666' },
  ]) {
    const bad = await env.req('post', '/api/auth/login').send(body);
    assert.equal(bad.status, 401);
    assert.equal(bad.body.error.message, 'Username or password is wrong');
  }
});

test('logout answers ok and needs a token', async () => {
  const token = await env.login('viewer01');
  assert.equal((await env.req('post', '/api/auth/logout', token)).status, 200);
  assert.equal((await env.req('post', '/api/auth/logout')).status, 401);
});

test('a viewer cannot use creator or admin endpoints', async () => {
  const token = await env.login('viewer01');
  assert.equal((await env.req('post', '/api/films', token).send({})).status, 403);
  assert.equal((await env.req('get', '/api/admin/sales', token)).status, 403);
});

test('an admin can promote a user, and the new role works at once', async () => {
  const { token, user } = await env.register('promote_me');
  assert.equal((await env.req('get', '/api/creator/films', token)).status, 403);
  const admin = await env.login('admin');
  const res = await env.req('put', `/api/admin/users/${user.id}/role`, admin).send({ role: 'creator' });
  assert.equal(res.status, 200);
  // The old token still names the viewer role; the database decides.
  assert.equal((await env.req('get', '/api/creator/films', token)).status, 200);
});

test('an admin cannot change their own role', async () => {
  const admin = await env.login('admin');
  const res = await env.req('put', '/api/admin/users/1/role', admin).send({ role: 'viewer' });
  assert.equal(res.status, 409);
});

test('the profile can be updated', async () => {
  const { token } = await env.register('profile_user');
  const res = await env
    .req('put', '/api/auth/me', token)
    .send({ display_name: 'Pro File', bio: 'hello' });
  assert.equal(res.status, 200);
  assert.equal(res.body.user.display_name, 'Pro File');
  assert.equal(res.body.user.bio, 'hello');
});
