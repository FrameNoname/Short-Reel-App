const test = require('node:test');
const assert = require('node:assert/strict');
const { createTestEnv } = require('./db');

let env;
test.before(async () => {
  env = await createTestEnv('wallet');
});
test.after(() => env.close());

// Seed: episode id = (film - 1) * 8 + number. Eps 1-2 free, 3-8 cost 20 coins.
const PAID = (film, n) => (film - 1) * 8 + n;

const balance = async (token) => (await env.req('get', '/api/wallet', token)).body.coin_balance;
const unlock = (token, id) => env.req('post', `/api/episodes/${id}/unlock`, token);
const dbCount = async (sql, params) => (await env.pool.query(sql, params))[0][0].n;

async function viewerWithCoins(name, coins) {
  const { token, user } = await env.register(name);
  if (coins > 0) await env.pool.query('UPDATE users SET coin_balance = ? WHERE id = ?', [coins, user.id]);
  return { token, id: user.id };
}

test('the wallet and coin packs are labelled as simulated', async () => {
  const { token } = await env.register('wallet_label');
  const wallet = await env.req('get', '/api/wallet', token);
  assert.equal(wallet.body.simulated_payment, true);
  assert.equal(wallet.body.demo_topup_coins, 100);
  const packs = await env.req('get', '/api/coin-packs');
  assert.equal(packs.body.simulated_payment, true);
  assert.deepEqual(packs.body.coin_packs.map((p) => p.coins), [60, 330, 750]);
});

test('the demo button adds 100 coins and the history shows it', async () => {
  const { token } = await env.register('demo_topper');
  const res = await env.req('post', '/api/wallet/topup', token).send({ demo: true });
  assert.equal(res.status, 201);
  assert.equal(res.body.coins_added, 100);
  assert.equal(res.body.balance, 100);
  assert.equal(res.body.simulated_payment, true);
  const history = (await env.req('get', '/api/wallet/transactions', token)).body.transactions;
  assert.equal(history.length, 1);
  assert.equal(history[0].type, 'topup');
  assert.equal(history[0].amount, 100);
  assert.equal(history[0].balance_after, 100);
});

test('a coin pack credits what the server says it is worth', async () => {
  const { token } = await env.register('pack_buyer');
  const res = await env.req('post', '/api/wallet/topup', token).send({ pack_id: 2 });
  assert.equal(res.body.coins_added, 330);
  assert.equal(res.body.price_usd, 4.99);
  const row = (await env.req('get', '/api/wallet/transactions', token)).body.transactions[0];
  assert.equal(row.price_usd, 4.99);
  assert.equal(row.pack_name, 'Popular');
});

test('the client cannot choose the number of coins', async () => {
  const { token } = await env.register('greedy');
  for (const body of [{ coins: 99999 }, { demo: true, pack_id: 1 }, {}, { pack_id: 'x' }, { demo: 'maybe' }]) {
    assert.equal((await env.req('post', '/api/wallet/topup', token).send(body)).status, 400, JSON.stringify(body));
  }
  assert.equal((await env.req('post', '/api/wallet/topup', token).send({ pack_id: 99 })).status, 404);
  assert.equal(await balance(token), 0);
});

test('top-up -> history -> unlock -> balance add up', async () => {
  const { token } = await env.register('flow_viewer');
  await env.req('post', '/api/wallet/topup', token).send({ demo: true });
  const res = await unlock(token, PAID(1, 5));
  assert.equal(res.status, 200);
  assert.deepEqual(
    { access: res.body.access, charged: res.body.charged, balance: res.body.balance },
    { access: 'unlocked', charged: 20, balance: 80 },
  );
  assert.equal(await balance(token), 80);
  const history = (await env.req('get', '/api/wallet/transactions', token)).body.transactions;
  assert.deepEqual(history.map((t) => [t.type, t.amount, t.balance_after]), [
    ['unlock', -20, 80],
    ['topup', 100, 100],
  ]);
  assert.equal(history[0].film_title, 'Salt & Signal');
  assert.equal(history[0].episode_no, 5);
  const detail = await env.req('get', `/api/episodes/${PAID(1, 5)}`, token);
  assert.equal(detail.body.episode.access, 'unlocked');
});

