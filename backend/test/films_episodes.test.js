const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const films = require('../src/controllers/films');
const episodes = require('../src/controllers/episodes');
const { fakePool, fakeReq, fakeRes } = require('./helpers/fakes');

const viewer = { id: 2, role: 'viewer' };
const admin = { id: 1, role: 'admin' };

async function call(handler, req) {
  const res = fakeRes();
  await handler(req, res);
  return res.body;
}

// ---- films.getOne ----

const filmRow = (status = 'approved') => ({
  id: 4, title: 'Salt & Signal', status, is_ai_generated: 1, catalog_drama_id: null,
  episode_count: 3, free_count: 1, like_count: 5, comment_count: 2,
});
const episodeRows = [
  { id: 10, film_id: 4, episode_no: 1, is_free: 1, price_coins: 0 },
  { id: 11, film_id: 4, episode_no: 2, is_free: 0, price_coins: 20 },
  { id: 12, film_id: 4, episode_no: 3, is_free: 0, price_coins: 20 },
];

function filmPool({ status = 'approved', unlocked = [], liked = [], saved = [] } = {}) {
  return fakePool([
    ['WHERE f.id = ?', status ? [filmRow(status)] : []],
    ['FROM episodes e WHERE e.film_id = ?', episodeRows],
    ['SELECT episode_id FROM unlocked_episodes', unlocked.map((id) => ({ episode_id: id }))],
    ['FROM likes WHERE user_id', liked.map((id) => ({ film_id: id }))],
    ['FROM watchlist WHERE user_id', saved.map((id) => ({ film_id: id }))],
  ]);
}

test('getOne gives a viewer each episode access and the like/save flags', async () => {
  const body = await call(films.getOne, fakeReq({
    pool: filmPool({ unlocked: [11], liked: [4] }), user: viewer, params: { id: '4' },
  }));
  assert.equal(body.film.id, 4);
  assert.equal(body.film.liked, true);
  assert.equal(body.film.saved, false);
  assert.deepEqual(body.episodes.map((e) => e.access), ['free', 'unlocked', 'locked']);
});

test('getOne for a guest has no flags and asks to log in for paid episodes', async () => {
  const pool = filmPool();
  const body = await call(films.getOne, fakeReq({ pool, params: { id: '4' } }));
  assert.equal(body.film.liked, undefined);
  assert.deepEqual(body.episodes.map((e) => e.access), ['free', 'login_required', 'login_required']);
  assert.equal(pool.callsMatching('FROM likes WHERE user_id').length, 0);
});

test('getOne hides a taken-down film from viewers but not from the admin', async () => {
  await assert.rejects(
    call(films.getOne, fakeReq({ pool: filmPool({ status: 'taken_down' }), user: viewer, params: { id: '4' } })),
    (e) => e.status === 404,
  );
  const body = await call(films.getOne, fakeReq({ pool: filmPool({ status: 'taken_down' }), user: admin, params: { id: '4' } }));
  assert.deepEqual(body.episodes.map((e) => e.access), ['owner', 'owner', 'owner']);
});

test('getOne is a 404 for a missing film and a 400 for a bad id', async () => {
  await assert.rejects(call(films.getOne, fakeReq({ pool: filmPool({ status: null }), params: { id: '4' } })), (e) => e.status === 404);
  await assert.rejects(call(films.getOne, fakeReq({ pool: filmPool(), params: { id: '4x' } })), (e) => e.status === 400);
});

// ---- episodes.getOne ----

function episodePool({ episode, unlocked = [] } = {}) {
  return fakePool([
    ['FROM episodes e JOIN films f', episode ? [episode] : []],
    ['SELECT episode_id FROM unlocked_episodes', unlocked.map((id) => ({ episode_id: id }))],
  ]);
}
const paidEpisode = (extra = {}) => ({
  id: 11, film_id: 4, episode_no: 2, is_free: 0, price_coins: 20,
  video_path: 'films/4/2.mp4', film_status: 'approved', film_title: 'Salt & Signal', ...extra,
});

test('episodes.getOne hands out a stream link only when the caller may watch', async () => {
  const locked = await call(episodes.getOne, fakeReq({ pool: episodePool({ episode: paidEpisode() }), user: viewer, params: { id: '11' } }));
  assert.equal(locked.episode.access, 'locked');
  assert.equal(locked.stream_url, null);

  const open = await call(episodes.getOne, fakeReq({
    pool: episodePool({ episode: paidEpisode(), unlocked: [11] }), user: viewer, params: { id: '11' },
  }));
  assert.equal(open.episode.access, 'unlocked');
  assert.deepEqual(open.film, { id: 4, title: 'Salt & Signal' });
  const token = decodeURIComponent(open.stream_url.split('?t=')[1]);
  const payload = jwt.verify(token, 'test-secret');
  assert.deepEqual([payload.typ, payload.eid, payload.uid], ['stream', 11, 2]);
});

test('episodes.getOne gives a guest a link for a free episode with no user in it', async () => {
  const body = await call(episodes.getOne, fakeReq({ pool: episodePool({ episode: paidEpisode({ is_free: 1, price_coins: 0 }) }), params: { id: '11' } }));
  assert.equal(body.episode.access, 'free');
  const payload = jwt.decode(decodeURIComponent(body.stream_url.split('?t=')[1]));
  assert.equal(payload.uid, null);
});

test('episodes.getOne is a 404 for a catalog episode, a missing one, or a taken-down film', async () => {
  for (const episode of [paidEpisode({ video_path: null }), undefined, paidEpisode({ film_status: 'taken_down' })]) {
    await assert.rejects(
      call(episodes.getOne, fakeReq({ pool: episodePool({ episode }), user: viewer, params: { id: '11' } })),
      (e) => e.status === 404,
    );
  }
});
