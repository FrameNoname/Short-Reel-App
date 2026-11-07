const test = require('node:test');
const assert = require('node:assert/strict');
const wallet = require('../src/models/wallet');
const controller = require('../src/controllers/wallet');
const { fakePool, fakeReq, fakeRes } = require('./helpers/fakes');

const viewer = { id: 2, role: 'viewer' };
const paidEpisode = { id: 9, is_free: 0, price_coins: 20, status: 'approved' };

// The SQL an unlock runs, answered for one episode and one balance.
function unlockPool({ balance = 50, episode, alreadyUnlocked = false, debitOk = true } = {}) {
  return fakePool([
    ['FROM users WHERE id = ? FOR UPDATE', [{ coin_balance: balance }]],
    ['FROM episodes e JOIN films f', episode ? [episode] : []],
    ['SELECT id FROM unlocked_episodes', alreadyUnlocked ? [{ id: 1 }] : []],
    ['UPDATE users SET coin_balance = coin_balance - ?', { affectedRows: debitOk ? 1 : 0 }],
    ['INSERT INTO unlocked_episodes', { insertId: 1 }],
    ['INSERT INTO coin_transactions', { insertId: 1 }],
  ]);
}

test('unlock charges the price once and writes the unlock and ledger rows', async () => {
  const pool = unlockPool({ episode: paidEpisode });
  const result = await wallet.unlock(pool, viewer, 9);
  assert.deepEqual(result, { access: 'unlocked', charged: 20, already_unlocked: false, balance: 30 });
  assert.deepEqual(pool.callsMatching('INSERT INTO coin_transactions')[0].params, [2, -20, 30, 9]);
  assert.equal(pool.tx.committed, 1);
  assert.equal(pool.tx.released, 1);
});

test('unlocking again does not charge', async () => {
  const pool = unlockPool({ episode: paidEpisode, alreadyUnlocked: true });
  const result = await wallet.unlock(pool, viewer, 9);
  assert.equal(result.charged, 0);
  assert.equal(result.already_unlocked, true);
  assert.equal(pool.callsMatching('UPDATE users').length, 0);
});

test('free episodes and the admin never pay', async () => {
  const free = await wallet.unlock(unlockPool({ episode: { ...paidEpisode, is_free: 1 } }), viewer, 9);
  assert.equal(free.access, 'free');

  const pool = unlockPool({ episode: paidEpisode });
  const owner = await wallet.unlock(pool, { id: 1, role: 'admin' }, 9);
  assert.equal(owner.access, 'owner');
  assert.equal(pool.callsMatching('UPDATE users').length, 0);
});

test('unlock fails with 402 and rolls back when coins run short', async () => {
  const pool = unlockPool({ balance: 5, episode: paidEpisode, debitOk: false });
  await assert.rejects(wallet.unlock(pool, viewer, 9), (err) => err.status === 402);
  assert.equal(pool.tx.rolledBack, 1);
  assert.equal(pool.tx.committed, 0);
  assert.equal(pool.callsMatching('INSERT').length, 0);
});

test('a missing or taken-down episode is a 404 for viewers', async () => {
  await assert.rejects(wallet.unlock(unlockPool({}), viewer, 9), (err) => err.status === 404);
  const down = { ...paidEpisode, status: 'taken_down' };
  await assert.rejects(wallet.unlock(unlockPool({ episode: down }), viewer, 9), (err) => err.status === 404);
});

test('topUp adds the coins of the chosen pack at its price', async () => {
  const pool = fakePool([
    ['FROM coin_packs', [{ coins: 330, price_usd: '4.99' }]],
    ['FOR UPDATE', [{ coin_balance: 10 }]],
    ['UPDATE users', { affectedRows: 1 }],
    ['INSERT INTO coin_transactions', { insertId: 77 }],
  ]);
  const result = await wallet.topUp(pool, 2, { packId: 2 });
  assert.deepEqual(result, { transaction_id: 77, coins_added: 330, price_usd: 4.99, balance: 340 });
});

test('the demo top-up uses the demo_topup_coins setting and costs nothing', async () => {
  const pool = fakePool([
    ['FROM settings', [{ value: '100' }]],
    ['FOR UPDATE', [{ coin_balance: 0 }]],
    ['UPDATE users', { affectedRows: 1 }],
    ['INSERT INTO coin_transactions', { insertId: 1 }],
  ]);
  const result = await wallet.topUp(pool, 2, {});
  assert.equal(result.coins_added, 100);
  assert.equal(result.price_usd, 0);
});

test('topUp with an unknown pack is a 404', async () => {
  const pool = fakePool([['FROM coin_packs', []]]);
  await assert.rejects(wallet.topUp(pool, 2, { packId: 99 }), (err) => err.status === 404);
  assert.equal(pool.tx.rolledBack, 1);
});

test('the topup controller needs exactly one of pack_id and demo', async () => {
  for (const body of [{}, { pack_id: 1, demo: true }, { demo: false }]) {
    await assert.rejects(
      controller.topup(fakeReq({ pool: fakePool(), user: viewer, body }), fakeRes()),
      (err) => err.status === 400,
      JSON.stringify(body),
    );
  }
});

test('listTransactions pages with one extra row to tell if more exist', async () => {
  const rows = [{ id: 3 }, { id: 2 }, { id: 1 }];
  const pool = fakePool([['FROM coin_transactions', (params) => rows.slice(0, params[1])]]);
  const res = fakeRes();
  await controller.listTransactions(fakeReq({ pool, user: viewer, query: { limit: '2' } }), res);
  assert.equal(res.body.transactions.length, 2);
  assert.equal(res.body.has_more, true);

  await assert.rejects(
    controller.listTransactions(fakeReq({ pool, user: viewer, query: { limit: '500' } }), fakeRes()),
    (err) => err.status === 400,
  );
});

test('typicalEpisodePrice is the most common price of our own paid episodes', async () => {
  const pool = fakePool([['GROUP BY e.price_coins', [{ price_coins: 20 }]]]);
  assert.equal(await wallet.typicalEpisodePrice(pool), 20);
});

test('typicalEpisodePrice falls back to the catalog price with nothing for sale', async () => {
  const pool = fakePool([
    ['GROUP BY e.price_coins', []],
    [/FROM settings/, (params) => (params[0] === 'catalog_price_coins' ? [{ value: '12' }] : [])],
  ]);
  assert.equal(await wallet.typicalEpisodePrice(pool), 12);
});
