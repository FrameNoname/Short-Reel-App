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
