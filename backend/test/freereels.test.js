const test = require('node:test');
const assert = require('node:assert/strict');
const freereels = require('../src/services/freereels');
const catalogModel = require('../src/models/catalog');
const controller = require('../src/controllers/catalog');
const { createCatalogClient } = require('../src/services/seriesjeen');
const { fakePool, fakeReq, fakeRes } = require('./helpers/fakes');

const listItem = {
  series_id: 'm4FzR2J0iQ',
  title: 'รักเป็นเหยื่อล่อ(พากย์เสียง)',
  cover: 'https://img/cover.jpg',
  episode_count: 80,
  genre: 'คืนดีกัน, แก้แค้น',
  description: 'เรื่องย่อ',
};

const detailBody = {
  data: {
    data: {
      info: {
        id: 'm4FzR2J0iQ',
        name: 'รักเป็นเหยื่อล่อ',
        desc: 'เรื่องย่อ',
        cover: 'https://img/cover.jpg',
        episode_count: 80,
        content_tags: ['คืนดีกัน'],
        episode: { subtitle_list: [{ language: 'th-TH', vtt: 'https://sub/th.vtt' }] },
      },
    },
  },
  success: true,
};

const playBody = {
  data: {
    data: {
      episode_number: 6,
      m3u8_url: 'https://video/6.m3u8',
      subtitle_list: [
        { language: 'th-TH', vtt: 'https://sub/6-th.vtt' },
        { language: 'en-US', vtt: 'https://sub/6-en.vtt' },
        { language: 'ja-JP', subtitle: 'https://sub/6-ja.srt' },
      ],
    },
  },
  success: true,
};

// A catalog client that answers by path and records what was asked.
function fakeClient(answers) {
  const calls = [];
  return {
    calls,
    async get(path, query = {}) {
      calls.push({ path, query });
      const answer = answers[path];
      if (answer === undefined) throw new Error(`Unexpected catalog call: ${path}`);
      return typeof answer === 'function' ? answer(query) : answer;
    },
  };
}

function idPool(known = { m4FzR2J0iQ: 7 }) {
  const table = new Map(Object.entries(known));
  let next = 100;
  return fakePool([
    [/^INSERT IGNORE INTO catalog_series/, (params) => {
      for (const s of params) if (!table.has(s)) table.set(s, next++);
      return { affectedRows: params.length };
    }],
    [/FROM catalog_series WHERE series_id IN/, ([ids]) =>
      ids.filter((s) => table.has(s)).map((s) => ({ id: table.get(s), series_id: s }))],
    [/FROM catalog_series WHERE id = /, ([id]) =>
      [...table].filter(([, n]) => n === id).map(([s]) => ({ series_id: s }))],
    [/FROM settings/, (params) => (params[0] === 'catalog_free_episodes' ? [{ value: '5' }] : [{ value: '10' }])],
    ['FROM unlocked_episodes', []],
  ]);
}

async function run(handler, req) {
  const res = fakeRes();
  let error;
  await handler(req, res, (err) => { error = err; });
  if (error) throw error;
  return res.body;
}

test('toDrama maps a list item into the app drama shape', () => {
  assert.deepEqual(freereels.toDrama(listItem, 7), {
    id: 7,
    title: 'รักเป็นเหยื่อล่อ(พากย์เสียง)',
    description: 'เรื่องย่อ',
    episode_count: 80,
    genres: ['คืนดีกัน', 'แก้แค้น'],
    poster: 'https://img/cover.jpg',
    thai_dub: true,
    thai_sub: false,
  });
});

test('toPage keeps only mapped items and counts pages', () => {
  const page = freereels.toPage(
    { page: 2, page_size: 20, total: 45, items: [listItem, { ...listItem, series_id: 'other' }] },
    new Map([['m4FzR2J0iQ', 7]]),
  );
  assert.equal(page.items.length, 1);
  assert.equal(page.page, 2);
  assert.equal(page.total_pages, 3);
});

test('toPlatforms marks FreeReels as open only when the key has it', () => {
  const open = freereels.toPlatforms({ platforms: [{ platform_id: 19, name: 'FreeReels' }] });
  assert.deepEqual(open.items, [{ id: 19, name: 'FreeReels', drama_count: 0, has_access: true }]);
  assert.equal(freereels.toPlatforms({ platforms: [] }).items[0].has_access, false);
});

test('detailInfo is null for an unknown series', () => {
  assert.equal(freereels.detailInfo({ data: { data: {} }, success: true }), null);
  assert.equal(freereels.detailInfo(detailBody).id, 'm4FzR2J0iQ');
});

