const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { createTestEnv, makeMp4 } = require('./db');

let env;
test.before(async () => {
  env = await createTestEnv('upload');
});
test.after(() => env.close());

const filmBody = (over = {}) => ({
  title: 'My AI Film',
  synopsis: 'A test',
  genre: 'Sci-Fi',
  ai_tool: 'Text-to-video',
  prompt_credit: 'Prompt: test',
  is_ai_generated: true,
  ...over,
});

const attach = (req, buffer = makeMp4(), type = 'video/mp4') =>
  req.attach('video', buffer, { filename: 'clip.mp4', contentType: type });

const feedIds = async () => (await env.req('get', '/api/films')).body.films.map((f) => f.id);
const files = () => fs.readdirSync(env.uploadDir);

test('upload -> pending -> approve -> appears in the feed', async () => {
  const creator = await env.login('kestrel_studio');
  const created = await env.req('post', '/api/films', creator).send(filmBody());
  assert.equal(created.status, 201);
  const film = created.body.film;
  assert.equal(film.status, 'pending');
  assert.equal(film.is_ai_generated, true);
  assert.equal(film.genre, 'Sci-Fi');

  const ep = await attach(
    env.req('post', `/api/films/${film.id}/episodes`, creator).field('price_coins', '15').field('title', 'Pilot'),
  );
  assert.equal(ep.status, 201);
  assert.equal(ep.body.episode.price_coins, 15);
  assert.equal(ep.body.episode.is_free, false);
  assert.equal(ep.body.episode.duration_sec, 5, 'length is read from the mp4 itself');
  assert.equal(files().length, 1);

  assert.equal((await feedIds()).includes(film.id), false, 'pending film is hidden');
  assert.equal((await env.req('get', `/api/films/${film.id}`)).status, 404);

  const mine = await env.req('get', '/api/creator/films', creator);
  assert.equal(mine.body.films.find((f) => f.id === film.id).status, 'pending');

  const admin = await env.login('admin');
  const queue = await env.req('get', '/api/admin/reviews', admin);
  assert.ok(queue.body.films.some((f) => f.id === film.id));
  const approved = await env.req('post', `/api/admin/films/${film.id}/review`, admin).send({ status: 'approved' });
  assert.equal(approved.status, 200);
  assert.equal(approved.body.film.status, 'approved');

  assert.ok((await feedIds()).includes(film.id));
  const detail = await env.req('get', `/api/films/${film.id}`);
  assert.equal(detail.status, 200);
  assert.equal(detail.body.episodes[0].access, 'login_required');
});

test('the AI label is mandatory and names must be known', async () => {
  const creator = await env.login('kestrel_studio');
  for (const body of [
    filmBody({ is_ai_generated: false }),
    filmBody({ is_ai_generated: undefined }),
    filmBody({ genre: 'Western' }),
    filmBody({ ai_tool: 'Magic' }),
    filmBody({ title: '' }),
  ]) {
    const res = await env.req('post', '/api/films', creator).send(body);
    assert.equal(res.status, 400, JSON.stringify(body));
  }
});

test('a missing, fake or non-mp4 file is rejected and leaves nothing on disk', async () => {
  const creator = await env.login('kestrel_studio');
  const { film } = (await env.req('post', '/api/films', creator).send(filmBody())).body;
  const url = `/api/films/${film.id}/episodes`;
  const before = files().length;

  const none = await env.req('post', url, creator).field('price_coins', '0');
  assert.equal(none.status, 400);
  const text = await attach(env.req('post', url, creator), Buffer.from('hello'), 'text/plain');
  assert.equal(text.status, 400);
  const fake = await attach(env.req('post', url, creator), Buffer.from('this is not a video at all'));
  assert.equal(fake.status, 400);
  assert.equal(fake.body.error.code, 'VALIDATION_ERROR');
  assert.equal(files().length, before);
});

test('an invalid price removes the saved file again', async () => {
  const creator = await env.login('kestrel_studio');
  const { film } = (await env.req('post', '/api/films', creator).send(filmBody())).body;
  const before = files().length;
  const res = await attach(
    env.req('post', `/api/films/${film.id}/episodes`, creator).field('price_coins', '99999'),
  );
  assert.equal(res.status, 400);
  assert.equal(files().length, before);
});

