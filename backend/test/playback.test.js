const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createTestEnv, makeMp4 } = require('./db');

let env;
test.before(async () => {
  env = await createTestEnv('playback');
  // The seed rows point at uploads/film<f>_ep<n>.mp4; give a few real bytes.
  for (const name of ['film1_ep1', 'film1_ep3', 'film4_ep1']) {
    fs.writeFileSync(path.join(env.uploadDir, `${name}.mp4`), makeMp4(4096));
  }
});
test.after(() => env.close());

// Seed: episode id = (film - 1) * 8 + number. Eps 1-2 free, 3-8 cost 20 coins.
const FREE_EP = 1;
const PAID_EP = 3;
const PENDING_FILM_EP = 25; // film 4 is pending

test('a guest sees only approved films', async () => {
  const res = await env.req('get', '/api/films');
  assert.equal(res.status, 200);
  const ids = res.body.films.map((f) => f.id).sort();
  assert.deepEqual(ids, [1, 2, 3, 5]);
  assert.ok(res.body.films.every((f) => f.status === 'approved'));
  assert.ok(res.body.films.every((f) => f.review_note === undefined));
});

test('a guest cannot open a pending film or its episodes', async () => {
  assert.equal((await env.req('get', '/api/films/4')).status, 404);
  assert.equal((await env.req('get', `/api/episodes/${PENDING_FILM_EP}`)).status, 404);
  assert.equal((await env.req('get', `/api/episodes/${PENDING_FILM_EP}/stream`)).status, 404);
});

test('a guest can watch a free episode', async () => {
  const detail = await env.req('get', `/api/episodes/${FREE_EP}`);
  assert.equal(detail.body.episode.access, 'free');
  assert.ok(detail.body.stream_url);
  const res = await env.req('get', detail.body.stream_url);
  assert.equal(res.status, 200);
  assert.equal(res.headers['content-type'], 'video/mp4');
});

test('a guest is asked to log in for a paid episode and gets no link', async () => {
  const detail = await env.req('get', `/api/episodes/${PAID_EP}`);
  assert.equal(detail.status, 200);
  assert.equal(detail.body.episode.access, 'login_required');
  assert.equal(detail.body.stream_url, null);
  assert.equal(JSON.stringify(detail.body).includes('video_path'), false);
  const direct = await env.req('get', `/api/episodes/${PAID_EP}/stream`);
  assert.equal(direct.status, 401);
});

test('the upload folder is not served directly', async () => {
  for (const url of ['/uploads/film1_ep3.mp4', '/api/uploads/film1_ep3.mp4', '/film1_ep3.mp4']) {
    assert.equal((await env.req('get', url)).status, 404, url);
  }
});

test('a logged-in viewer without coins is blocked from a paid episode', async () => {
  const { token } = await env.register('poor_viewer');
  const detail = await env.req('get', `/api/episodes/${PAID_EP}`, token);
  assert.equal(detail.body.episode.access, 'locked');
  assert.equal(detail.body.stream_url, null);
  assert.equal((await env.req('get', `/api/episodes/${PAID_EP}/stream`, token)).status, 403);
});

test('a stream link for a free episode cannot be reused for a paid one', async () => {
  const detail = await env.req('get', `/api/episodes/${FREE_EP}`);
  const swapped = detail.body.stream_url.replace(`/episodes/${FREE_EP}/`, `/episodes/${PAID_EP}/`);
  assert.equal((await env.req('get', swapped)).status, 401);
});

test('the login token is not accepted as a playback link', async () => {
  const token = await env.login('mira.lens');
  const res = await env.req('get', `/api/episodes/${PAID_EP}/stream?t=${token}`);
  assert.equal(res.status, 401);
});

test('an unlocked episode plays through its link, and seeking (Range) works', async () => {
  const token = await env.login('mira.lens'); // unlocked film 1 ep 3 in the seed
  const detail = await env.req('get', `/api/episodes/${PAID_EP}`, token);
  assert.equal(detail.body.episode.access, 'unlocked');
  const url = detail.body.stream_url;
  const full = await env.req('get', url);
  assert.equal(full.status, 200);
  assert.equal(full.headers['accept-ranges'], 'bytes');
  const part = await env.req('get', url).set('Range', 'bytes=10-19');
  assert.equal(part.status, 206);
  assert.equal(part.headers['content-range'].startsWith('bytes 10-19/'), true);
  assert.equal(part.body.length, 10);
});

test('a missing video file is a 404, not a crash', async () => {
  const res = await env.req('get', '/api/episodes/2/stream'); // free, but no file on disk
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});

test('a path stored with ../ cannot leave the upload folder', async () => {
  fs.writeFileSync(path.join(env.uploadDir, '..', 'secret-outside.mp4'), makeMp4());
  await env.pool.query("UPDATE episodes SET video_path = '../secret-outside.mp4' WHERE id = 2");
  const res = await env.req('get', '/api/episodes/2/stream');
  assert.equal(res.status, 404);
});

test('search filters by genre, AI tool, length and text', async () => {
  const names = async (q) => (await env.req('get', `/api/films?${q}`)).body.films.map((f) => f.title).sort();
  assert.deepEqual(await names('genre=Sci-Fi'), ['Ember Protocol']);
  assert.deepEqual(await names('genre=Sci-Fi,Romance'), ['Ember Protocol', 'Paper Moons']);
  assert.deepEqual(await names('ai_tool=Mixed'), ['ShortReel Intro']);
  assert.deepEqual(await names('q=moons'), ['Paper Moons']);
  assert.equal((await names('length=15to30')).length, 4); // 17 minutes each
  assert.deepEqual(await names('length=under5'), []);
  assert.equal((await env.req('get', '/api/films?length=forever')).status, 400);
  assert.equal((await env.req('get', '/api/films?sort=random')).status, 400);
});

test('a viewer sees their own like, save and follow flags', async () => {
  const token = await env.login('mira.lens');
  const films = (await env.req('get', '/api/films', token)).body.films;
  const film1 = films.find((f) => f.id === 1);
  assert.equal(film1.liked, true);
  assert.equal(films.find((f) => f.id === 2).saved, true);
  assert.equal(films.find((f) => f.id === 2).following_creator, true);
});

test('films can be listed per channel and carry the follower count', async () => {
  const res = await env.req('get', '/api/films?creator_id=2');
  assert.deepEqual(res.body.films.map((f) => f.id), [1]);
  assert.equal(res.body.films[0].creator.follower_count, 1);
});

test('the link handed to a guest cannot be used as a login or on the catalog', async () => {
  const detail = await env.req('get', `/api/episodes/${FREE_EP}`);
  const link = new URL(detail.body.stream_url, 'http://x').searchParams.get('t');
  assert.equal((await env.req('get', '/api/auth/me', link)).status, 401);
  assert.equal((await env.req('get', '/api/catalog/dramas/1/episodes?ep=1', link)).status, 401);
});