test('toDramaFromDetail reads Thai subtitles from the first episode', () => {
  const drama = freereels.toDramaFromDetail(freereels.detailInfo(detailBody), 7);
  assert.equal(drama.title, 'รักเป็นเหยื่อล่อ');
  assert.deepEqual(drama.genres, ['คืนดีกัน']);
  assert.equal(drama.thai_sub, true);
  assert.equal(drama.thai_dub, false);
});

test('toEpisode gives one part with short language codes and only VTT files', () => {
  assert.deepEqual(freereels.toEpisode(playBody, 6), {
    episode_no: 6,
    parts: [{
      url: 'https://video/6.m3u8',
      subtitles: [
        { language: 'th', url: 'https://sub/6-th.vtt', forced: false },
        { language: 'en', url: 'https://sub/6-en.vtt', forced: false },
      ],
    }],
  });
  assert.equal(freereels.toEpisode({ data: { data: {} } }, 1), null);
});

test('idsFor inserts only new series ids, then returns every number', async () => {
  const pool = idPool();
  const ids = await catalogModel.idsFor(pool, ['m4FzR2J0iQ', 'newOne', 'newOne']);
  assert.deepEqual([...ids], [['m4FzR2J0iQ', 7], ['newOne', 100]]);
  const inserts = pool.callsMatching(/INSERT IGNORE/);
  assert.equal(inserts.length, 1);
  assert.deepEqual(inserts[0].params, ['newOne']);
});

test('idsFor skips the insert when every id is known', async () => {
  const pool = idPool();
  await catalogModel.idsFor(pool, ['m4FzR2J0iQ']);
  assert.equal(pool.callsMatching(/INSERT/).length, 0);
});

test('dramas lists Thai dubs, or searches when q is given', async () => {
  const client = fakeClient({
    [freereels.paths.thai]: { page: 1, page_size: 20, total: 1, items: [listItem] },
    [freereels.paths.search]: { page: 1, page_size: 20, total: 0, items: [] },
  });
  const locals = { catalog: client };
  const list = await run(controller.dramas, fakeReq({ pool: idPool(), locals, params: { platformId: '19' } }));
  assert.equal(list.items[0].id, 7);
  await run(controller.dramas, fakeReq({ pool: idPool(), locals, params: { platformId: '19' }, query: { q: 'รัก' } }));
  assert.equal(client.calls[1].path, freereels.paths.search);
  assert.equal(client.calls[1].query.keyword, 'รัก');
});

test('dramas on another platform id is a 404', async () => {
  const req = fakeReq({ pool: idPool(), locals: { catalog: fakeClient({}) }, params: { platformId: '3' } });
  await assert.rejects(run(controller.dramas, req), (err) => err.status === 404);
});

test('drama looks up the series id behind our number', async () => {
  const client = fakeClient({ [freereels.paths.drama('m4FzR2J0iQ')]: detailBody });
  const body = await run(controller.drama, fakeReq({ pool: idPool(), locals: { catalog: client }, params: { dramaId: '7' } }));
  assert.equal(body.id, 7);
  assert.equal(body.episode_count, 80);
});

test('drama with a number we never handed out is a 404', async () => {
  const req = fakeReq({ pool: idPool(), locals: { catalog: fakeClient({}) }, params: { dramaId: '999' } });
  await assert.rejects(run(controller.drama, req), (err) => err.status === 404);
});

test('episodes fetches each episode in the range for the admin', async () => {
  const client = fakeClient({
    [freereels.paths.play('m4FzR2J0iQ', 6)]: playBody,
    [freereels.paths.play('m4FzR2J0iQ', 7)]: { data: { data: { ...playBody.data.data, episode_number: 7 } } },
  });
  const body = await run(controller.episodes, fakeReq({
    pool: idPool(),
    user: { id: 1, role: 'admin' },
    locals: { catalog: client },
    params: { dramaId: '7' },
    query: { ep: '6-7' },
  }));
  assert.deepEqual(body.episodes.map((e) => e.episode_no), [6, 7]);
});

test('episodes refuses a locked episode before asking the catalog', async () => {
  const client = fakeClient({});
  const req = fakeReq({
    pool: idPool(),
    user: { id: 2, role: 'viewer' },
    locals: { catalog: client },
    params: { dramaId: '7' },
    query: { ep: '6' },
  });
  await assert.rejects(run(controller.episodes, req), (err) => err.status === 403);
  assert.equal(client.calls.length, 0);
});

test('the client turns a { success: false } not-found reply into a 404', async () => {
  const fetchImpl = async () => ({
    ok: true,
    json: async () => ({ success: false, error: 'episode 999 not found (total: 80)' }),
  });
  const client = createCatalogClient({ apiKey: 'k', fetchImpl });
  await assert.rejects(client.get('/x'), (err) => err.status === 404);
});