test('when the database write fails the uploaded file is deleted', async () => {
  const creator = await env.login('kestrel_studio');
  const { filmId } = await env.uploadFilm(creator, { title: 'Dup' });
  const before = files().length;
  const res = await attach(env.req('post', `/api/films/${filmId}/episodes`, creator).field('episode_no', '1'));
  assert.equal(res.status, 409);
  assert.equal(files().length, before);
});

test('only the owner or an admin can add episodes, and strangers never write a file', async () => {
  const owner = await env.login('kestrel_studio');
  const { film } = (await env.req('post', '/api/films', owner).send(filmBody())).body;
  const url = `/api/films/${film.id}/episodes`;
  const before = files().length;
  const other = await env.login('noor.frames');
  assert.equal((await attach(env.req('post', url, other))).status, 404, 'pending film is not even visible');
  await env.approve(film.id).catch(() => {});
  assert.equal(files().length, before);
  const viewer = await env.login('viewer01');
  assert.equal((await attach(env.req('post', url, viewer))).status, 403);
  assert.equal(files().length, before);
});

test('a creator cannot edit or delete another creator\'s approved film', async () => {
  const other = await env.login('noor.frames');
  const put = await env.req('put', '/api/films/1', other).send(filmBody());
  assert.equal(put.status, 403);
  assert.equal((await env.req('delete', '/api/films/1', other)).status, 403);
  assert.equal((await env.req('put', '/api/episodes/1', other).send({ price_coins: 5 })).status, 403);
  assert.equal((await env.req('delete', '/api/episodes/1', other)).status, 403);
  const [[row]] = await env.pool.query('SELECT title, status FROM films WHERE id = 1');
  assert.deepEqual(row, { title: 'Salt & Signal', status: 'approved' });
});

test('an admin can edit any film without sending it back to review', async () => {
  const admin = await env.login('admin');
  const res = await env.req('put', '/api/films/2', admin).send(filmBody({ title: 'Paper Moons', genre: 'Romance' }));
  assert.equal(res.status, 200);
  assert.equal(res.body.film.status, 'approved');
});

test('editing an approved film as its owner sends it back to review', async () => {
  const owner = await env.login('noor.frames');
  const res = await env.req('put', '/api/films/2', owner).send(filmBody({ title: 'Paper Moons II', genre: 'Romance' }));
  assert.equal(res.status, 200);
  assert.equal(res.body.film.status, 'pending');
  assert.equal((await feedIds()).includes(2), false);
  await env.approve(2);
  assert.ok((await feedIds()).includes(2));
});

test('adding an episode to a live film puts the film back in review', async () => {
  const owner = await env.login('tidewater_ai');
  const { filmId } = await env.uploadFilm(owner, { title: 'Live Film' });
  await env.approve(filmId);
  assert.ok((await feedIds()).includes(filmId));
  const res = await attach(env.req('post', `/api/films/${filmId}/episodes`, owner).field('price_coins', '10'));
  assert.equal(res.status, 201);
  assert.equal((await feedIds()).includes(filmId), false);
});

test('reject and take down hide the film, need a note, and block playback', async () => {
  const owner = await env.login('noor.frames');
  const admin = await env.login('admin');
  const review = (id, body) => env.req('post', `/api/admin/films/${id}/review`, admin).send(body);

  const { filmId, episodeIds } = await env.uploadFilm(owner, { title: 'To Reject' });
  assert.equal((await review(filmId, { status: 'rejected' })).status, 400, 'note required');
  const rejected = await review(filmId, { status: 'rejected', note: 'Unclear AI credit' });
  assert.equal(rejected.body.film.status, 'rejected');
  assert.equal((await feedIds()).includes(filmId), false);
  assert.equal((await env.req('get', `/api/films/${filmId}`)).status, 404);
  assert.equal((await env.req('get', `/api/episodes/${episodeIds[0]}`)).status, 404);
  assert.equal((await env.req('get', `/api/episodes/${episodeIds[0]}/stream`)).status, 404);
  const mine = await env.req('get', '/api/creator/films', owner);
  const row = mine.body.films.find((f) => f.id === filmId);
  assert.equal(row.status, 'rejected');
  assert.equal(row.review_note, 'Unclear AI credit');

  // The owner fixes it: back to pending, note cleared.
  const edited = await env.req('put', `/api/films/${filmId}`, owner).send(filmBody({ title: 'Fixed' }));
  assert.equal(edited.body.film.status, 'pending');
  assert.equal(edited.body.film.review_note, null);

  // Take down a live film while a stream link from before is still valid.
  assert.equal((await review(filmId, { status: 'approved' })).status, 200);
  const link = (await env.req('get', `/api/episodes/${episodeIds[0]}`)).body.stream_url;
  assert.equal((await env.req('get', link)).status, 200, 'the link works while the film is live');
  const down = await review(filmId, { status: 'taken_down', note: 'Copyright claim' });
  assert.equal(down.body.film.status, 'taken_down');
  assert.equal((await feedIds()).includes(filmId), false);
  assert.equal((await env.req('get', link)).status, 404, 'an old playback link stops working');
  assert.equal((await env.req('put', `/api/films/${filmId}`, owner).send(filmBody())).status, 409);
});

