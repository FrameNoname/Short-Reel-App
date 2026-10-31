const test = require('node:test');
const assert = require('node:assert/strict');
const { createTestEnv } = require('./db');

let env;
test.before(async () => {
  env = await createTestEnv('social');
});
test.after(() => env.close());

test('like and unlike keep the count right and never double count', async () => {
  const { token } = await env.register('liker');
  const first = await env.req('post', '/api/films/2/like', token);
  const again = await env.req('post', '/api/films/2/like', token);
  assert.equal(first.body.like_count, again.body.like_count);
  const undone = await env.req('delete', '/api/films/2/like', token);
  assert.equal(undone.body.like_count, first.body.like_count - 1);
});

test('save to the watchlist and read it back', async () => {
  const { token } = await env.register('saver');
  assert.equal((await env.req('post', '/api/films/3/watchlist', token)).status, 200);
  assert.deepEqual((await env.req('get', '/api/watchlist', token)).body.film_ids, [3]);
  await env.req('delete', '/api/films/3/watchlist', token);
  assert.deepEqual((await env.req('get', '/api/watchlist', token)).body.film_ids, []);
});

test('comments can be added by a viewer and removed only by their author or an admin', async () => {
  const author = await env.register('commenter');
  const other = await env.register('bystander');
  const added = await env.req('post', '/api/films/1/comments', author.token).send({ body: ' Nice ' });
  assert.equal(added.status, 201);
  const list = (await env.req('get', '/api/films/1/comments')).body.comments;
  assert.equal(list[0].body, 'Nice');
  assert.equal(list[0].username, 'commenter');
  assert.equal((await env.req('delete', `/api/comments/${added.body.id}`, other.token)).status, 403);
  assert.equal((await env.req('delete', `/api/comments/${added.body.id}`, author.token)).status, 204);
  assert.equal((await env.req('post', '/api/films/1/comments', author.token).send({ body: '  ' })).status, 400);
});

test('a hidden film cannot be liked, commented on or reported', async () => {
  const { token } = await env.register('snoop');
  for (const [method, url, body] of [
    ['post', '/api/films/4/like'],
    ['post', '/api/films/4/comments', { body: 'hi' }],
    ['post', '/api/films/4/reports', { reason: 'x' }],
    ['post', '/api/films/4/watchlist'],
  ]) {
    const res = await env.req(method, url, token).send(body);
    assert.equal(res.status, 404, url);
  }
  assert.equal((await env.req('get', '/api/films/4/comments')).status, 404);
});

test('follow a creator, but not yourself or a viewer', async () => {
  const { token, user } = await env.register('fan');
  assert.equal((await env.req('post', '/api/creators/2/follow', token)).status, 200);
  const films = (await env.req('get', '/api/films', token)).body.films;
  assert.equal(films.find((f) => f.creator_id === 2).following_creator, true);
  assert.equal((await env.req('post', `/api/creators/${user.id}/follow`, token)).status, 400);
  assert.equal((await env.req('post', '/api/creators/6/follow', token)).status, 404);
  assert.equal((await env.req('delete', '/api/creators/2/follow', token)).status, 200);
});

test('a report reaches the admin, who can resolve it', async () => {
  const { token } = await env.register('reporter');
  const sent = await env.req('post', '/api/films/2/reports', token).send({ reason: 'Wrong AI label' });
  assert.equal(sent.status, 201);
  const admin = await env.login('admin');
  const open = (await env.req('get', '/api/admin/reports', admin)).body.reports.find((r) => r.id === sent.body.id);
  assert.equal(open.status, 'open');
  assert.equal((await env.req('post', `/api/admin/reports/${sent.body.id}/resolve`, admin)).status, 200);
  const after = (await env.req('get', '/api/admin/reports', admin)).body.reports.find((r) => r.id === sent.body.id);
  assert.equal(after.status, 'resolved');
});
