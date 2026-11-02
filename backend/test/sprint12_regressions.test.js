// Regressions for the Sprint 1-2 fixes. Checked against the pre-fix source with
// `git stash push -- backend/src`: every test here fails there except 'the
// price limit is 500', which only guards the API side of a bug that lived in the
// Flutter form (the form accepted 999 while the API already refused it).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createTestEnv, makeMp4 } = require('./db');
const episodesModel = require('../src/models/episodes');

let env;
test.before(async () => {
  env = await createTestEnv('sprint12');
});
test.after(() => env.close());

const PAID = (film, n) => (film - 1) * 8 + n;
const one = async (sql, params) => (await env.pool.query(sql, params))[0][0];

async function buyer(name, coins) {
  const { token, user } = await env.register(name);
  await env.pool.query('UPDATE users SET coin_balance = ? WHERE id = ?', [coins, user.id]);
  return { token, id: user.id };
}

async function approvedFilm(creatorName, price = 20) {
  const creator = await env.register(creatorName, 'creator');
  const film = await env.uploadFilm(creator.token, { title: `Film of ${creatorName}`, price_coins: price, episodes: 2 });
  await env.approve(film.filmId);
  return { creator, ...film };
}

async function emptyFilm(token, title) {
  const res = await env.req('post', '/api/films', token).send({
    title, genre: 'Drama', ai_tool: 'Mixed', is_ai_generated: true,
  });
  return res.body.film;
}

