const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('../src/models/admin');
const controller = require('../src/controllers/admin');
const { fakePool, fakeReq, fakeRes } = require('./helpers/fakes');

const adminUser = { id: 1, role: 'admin' };
const isStatus = (status) => (err) => err.status === status;

// ---- model ----

test('sales keeps coins and simulated dollars apart and as numbers', async () => {
  const pool = fakePool([
    [/FROM unlocked_episodes\s*$/, [{ unlock_count: '4', coins_spent: '80' }]],
    ["type = 'topup'", [{ count: '2', simulated_usd: '5.98', coins_issued: '660' }]],
    ['GROUP BY f.id', [{ film_id: 1, title: 'A', unlock_count: '2', coins_spent: '40' }]],
    ['ORDER BY ue.id DESC LIMIT 20', []],
  ]);
  const sales = await admin.sales(pool);
  assert.deepEqual(sales.coins, { unit: 'coins', unlock_count: 4, coins_spent: 80 });
  assert.equal(sales.simulated_payments.coin_topups.simulated_usd, 5.98);
  assert.deepEqual(sales.per_film[0], { film_id: 1, title: 'A', unlock_count: 2, coins_spent: 40 });
});

test('setFilmStatus only touches the app own films', async () => {
  const pool = fakePool([
    ['catalog_drama_id IS NULL', (params) => (params[0] === 1 ? [{ id: 1 }] : [])],
    ['UPDATE films SET status', { affectedRows: 1 }],
  ]);
  await admin.setFilmStatus(pool, 1, 'taken_down');
  assert.deepEqual(pool.callsMatching('UPDATE films')[0].params, ['taken_down', 1]);
  await assert.rejects(admin.setFilmStatus(pool, 99, 'approved'), isStatus(404));
});

test('updateEpisode makes a free episode cost 0', async () => {
  const pool = fakePool([
    ['FROM episodes e', [{ id: 3, is_free: 0, price_coins: 20 }]],
    ['UPDATE episodes', { affectedRows: 1 }],
  ]);
  const saved = await admin.updateEpisode(pool, 3, { isFree: true });
  assert.deepEqual(saved, { id: 3, is_free: true, price_coins: 0 });
  assert.deepEqual(pool.callsMatching('UPDATE episodes')[0].params, [1, 0, 3]);
});

test('updateEpisode keeps the old price when only the flag changes', async () => {
  const pool = fakePool([
    ['FROM episodes e', [{ id: 3, is_free: 0, price_coins: 20 }]],
    ['UPDATE episodes', { affectedRows: 1 }],
  ]);
  assert.equal((await admin.updateEpisode(pool, 3, { priceCoins: 15 })).price_coins, 15);
  assert.equal((await admin.updateEpisode(pool, 3, { isFree: false })).price_coins, 20);
});

test('updateEpisode refuses a paid episode at 0 coins and unknown episodes', async () => {
  const paidAtZero = fakePool([['FROM episodes e', [{ id: 3, is_free: 1, price_coins: 0 }]]]);
  await assert.rejects(admin.updateEpisode(paidAtZero, 3, { isFree: false }), isStatus(400));
  const none = fakePool([['FROM episodes e', []]]);
  await assert.rejects(admin.updateEpisode(none, 3, { isFree: true }), isStatus(404));
});

test('getSettings returns only the known settings, as numbers', async () => {
  const pool = fakePool([
    ['FROM settings', [
      { name: 'catalog_price_coins', value: '10' },
      { name: 'catalog_free_episodes', value: '5' },
      { name: 'something_else', value: 'x' },
    ]],
  ]);
  assert.deepEqual(await admin.getSettings(pool), { catalog_price_coins: 10, catalog_free_episodes: 5 });
});