test('unlocking again charges nothing and adds no second record', async () => {
  const { token, id } = await viewerWithCoins('repeat_viewer', 100);
  await unlock(token, PAID(2, 3));
  const again = await unlock(token, PAID(2, 3));
  assert.equal(again.status, 200);
  assert.equal(again.body.charged, 0);
  assert.equal(again.body.already_unlocked, true);
  assert.equal(await balance(token), 80);
  assert.equal(await dbCount('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [id]), 1);
  assert.equal(await dbCount("SELECT COUNT(*) n FROM coin_transactions WHERE user_id = ? AND type = 'unlock'", [id]), 1);
});

test('not enough coins is a 402 and changes nothing', async () => {
  const { token, id } = await viewerWithCoins('broke_viewer', 19);
  const res = await unlock(token, PAID(1, 6));
  assert.equal(res.status, 402);
  assert.equal(res.body.error.code, 'INSUFFICIENT_COINS');
  assert.equal(await balance(token), 19);
  assert.equal(await dbCount('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [id]), 0);
  assert.equal(await dbCount('SELECT COUNT(*) n FROM coin_transactions WHERE user_id = ?', [id]), 0);
  assert.equal((await env.req('get', `/api/episodes/${PAID(1, 6)}`, token)).body.stream_url, null);
});

test('five parallel unlocks of one episode charge exactly once', async () => {
  const { token, id } = await viewerWithCoins('parallel_same', 100);
  const results = await Promise.all(Array.from({ length: 5 }, () => unlock(token, PAID(3, 7))));
  assert.ok(results.every((r) => r.status === 200), results.map((r) => r.status).join());
  assert.equal(results.filter((r) => r.body.charged === 20).length, 1);
  assert.equal(await balance(token), 80);
  assert.equal(await dbCount('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [id]), 1);
  assert.equal(await dbCount("SELECT COUNT(*) n FROM coin_transactions WHERE user_id = ? AND type = 'unlock'", [id]), 1);
});

test('parallel unlocks of different episodes can never overspend', async () => {
  const { token, id } = await viewerWithCoins('parallel_many', 45);
  const results = await Promise.all([3, 4, 5, 6, 7].map((n) => unlock(token, PAID(1, n))));
  const ok = results.filter((r) => r.status === 200);
  const refused = results.filter((r) => r.status === 402);
  assert.equal(ok.length, 2);
  assert.equal(refused.length, 3);
  assert.equal(await balance(token), 5);
  assert.equal(await dbCount('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [id]), 2);
  const [[sum]] = await env.pool.query(
    "SELECT SUM(amount) s FROM coin_transactions WHERE user_id = ? AND type = 'unlock'", [id]);
  assert.equal(Number(sum.s), -40);
});

test('free episodes and the owner\'s own episodes cost nothing', async () => {
  const { token } = await viewerWithCoins('free_viewer', 50);
  const free = await unlock(token, PAID(1, 1));
  assert.equal(free.body.access, 'free');
  assert.equal(free.body.charged, 0);
  const owner = await env.login('kestrel_studio');
  const own = await unlock(owner, PAID(1, 4));
  assert.equal(own.body.access, 'owner');
  assert.equal(own.body.charged, 0);
  assert.equal(await balance(token), 50);
});

test('a hidden film cannot be unlocked and guests cannot unlock', async () => {
  const { token } = await viewerWithCoins('hidden_viewer', 100);
  assert.equal((await unlock(token, PAID(4, 3))).status, 404); // film 4 is pending
  assert.equal((await env.req('post', `/api/episodes/${PAID(1, 3)}/unlock`)).status, 401);
  assert.equal(await balance(token), 100);
});

test('purchases and balance are still there after logging in again', async () => {
  const { id } = await viewerWithCoins('returning_viewer', 100);
  const first = (await env.req('post', '/api/auth/login').send({ username: 'returning_viewer', password: 'secret123' })).body.token;
  await unlock(first, PAID(1, 8));
  const second = (await env.req('post', '/api/auth/login').send({ username: 'returning_viewer', password: 'secret123' })).body.token;
  assert.equal(await balance(second), 80);
  assert.equal((await env.req('get', `/api/episodes/${PAID(1, 8)}`, second)).body.episode.access, 'unlocked');
  assert.equal(id > 0, true);
});

test('a subscription unlocks every episode without coins, and expires', async () => {
  const { token, id } = await viewerWithCoins('subscriber', 30);
  const before = await env.req('get', '/api/subscription', token);
  assert.equal(before.body.active, false);

  const sub = await env.req('post', '/api/subscription', token);
  assert.equal(sub.status, 201);
  assert.equal(sub.body.active, true);
  assert.equal(sub.body.simulated_payment, true);
  assert.ok(sub.body.subscription.end_date > sub.body.subscription.start_date);

  const detail = await env.req('get', `/api/episodes/${PAID(2, 6)}`, token);
  assert.equal(detail.body.episode.access, 'subscription');
  assert.ok(detail.body.stream_url);
  const viaUnlock = await unlock(token, PAID(2, 6));
  assert.equal(viaUnlock.body.charged, 0);
  assert.equal(await balance(token), 30);
  assert.equal(await dbCount('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [id]), 0);

  // Buy one episode with coins first, then let the plan run out.
  await env.pool.query('UPDATE subscriptions SET start_date = CURDATE() - INTERVAL 40 DAY, end_date = CURDATE() - INTERVAL 1 DAY WHERE user_id = ?', [id]);
  const expired = await env.req('get', '/api/subscription', token);
  assert.equal(expired.body.active, false);
  assert.equal((await env.req('get', `/api/episodes/${PAID(2, 6)}`, token)).body.episode.access, 'locked');
  assert.equal((await env.req('get', `/api/episodes/${PAID(2, 6)}/stream`, token)).status, 403);
  const bought = await unlock(token, PAID(2, 6));
  assert.equal(bought.body.charged, 20);
});

test('an episode bought before a plan expired stays watchable after', async () => {
  const { token, id } = await viewerWithCoins('lapsed', 100);
  await unlock(token, PAID(3, 4));
  await env.req('post', '/api/subscription', token);
  await env.pool.query('UPDATE subscriptions SET start_date = CURDATE() - INTERVAL 40 DAY, end_date = CURDATE() - INTERVAL 1 DAY WHERE user_id = ?', [id]);
  assert.equal((await env.req('get', `/api/episodes/${PAID(3, 4)}`, token)).body.episode.access, 'unlocked');
  assert.equal((await env.req('get', `/api/episodes/${PAID(3, 5)}`, token)).body.episode.access, 'locked');
});

test('subscribing again extends the plan, and cancelling keeps it until the end date', async () => {
  const { token } = await viewerWithCoins('renewer', 0);
  const first = (await env.req('post', '/api/subscription', token)).body;
  await env.req('post', '/api/subscription', token);
  const rows = (await env.pool.query('SELECT start_date, end_date FROM subscriptions ORDER BY id DESC LIMIT 2'))[0];
  assert.equal(rows[0].start_date > first.subscription.start_date, true, 'second plan starts after the first');
  const cancelled = await env.req('delete', '/api/subscription', token);
  assert.equal(cancelled.status, 200);
  assert.equal(cancelled.body.active, true);
  assert.equal(cancelled.body.subscription.is_cancelled, true);
  assert.equal((await env.req('get', `/api/episodes/${PAID(2, 4)}`, token)).body.episode.access, 'subscription');
  const none = await viewerWithCoins('no_plan', 0);
  assert.equal((await env.req('delete', '/api/subscription', none.token)).status, 404);
});