test('deleting an episode while it is being bought never takes coins without a right to watch', async () => {
  for (let round = 0; round < 12; round += 1) {
    const { creator, episodeIds } = await approvedFilm(`racer_c${round}`);
    const b = await buyer(`racer_b${round}`, 50);
    const paid = episodeIds[1];
    const [del, unlock] = await Promise.all([
      env.req('delete', `/api/episodes/${paid}`, creator.token),
      env.req('post', `/api/episodes/${paid}/unlock`, b.token),
    ]);
    const rights = (await one('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [b.id])).n;
    const balance = (await one('SELECT coin_balance b FROM users WHERE id = ?', [b.id])).b;
    const episodeLeft = (await one('SELECT COUNT(*) n FROM episodes WHERE id = ?', [paid])).n;
    if (unlock.status === 200) {
      assert.equal(del.status, 409, 'a paid-for episode cannot be deleted');
      assert.equal(rights, 1);
      assert.equal(balance, 30);
      assert.equal(episodeLeft, 1);
    } else {
      assert.equal(del.status, 204);
      assert.equal(unlock.status, 404);
      assert.equal(rights, 0);
      assert.equal(balance, 50, 'nothing was charged');
    }
  }
});

test('a failure after the upload commits keeps the stored file', async () => {
  const creator = await env.register('postcommit', 'creator');
  const film = await emptyFilm(creator.token, 'Post commit');
  const original = episodesModel.findWithFilm;
  episodesModel.findWithFilm = async () => {
    throw new Error('read after commit failed');
  };
  try {
    await env
      .req('post', `/api/films/${film.id}/episodes`, creator.token)
      .attach('video', makeMp4(), { filename: 'a.mp4', contentType: 'video/mp4' });
  } finally {
    episodesModel.findWithFilm = original;
  }
  const row = await one('SELECT video_path FROM episodes WHERE film_id = ?', [film.id]);
  assert.ok(row, 'the episode row was committed');
  assert.ok(fs.existsSync(path.join(env.uploadDir, path.basename(row.video_path))), 'its file must still exist');
});

test('renewing a plan many times, even at once, never overlaps dates', async () => {
  const { token, id } = await buyer('renew_many', 0);
  await Promise.all([1, 2, 3, 4].map(() => env.req('post', '/api/subscription', token)));
  await env.req('post', '/api/subscription', token);
  const [rows] = await env.pool.query(
    'SELECT start_date, end_date, DATE_ADD(end_date, INTERVAL 1 DAY) AS next_day FROM subscriptions WHERE user_id = ? ORDER BY start_date',
    [id],
  );
  assert.equal(rows.length, 5);
  for (let i = 1; i < rows.length; i += 1) {
    assert.equal(rows[i].start_date, rows[i - 1].next_day, 'each plan starts the day after the previous one ends');
    assert.ok(rows[i].end_date >= rows[i].start_date);
  }
  const state = (await env.req('get', '/api/subscription', token)).body;
  assert.equal(state.paid_through, rows[4].end_date);
  assert.equal(state.plans_remaining, 5);
  assert.equal(typeof state.today, 'string');
});

test('past earnings do not change when the owner changes role', async () => {
  const { creator, episodeIds } = await approvedFilm('role_change');
  const b = await buyer('role_change_buyer', 40);
  assert.equal((await env.req('post', `/api/episodes/${episodeIds[1]}/unlock`, b.token)).status, 200);
  const before = (await env.req('get', '/api/creator/earnings', creator.token)).body;
  assert.equal(before.coins_earned, 14);
  const admin = await env.login('admin');
  const promote = await env.req('put', `/api/admin/users/${creator.user.id}/role`, admin).send({ role: 'admin' });
  assert.equal(promote.status, 200);
  const after = (await env.req('get', '/api/creator/earnings', env.tokenFor(creator.user.id, 'admin'))).body;
  assert.equal(after.coins_earned, 14);
  assert.equal(after.films[0].coins_earned, 14);
});

test('only an MP4 that really holds a video track is accepted', async () => {
  const creator = await env.register('probe_creator', 'creator');
  const film = await emptyFilm(creator.token, 'Probe');
  const send = (buffer) =>
    env
      .req('post', `/api/films/${film.id}/episodes`, creator.token)
      .attach('video', buffer, { filename: 'x.mp4', contentType: 'video/mp4' });
  const filesBefore = fs.readdirSync(env.uploadDir).length;
  const header = Buffer.concat([Buffer.from([0, 0, 0, 12]), Buffer.from('ftypisom', 'latin1'), Buffer.alloc(4)]);
  assert.equal((await send(header)).status, 400, 'ftyp alone has no video');
  const good = makeMp4();
  assert.equal((await send(good.subarray(0, 40))).status, 400, 'truncated file');
  const audioOnly = Buffer.from(good);
  audioOnly.write('soun', audioOnly.indexOf('vide'), 'latin1');
  assert.equal((await send(audioOnly)).status, 400, 'no video handler');
  const wrongCodec = Buffer.from(good);
  wrongCodec.write('zzzz', wrongCodec.indexOf('avc1'), 'latin1');
  assert.equal((await send(wrongCodec)).status, 400, 'unsupported codec');
  assert.equal(fs.readdirSync(env.uploadDir).length, filesBefore, 'rejected files are removed');
  const fragmented = Buffer.from(good);
  fragmented.write('moof', fragmented.indexOf('mdat'), 'latin1');
  assert.equal((await send(fragmented)).status, 201, 'a fragmented MP4 (moof) is accepted');
  assert.equal((await send(good)).status, 201);
});

test('the price limit is 500 coins everywhere', async () => {
  const creator = await env.register('price_limit', 'creator');
  const film = await emptyFilm(creator.token, 'Price');
  const add = (price) =>
    env
      .req('post', `/api/films/${film.id}/episodes`, creator.token)
      .field('price_coins', String(price))
      .attach('video', makeMp4(), { filename: 'a.mp4', contentType: 'video/mp4' });
  assert.equal((await add(501)).status, 400);
  assert.equal((await add(999)).status, 400);
  const ok = await add(500);
  assert.equal(ok.status, 201);
  const edit = (price) => env.req('put', `/api/episodes/${ok.body.episode.id}`, creator.token).send({ price_coins: price });
  assert.equal((await edit(501)).status, 400);
  assert.equal((await edit(500)).status, 200);
});

test('lists say whether more pages exist and unlocked rights do not depend on ledger paging', async () => {
  const first = await env.req('get', '/api/films?page_size=2');
  assert.equal(first.body.films.length, 2);
  assert.equal(first.body.has_more, true);
  const all = await env.req('get', '/api/films?page_size=100');
  assert.equal(all.body.has_more, false);

  const b = await buyer('old_buyer', 100);
  assert.equal((await env.req('post', `/api/episodes/${PAID(3, 4)}/unlock`, b.token)).status, 200);
  for (let i = 0; i < 4; i += 1) await env.req('post', '/api/wallet/topup', b.token).send({ demo: true });
  const page = await env.req('get', '/api/wallet/transactions?limit=2', b.token);
  assert.equal(page.body.transactions.length, 2);
  assert.equal(page.body.has_more, true);
  const unlocked = await env.req('get', '/api/wallet/unlocked', b.token);
  assert.deepEqual(unlocked.body.unlocked.map((u) => u.episode_id), [PAID(3, 4)]);
  const none = await env.req('get', '/api/wallet/unlocked', (await buyer('no_buys', 0)).token);
  assert.deepEqual(none.body.unlocked, []);
});

test('editing a film changes prices and details together or not at all', async () => {
  const { creator, filmId, episodeIds } = await approvedFilm('atomic_edit', 20);
  const details = { title: 'New title', genre: 'Drama', ai_tool: 'Mixed', prompt_credit: 'p' };
  const bad = await env
    .req('put', `/api/films/${filmId}`, creator.token)
    .send({ ...details, genre: 'Not a genre', episode_prices: [{ id: episodeIds[1], price_coins: 40 }] });
  assert.equal(bad.status, 400);
  assert.equal((await one('SELECT price_coins p FROM episodes WHERE id = ?', [episodeIds[1]])).p, 20);
  const foreign = await env
    .req('put', `/api/films/${filmId}`, creator.token)
    .send({ ...details, episode_prices: [{ id: episodeIds[1], price_coins: 40 }, { id: 1, price_coins: 5 }] });
  assert.equal(foreign.status, 400);
  assert.equal((await one('SELECT price_coins p FROM episodes WHERE id = ?', [episodeIds[1]])).p, 20);
  assert.equal((await one('SELECT price_coins p FROM episodes WHERE id = 1')).p, 0);
  const tooHigh = await env
    .req('put', `/api/films/${filmId}`, creator.token)
    .send({ ...details, episode_prices: [{ id: episodeIds[1], price_coins: 501 }] });
  assert.equal(tooHigh.status, 400);
  const ok = await env
    .req('put', `/api/films/${filmId}`, creator.token)
    .send({ ...details, episode_prices: [{ id: episodeIds[1], price_coins: 40 }] });
  assert.equal(ok.status, 200);
  assert.equal((await one('SELECT price_coins p FROM episodes WHERE id = ?', [episodeIds[1]])).p, 40);
  assert.equal((await one('SELECT title t FROM films WHERE id = ?', [filmId])).t, 'New title');
});

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const settled = (promise) => {
  const state = { done: false };
  promise.then(() => { state.done = true; }, () => { state.done = true; });
  return state;
};

test('delete holds the film first: the purchase is refused and nothing is charged', async () => {
  const { creator, episodeIds } = await approvedFilm('order_delete_first');
  const b = await buyer('order_delete_first_b', 50);
  const paid = episodeIds[1];
  const filmId = (await one('SELECT film_id f FROM episodes WHERE id = ?', [paid])).f;
  const d = await env.pool.getConnection();
  try {
    await d.beginTransaction();
    await d.query('SELECT id FROM films WHERE id = ? FOR UPDATE', [filmId]);
    await d.query('DELETE FROM episodes WHERE id = ?', [paid]);
    const pending = env.req('post', `/api/episodes/${paid}/unlock`, b.token).then((r) => r);
    const state = settled(pending);
    await pause(250);
    assert.equal(state.done, false, 'the purchase must wait for the delete');
    await d.commit();
    const res = await pending;
    assert.equal(res.status, 404);
  } finally {
    d.release();
  }
  assert.equal((await one('SELECT coin_balance b FROM users WHERE id = ?', [b.id])).b, 50);
  assert.equal((await one('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [b.id])).n, 0);
  assert.equal((await one('SELECT COUNT(*) n FROM coin_transactions WHERE user_id = ?', [b.id])).n, 0);
  assert.ok(creator);
});

test('the purchase holds the film first: the delete is refused and the right is kept', async () => {
  const { creator, episodeIds } = await approvedFilm('order_unlock_first');
  const b = await buyer('order_unlock_first_b', 50);
  const paid = episodeIds[1];
  const h = await env.pool.getConnection();
  try {
    await h.beginTransaction();
    // Holding the buyer's row stalls the purchase after it has taken the film lock.
    await h.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [b.id]);
    const unlocking = env.req('post', `/api/episodes/${paid}/unlock`, b.token).then((r) => r);
    await pause(250);
    const deleting = env.req('delete', `/api/episodes/${paid}`, creator.token).then((r) => r);
    const deleteState = settled(deleting);
    await pause(250);
    assert.equal(deleteState.done, false, 'the delete must wait for the purchase');
    await h.commit();
    const [unlock, del] = await Promise.all([unlocking, deleting]);
    assert.equal(unlock.status, 200);
    assert.equal(unlock.body.charged, 20);
    assert.equal(del.status, 409);
  } finally {
    h.release();
  }
  assert.equal((await one('SELECT coin_balance b FROM users WHERE id = ?', [b.id])).b, 30);
  assert.equal((await one('SELECT COUNT(*) n FROM unlocked_episodes WHERE user_id = ?', [b.id])).n, 1);
  assert.equal((await one('SELECT COUNT(*) n FROM episodes WHERE id = ?', [paid])).n, 1);
});
