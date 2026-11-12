const test = require('node:test');
const assert = require('node:assert/strict');
const catalog = require('../src/models/catalog');
const social = require('../src/models/social');
const { fakePool } = require('./helpers/fakes');

const viewer = { id: 2, role: 'viewer' };

function catalogPool({ free = '5', price = '10', unlocked = [] } = {}) {
  return fakePool([
    [/FROM settings/, (params) => (params[0] === 'catalog_free_episodes' ? [{ value: free }] : [{ value: price }])],
    ['FROM unlocked_episodes', unlocked.map((n) => ({ episode_no: n }))],
  ]);
}

test('pricing reads the catalog settings as numbers', async () => {
  assert.deepEqual(await catalog.pricing(catalogPool({ free: '3', price: '15' })), {
    free_episodes: 3,
    price_coins: 15,
  });
});

test('pricing falls back to 5 free episodes and 10 coins', async () => {
  const pool = fakePool([['FROM settings', []]]);
  assert.deepEqual(await catalog.pricing(pool), { free_episodes: 5, price_coins: 10 });
});

test('lockedIn: the first episodes are free, later ones need an unlock', async () => {
  assert.deepEqual(await catalog.lockedIn(catalogPool(), viewer, 77, 1, 8), [6, 7, 8]);
  assert.deepEqual(await catalog.lockedIn(catalogPool(), viewer, 77, 1, 5), []);
});

test('lockedIn skips the episodes the viewer already bought', async () => {
  const pool = catalogPool({ unlocked: [6, 8] });
  assert.deepEqual(await catalog.lockedIn(pool, viewer, 77, 1, 9), [7, 9]);
});

test('lockedIn: guests see every paid episode as locked, the admin none', async () => {
  assert.deepEqual(await catalog.lockedIn(catalogPool(), null, 77, 4, 7), [6, 7]);
  const pool = catalogPool();
  assert.deepEqual(await catalog.lockedIn(pool, { id: 1, role: 'admin' }, 77, 1, 50), []);
  assert.equal(pool.calls.length, 0);
});

test('removeComment: the author and the admin may delete, others may not', async () => {
  const pool = () =>
    fakePool([
      ['SELECT user_id FROM comments', [{ user_id: 2 }]],
      ['DELETE FROM comments', { affectedRows: 1 }],
    ]);
  const own = pool();
  await social.removeComment(own, viewer, 10);
  assert.equal(own.callsMatching('DELETE').length, 1);

  const byAdmin = pool();
  await social.removeComment(byAdmin, { id: 1, role: 'admin' }, 10);
  assert.equal(byAdmin.callsMatching('DELETE').length, 1);

  const other = pool();
  await assert.rejects(social.removeComment(other, { id: 3, role: 'viewer' }, 10), (e) => e.status === 403);
  assert.equal(other.callsMatching('DELETE').length, 0);
});

test('removeComment on a missing comment is a 404', async () => {
  const pool = fakePool([['SELECT user_id FROM comments', []]]);
  await assert.rejects(social.removeComment(pool, viewer, 10), (e) => e.status === 404);
});

test('flags tells which films the viewer liked and saved', async () => {
  const pool = fakePool([
    ['FROM likes', [{ film_id: 1 }]],
    ['FROM watchlist', [{ film_id: 2 }]],
  ]);
  const flags = await social.flags(pool, 2, [{ id: 1 }, { id: 2 }]);
  assert.deepEqual([...flags.liked], [1]);
  assert.deepEqual([...flags.saved], [2]);
  const none = await social.flags(fakePool(), 2, []);
  assert.equal(none.liked.size, 0);
});

// ---- social controller ----

const controller = require('../src/controllers/social');
const { fakeReq, fakeRes } = require('./helpers/fakes');

const film = (status = 'approved') => ({ id: 4, title: 'A', status });

