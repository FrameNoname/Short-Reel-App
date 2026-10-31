const test = require('node:test');
const assert = require('node:assert/strict');
const { createTestEnv } = require('./db');

let env;
test.before(async () => {
  env = await createTestEnv('revenue');
});
test.after(() => env.close());

const PAID = (film, n) => (film - 1) * 8 + n;
const unlock = (token, id) => env.req('post', `/api/episodes/${id}/unlock`, token);
const setShare = async (percent) =>
  env.req('put', '/api/admin/settings/revenue-share', await env.login('admin')).send({ admin_share_percent: percent });

async function buyer(name, coins = 1000) {
  const { token, user } = await env.register(name);
  await env.pool.query('UPDATE users SET coin_balance = ? WHERE id = ?', [coins, user.id]);
  return token;
}

const lastShares = async () =>
  (await env.pool.query('SELECT coins_spent, creator_share, admin_share FROM unlocked_episodes ORDER BY id DESC LIMIT 1'))[0][0];

test('only an admin can set the share, and only within 0-100', async () => {
  const viewer = await env.login('viewer01');
  const creator = await env.login('kestrel_studio');
  for (const token of [viewer, creator]) {
    assert.equal((await env.req('put', '/api/admin/settings/revenue-share', token).send({ admin_share_percent: 50 })).status, 403);
  }
  for (const bad of [-1, 101, 30.5, 'abc', undefined]) {
    assert.equal((await setShare(bad)).status, 400, String(bad));
  }
  assert.equal((await setShare(30)).status, 200);
});

test('a creator film splits the coins by the admin setting', async () => {
  await unlock(await buyer('split_a'), PAID(1, 3));
  assert.deepEqual(await lastShares(), { coins_spent: 20, creator_share: 14, admin_share: 6 });
});

test('an admin film pays everything to the admin', async () => {
  await unlock(await buyer('split_b'), PAID(5, 3));
  assert.deepEqual(await lastShares(), { coins_spent: 20, creator_share: 0, admin_share: 20 });
});

test('rounding always adds up to the coins spent', async () => {
  await setShare(33);
  for (const price of [1, 7, 19, 20, 99, 101]) {
    await env.pool.query('UPDATE episodes SET price_coins = ?, is_free = 0 WHERE id = ?', [price, PAID(1, 8)]);
    await unlock(await buyer(`rounder_${price}`), PAID(1, 8));
    const s = await lastShares();
    assert.equal(s.coins_spent, price);
    assert.equal(s.creator_share + s.admin_share, price, `price ${price}`);
    assert.equal(s.creator_share, Math.floor((price * 67) / 100));
  }
  await setShare(30);
});

test('changing the percentage never rewrites past unlocks', async () => {
  const token = await buyer('history_a');
  await setShare(30);
  await unlock(token, PAID(2, 3));
  const [[old]] = await env.pool.query('SELECT id, creator_share, admin_share FROM unlocked_episodes ORDER BY id DESC LIMIT 1');
  await setShare(10);
  await unlock(token, PAID(2, 4));
  const fresh = await lastShares();
  assert.deepEqual(fresh, { coins_spent: 20, creator_share: 18, admin_share: 2 });
  const [[same]] = await env.pool.query('SELECT creator_share, admin_share FROM unlocked_episodes WHERE id = ?', [old.id]);
  assert.deepEqual(same, { creator_share: old.creator_share, admin_share: old.admin_share });
  await setShare(30);
});

test('a creator\'s dashboard shows exactly their share, from the database', async () => {
  const creator = await env.login('kestrel_studio');
  const [[expected]] = await env.pool.query(
    `SELECT COALESCE(SUM(ue.creator_share),0) coins, COUNT(*) n FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id JOIN films f ON f.id = e.film_id WHERE f.creator_id = 2`);
  const res = await env.req('get', '/api/creator/earnings', creator);
  assert.equal(res.status, 200);
  assert.equal(res.body.unit, 'coins');
  assert.equal(res.body.coins_earned, Number(expected.coins));
  assert.equal(res.body.unlock_count, expected.n);
  assert.ok(res.body.coins_earned > 0);
  assert.equal(res.body.films.reduce((a, f) => a + f.coins_earned, 0), res.body.coins_earned);
  assert.ok(res.body.recent_unlocks.length > 0);
  // Another creator sees none of it.
  const other = await env.req('get', '/api/creator/earnings', await env.login('tidewater_ai'));
  assert.equal(other.body.coins_earned, 0);
});

test('an admin\'s own films earn the whole price', async () => {
  const admin = await env.login('admin');
  const res = await env.req('get', '/api/creator/earnings', admin);
  const film5 = res.body.films.find((f) => f.film_id === 5);
  assert.equal(film5.coins_earned, film5.coins_spent);
  assert.ok(film5.coins_earned >= 40);
});

test('admin sales trace every coin and keep coins and dollars apart', async () => {
  const admin = await env.login('admin');
  const res = await env.req('get', '/api/admin/sales', admin);
  assert.equal(res.status, 200);
  const { coins, simulated_payments: usd } = res.body;
  assert.equal(coins.unit, 'coins');
  assert.equal(coins.creator_share + coins.admin_share, coins.coins_spent);
  const [[ledger]] = await env.pool.query("SELECT -SUM(amount) s FROM coin_transactions WHERE type = 'unlock'");
  assert.equal(coins.coins_spent, Number(ledger.s), 'unlock ledger matches the unlock records');
  assert.equal(res.body.per_film.reduce((a, f) => a + f.coins_spent, 0), coins.coins_spent);
  assert.equal(res.body.per_film.reduce((a, f) => a + f.admin_share, 0), coins.admin_share);
  assert.match(usd.unit, /simulated/);
  assert.equal(typeof usd.coin_topups.simulated_usd, 'number');
  assert.equal(res.body.admin_share_percent, 30);
  assert.ok(res.body.recent_unlocks[0].buyer);
  assert.equal(res.body.total, undefined, 'no figure mixes coins and dollars');
});

test('the earnings response tells a creator the current admin cut', async () => {
  const res = await env.req('get', '/api/creator/earnings', await env.login('kestrel_studio'));
  assert.equal(res.body.admin_share_percent, 30);
});