test('a coin pack that was bought cannot be deleted', async () => {
  const sold = fakePool([['FROM coin_transactions', [{ n: 3 }]]]);
  await assert.rejects(admin.deleteCoinPack(sold, 1), isStatus(409));
  assert.equal(sold.callsMatching('DELETE').length, 0);

  const unsold = fakePool([
    ['FROM coin_transactions', [{ n: 0 }]],
    ['DELETE FROM coin_packs', { affectedRows: 1 }],
  ]);
  await admin.deleteCoinPack(unsold, 1);
  assert.equal(unsold.callsMatching('DELETE FROM coin_packs').length, 1);

  const missing = fakePool([
    ['FROM coin_transactions', [{ n: 0 }]],
    ['DELETE FROM coin_packs', { affectedRows: 0 }],
  ]);
  await assert.rejects(admin.deleteCoinPack(missing, 1), isStatus(404));
});

// ---- controller ----

test('setFilmStatus accepts only approved and taken_down', async () => {
  const pool = fakePool([
    ['catalog_drama_id IS NULL', [{ id: 1 }]],
    ['UPDATE films', { affectedRows: 1 }],
  ]);
  const res = fakeRes();
  await controller.setFilmStatus(
    fakeReq({ pool, user: adminUser, params: { id: '1' }, body: { status: 'taken_down' } }),
    res,
  );
  assert.deepEqual(res.body, { id: 1, status: 'taken_down' });

  for (const status of [undefined, 'deleted', 'pending']) {
    await assert.rejects(
      controller.setFilmStatus(
        fakeReq({ pool, user: adminUser, params: { id: '1' }, body: { status } }),
        fakeRes(),
      ),
      isStatus(400),
    );
  }
});

test('updateEpisode needs something to change and a valid price', async () => {
  const pool = fakePool();
  const call = (body) =>
    controller.updateEpisode(fakeReq({ pool, user: adminUser, params: { id: '3' }, body }), fakeRes());
  await assert.rejects(call({}), isStatus(400));
  await assert.rejects(call({ price_coins: -5 }), isStatus(400));
  await assert.rejects(call({ is_free: 'maybe' }), isStatus(400));
});

test('saveSettings rejects unknown names and out-of-range values', async () => {
  const pool = fakePool([
    ['INSERT INTO settings', { affectedRows: 1 }],
    ['FROM settings', [{ name: 'catalog_price_coins', value: '12' }]],
  ]);
  const call = (body) => controller.saveSettings(fakeReq({ pool, user: adminUser, body }), fakeRes());
  await assert.rejects(call({}), isStatus(400));
  await assert.rejects(call({ admin_password: 1 }), isStatus(400));
  await assert.rejects(call({ catalog_price_coins: 0 }), isStatus(400));
  await assert.rejects(call({ catalog_free_episodes: -1 }), isStatus(400));
  assert.equal(pool.callsMatching('INSERT INTO settings').length, 0, 'nothing saved on a bad request');

  const res = fakeRes();
  await controller.saveSettings(fakeReq({ pool, user: adminUser, body: { catalog_price_coins: 12 } }), res);
  assert.deepEqual(res.body, { settings: { catalog_price_coins: 12 } });
});

test('coin pack bodies are checked before anything is written', async () => {
  const pool = fakePool([['INSERT INTO coin_packs', { insertId: 4 }]]);
  const call = (body) => controller.createCoinPack(fakeReq({ pool, user: adminUser, body }), fakeRes());
  await assert.rejects(call({ coins: 10, price_usd: 1 }), isStatus(400));
  await assert.rejects(call({ name: 'x', coins: 0, price_usd: 1 }), isStatus(400));
  await assert.rejects(call({ name: 'x', coins: 10, price_usd: 0 }), isStatus(400));
  await assert.rejects(call({ name: 'x', coins: 10, price_usd: 'free' }), isStatus(400));
  assert.equal(pool.calls.length, 0);

  const res = fakeRes();
  await controller.createCoinPack(
    fakeReq({ pool, user: adminUser, body: { name: ' Mega ', coins: 999, price_usd: 12.345 } }),
    res,
  );
  assert.equal(res.statusCode, 201);
  assert.deepEqual(pool.calls[0].params, ['Mega', 999, 12.35]);
});