function socialPool({ status = 'approved', likes = 3 } = {}) {
  return fakePool([
    ['WHERE f.id = ?', status ? [film(status)] : []],
    [/^(INSERT IGNORE INTO|DELETE FROM) (likes|watchlist)/, { affectedRows: 1 }],
    ['SELECT COUNT(*) AS n FROM likes', [{ n: likes }]],
    ['INSERT INTO comments', { insertId: 55 }],
    ['FROM watchlist w JOIN films f', [{ film_id: 4 }, { film_id: 9 }]],
  ]);
}

async function call(handler, req) {
  const res = fakeRes();
  await handler(req, res);
  return res;
}

test('like and unlike write the row and return the new count', async () => {
  const pool = socialPool({ likes: 8 });
  const liked = await call(controller.like, fakeReq({ pool, user: viewer, params: { id: '4' } }));
  assert.deepEqual(liked.body, { liked: true, like_count: 8 });
  assert.deepEqual(pool.callsMatching('INSERT IGNORE INTO likes')[0].params, [2, 4]);

  const unliked = await call(controller.unlike, fakeReq({ pool, user: viewer, params: { id: '4' } }));
  assert.equal(unliked.body.liked, false);
  assert.deepEqual(pool.callsMatching('DELETE FROM likes')[0].params, [2, 4]);
});

test('a viewer cannot like, save or comment on a taken-down or missing film', async () => {
  for (const status of ['taken_down', null]) {
    const pool = socialPool({ status });
    for (const handler of [controller.like, controller.addToWatchlist, controller.listComments]) {
      await assert.rejects(
        call(handler, fakeReq({ pool, user: viewer, params: { id: '4' }, body: { body: 'hi' } })),
        (e) => e.status === 404,
      );
    }
    assert.equal(pool.callsMatching(/^(INSERT|DELETE)/).length, 0);
  }
});

test('the admin may still act on a taken-down film', async () => {
  const pool = socialPool({ status: 'taken_down' });
  const res = await call(controller.like, fakeReq({ pool, user: { id: 1, role: 'admin' }, params: { id: '4' } }));
  assert.equal(res.body.liked, true);
});

test('watchlist add, remove and list', async () => {
  const pool = socialPool();
  const added = await call(controller.addToWatchlist, fakeReq({ pool, user: viewer, params: { id: '4' } }));
  assert.deepEqual(added.body, { saved: true });
  const removed = await call(controller.removeFromWatchlist, fakeReq({ pool, user: viewer, params: { id: '4' } }));
  assert.deepEqual(removed.body, { saved: false });
  assert.deepEqual(pool.callsMatching('DELETE FROM watchlist')[0].params, [2, 4]);
  const list = await call(controller.listWatchlist, fakeReq({ pool, user: viewer }));
  assert.deepEqual(list.body, { film_ids: [4, 9] });
});

test('removeFromWatchlist works even when the film was taken down', async () => {
  const pool = socialPool({ status: 'taken_down' });
  const res = await call(controller.removeFromWatchlist, fakeReq({ pool, user: viewer, params: { id: '4' } }));
  assert.deepEqual(res.body, { saved: false });
});

test('addComment trims the body, stores it and answers 201 with the id', async () => {
  const pool = socialPool();
  const res = await call(controller.addComment, fakeReq({ pool, user: viewer, params: { id: '4' }, body: { body: '  สนุกมาก  ' } }));
  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.body, { id: 55 });
  assert.deepEqual(pool.callsMatching('INSERT INTO comments')[0].params, [2, 4, 'สนุกมาก']);
});

test('addComment refuses an empty or too long body', async () => {
  for (const body of [{}, { body: '   ' }, { body: 'x'.repeat(501) }]) {
    const pool = socialPool();
    await assert.rejects(
      call(controller.addComment, fakeReq({ pool, user: viewer, params: { id: '4' }, body })),
      (e) => e.status === 400,
    );
    assert.equal(pool.callsMatching('INSERT').length, 0);
  }
});