test('review transitions are enforced and an empty film cannot go live', async () => {
  const admin = await env.login('admin');
  const review = (id, body) => env.req('post', `/api/admin/films/${id}/review`, admin).send(body);
  assert.equal((await review(1, { status: 'rejected', note: 'x' })).status, 409, 'approved -> rejected');
  assert.equal((await review(4, { status: 'taken_down', note: 'x' })).status, 409, 'pending -> taken_down');
  assert.equal((await review(1, { status: 'bogus' })).status, 400);
  const creator = await env.login('kestrel_studio');
  const { film } = (await env.req('post', '/api/films', creator).send(filmBody())).body;
  assert.equal((await review(film.id, { status: 'approved' })).status, 409);
});

test('taking a film down closes its open reports', async () => {
  const viewer = await env.login('viewer01');
  const admin = await env.login('admin');
  assert.equal((await env.req('post', '/api/films/3/reports', viewer).send({ reason: 'Spam' })).status, 201);
  const open = (await env.req('get', '/api/admin/reports', admin)).body.reports.filter((r) => r.status === 'open');
  assert.ok(open.some((r) => r.film_id === 3));
  await env.req('post', '/api/admin/films/3/review', admin).send({ status: 'taken_down', note: 'Reported' });
  const after = (await env.req('get', '/api/admin/reports', admin)).body.reports;
  assert.ok(after.filter((r) => r.film_id === 3).every((r) => r.status === 'resolved'));
});

test('a film that viewers paid for cannot be deleted; others can, with their files', async () => {
  const owner = await env.login('kestrel_studio');
  assert.equal((await env.req('delete', '/api/films/1', owner)).status, 409);
  assert.equal((await env.req('delete', '/api/episodes/3', owner)).status, 409, 'episode 3 of film 1 was bought');
  const { filmId, episodeIds } = await env.uploadFilm(owner, { title: 'Delete me', episodes: 2, price_coins: 5 });
  const before = files().length;
  assert.equal((await env.req('delete', `/api/episodes/${episodeIds[1]}`, owner)).status, 204);
  assert.equal(files().length, before - 1);
  assert.equal((await env.req('delete', `/api/films/${filmId}`, owner)).status, 204);
  assert.equal(files().length, before - 2);
  const [rows] = await env.pool.query('SELECT id FROM episodes WHERE film_id = ?', [filmId]);
  assert.equal(rows.length, 0);
});

test('the owner sets each episode free or priced, and price changes keep earlier unlocks', async () => {
  const owner = await env.login('kestrel_studio');
  const free = await env.req('put', '/api/episodes/4', owner).send({ is_free: true });
  assert.equal(free.body.episode.is_free, true);
  assert.equal(free.body.episode.price_coins, 0);
  const paid = await env.req('put', '/api/episodes/4', owner).send({ price_coins: 40 });
  assert.equal(paid.body.episode.price_coins, 40);
  assert.equal(paid.body.episode.is_free, false);
  assert.equal((await env.req('put', '/api/episodes/4', owner).send({ is_free: false, price_coins: 0 })).status, 400);
  const mira = await env.login('mira.lens'); // bought episode 4 in the seed
  const detail = await env.req('get', '/api/episodes/4', mira);
  assert.equal(detail.body.episode.access, 'unlocked');
});

test('an oversized upload is a 413 and leaves no file', async () => {
  const small = await createTestEnv('upload_small', { maxUploadBytes: 1024 });
  try {
    const creator = await small.login('kestrel_studio');
    const { film } = (await small.req('post', '/api/films', creator).send(filmBody())).body;
    const res = await attach(small.req('post', `/api/films/${film.id}/episodes`, creator), makeMp4(5000));
    assert.equal(res.status, 413);
    assert.deepEqual(fs.readdirSync(small.uploadDir), []);
  } finally {
    await small.close();
  }
});