test('listComments pages and can filter by film', async () => {
  const pool = fakePool([
    ['FROM comments c', (params) => [{ id: 1 }, { id: 2 }, { id: 3 }].slice(0, params.at(-2))],
  ]);
  const res = fakeRes();
  await controller.listComments(
    fakeReq({ pool, user: adminUser, query: { limit: '2', film_id: '5' } }),
    res,
  );
  assert.equal(res.body.comments.length, 2);
  assert.equal(res.body.has_more, true);
  assert.equal(pool.calls[0].params[0], 5);
  assert.match(pool.calls[0].sql, /WHERE c\.film_id = \?/);
});

// ---- content and coin pack lists ----

async function call(handler, req) {
  const res = fakeRes();
  await handler(req, res);
  return res;
}

test('listFilms turns the counts into numbers', async () => {
  const pool = fakePool([['FROM films f', [{
    id: 1, title: 'A', status: 'approved', catalog_drama_id: null,
    episode_count: '8', like_count: '3', comment_count: '2', coins_spent: '40',
  }]]]);
  const res = await call(controller.listFilms, fakeReq({ pool, user: adminUser }));
  const [film] = res.body.films;
  assert.deepEqual(
    [film.episode_count, film.like_count, film.comment_count, film.coins_spent],
    [8, 3, 2, 40],
  );
});

test('listEpisodes lists the episodes of the app own film only', async () => {
  const pool = fakePool([
    ['catalog_drama_id IS NULL', (params) => (params[0] === 1 ? [{ id: 1 }] : [])],
    ['FROM episodes e WHERE e.film_id', [{ id: 3, episode_no: 1, is_free: 1, price_coins: 0, unlock_count: '0' },
      { id: 4, episode_no: 2, is_free: 0, price_coins: 20, unlock_count: '5' }]],
  ]);
  const res = await call(controller.listEpisodes, fakeReq({ pool, user: adminUser, params: { id: '1' } }));
  assert.deepEqual(res.body.episodes.map((e) => [e.is_free, e.unlock_count]), [[true, 0], [false, 5]]);
  await assert.rejects(
    call(controller.listEpisodes, fakeReq({ pool, user: adminUser, params: { id: '99' } })),
    isStatus(404),
  );
});

test('listCoinPacks gives the price and sold count as numbers', async () => {
  const pool = fakePool([['FROM coin_packs p', [{ id: 1, name: 'S', coins: 100, price_usd: '0.99', sold_count: '7' }]]]);
  const res = await call(controller.listCoinPacks, fakeReq({ pool, user: adminUser }));
  assert.deepEqual(res.body.coin_packs, [{ id: 1, name: 'S', coins: 100, price_usd: 0.99, sold_count: 7 }]);
});

test('updateCoinPack saves the checked body and rounds the price to cents', async () => {
  const pool = fakePool([['UPDATE coin_packs', (params) => ({ affectedRows: params[3] === 2 ? 1 : 0 })]]);
  const res = await call(controller.updateCoinPack, fakeReq({
    pool, user: adminUser, params: { id: '2' }, body: { name: ' Big ', coins: 500, price_usd: 4.999 },
  }));
  assert.deepEqual(res.body, { id: 2 });
  assert.deepEqual(pool.calls[0].params, ['Big', 500, 5, 2]);
  await assert.rejects(
    call(controller.updateCoinPack, fakeReq({
      pool, user: adminUser, params: { id: '9' }, body: { name: 'X', coins: 1, price_usd: 1 },
    })),
    isStatus(404),
  );
});

test('updateCoinPack refuses a bad price or coin count before touching the table', async () => {
  const pool = fakePool();
  for (const body of [
    { name: 'X', coins: 10, price_usd: 0 },
    { name: 'X', coins: 10, price_usd: 'free' },
    { name: 'X', coins: 0, price_usd: 1 },
    { coins: 10, price_usd: 1 },
  ]) {
    await assert.rejects(
      call(controller.updateCoinPack, fakeReq({ pool, user: adminUser, params: { id: '2' }, body })),
      isStatus(400),
    );
  }
  assert.equal(pool.calls.length, 0);
});
