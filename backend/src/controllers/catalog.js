const ApiError = require('../utils/ApiError');
const catalogModel = require('../models/catalog');
const wallet = require('../models/wallet');
const freereels = require('../services/freereels');

const SORTS = new Set(['latest', 'title', 'episodes']);
const MAX_EPISODES_PER_REQUEST = 3;

function id(value) {
  if (!/^\d{1,9}$/.test(value)) throw new ApiError(400, 'VALIDATION_ERROR', 'Id is not valid');
  return value;
}

function intIn(value, name, min, max) {
  if (value === undefined) return undefined;
  const n = Number(value);
  if (!Number.isInteger(n) || n < min || n > max) {
    throw new ApiError(400, 'VALIDATION_ERROR', `${name} is not valid`);
  }
  return n;
}

// "3" or "3-5". A viewer plays what they opened, so ranges stay short.
function episodeRange(value) {
  const match = /^(\d{1,4})(?:-(\d{1,4}))?$/.exec(value ?? '');
  const from = match && Number(match[1]);
  const to = match && Number(match[2] ?? match[1]);
  if (!match || from < 1 || to < from || to - from >= MAX_EPISODES_PER_REQUEST) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'ep is not valid');
  }
  return { value, from, to };
}

function relay(handler) {
  return async (req, res, next) => {
    try {
      const client = req.app.locals.catalog;
      if (!client) throw new ApiError(503, 'CATALOG_UNAVAILABLE', 'The catalog is not set up');
      res.json(await handler(client, req));
    } catch (err) {
      if (err.retryAfter) res.set('Retry-After', err.retryAfter);
      next(err);
    }
  };
}

exports.platforms = relay(async (client) => freereels.toPlatforms(await client.get(freereels.paths.access)));

// The catalog's string id behind one of our drama numbers.
async function seriesIdFor(req, dramaId) {
  const seriesId = await catalogModel.seriesIdOf(req.app.locals.pool, Number(dramaId));
  if (!seriesId) throw new ApiError(404, 'NOT_FOUND', 'Not found in the catalog');
  return seriesId;
}

async function readDrama(client, req, dramaId) {
  const seriesId = await seriesIdFor(req, dramaId);
  const info = freereels.detailInfo(await client.get(freereels.paths.drama(seriesId)));
  if (!info) throw new ApiError(404, 'NOT_FOUND', 'Not found in the catalog');
  return { seriesId, drama: freereels.toDramaFromDetail(info, Number(dramaId)) };
}

// FreeReels has no genre filter or sort, so those are checked and ignored.
exports.dramas = relay(async (client, req) => {
  const { q, genre, sort } = req.query;
  if (q !== undefined && (typeof q !== 'string' || q.length < 1 || q.length > 100)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'q is not valid');
  }
  if (genre !== undefined && typeof genre !== 'string') {
    throw new ApiError(400, 'VALIDATION_ERROR', 'genre is not valid');
  }
  if (sort !== undefined && !SORTS.has(sort)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'sort is not valid');
  }
  if (Number(id(req.params.platformId)) !== freereels.PLATFORM_ID) {
    throw new ApiError(404, 'NOT_FOUND', 'Not found in the catalog');
  }
  const paging = {
    page: intIn(req.query.page, 'page', 1, 100000),
    page_size: intIn(req.query.page_size, 'page_size', 1, 50),
  };
  const body = q
    ? await client.get(freereels.paths.search, { keyword: q, ...paging })
    : await client.get(freereels.paths.thai, paging);
  const items = (body.items ?? []).filter((i) => i && i.series_id);
  const ids = await catalogModel.idsFor(req.app.locals.pool, items.map((i) => i.series_id));
  return freereels.toPage({ ...body, items }, ids);
});

exports.drama = relay(async (client, req) => (await readDrama(client, req, id(req.params.dramaId))).drama);

// The only upstream call that spends quota, so it needs a logged-in viewer.
// Paid episodes are checked here, before upstream is asked for any link.
exports.episodes = relay(async (client, req) => {
  const dramaId = id(req.params.dramaId);
  const range = episodeRange(req.query.ep);
  const locked = await catalogModel.lockedIn(req.app.locals.pool, req.user, Number(dramaId), range.from, range.to);
  if (locked.length > 0) {
    throw req.user
      ? new ApiError(403, 'FORBIDDEN', 'Unlock this episode to watch it')
      : new ApiError(401, 'UNAUTHENTICATED', 'Log in to watch this episode');
  }
  const seriesId = await seriesIdFor(req, dramaId);
  const episodes = [];
  for (let n = range.from; n <= range.to; n++) {
    const episode = freereels.toEpisode(await client.get(freereels.paths.play(seriesId, n)), n);
    if (!episode) throw new ApiError(502, 'CATALOG_ERROR', 'The catalog could not answer');
    episodes.push(episode);
  }
  return { episodes };
});

// Prices, plus the catalog episodes this viewer already paid for.
exports.access = async (req, res) => {
  const pool = req.app.locals.pool;
  res.json({
    ...(await catalogModel.pricing(pool)),
    unlocked: req.user ? await catalogModel.unlocksOf(pool, req.user.id) : [],
  });
};

// Pays for one catalog episode. The coins go to the admin like any unlock.
exports.unlock = relay(async (client, req) => {
  const pool = req.app.locals.pool;
  const dramaId = Number(id(req.params.dramaId));
  const episodeNo = Number(req.params.episodeNo);
  if (!/^\d{1,4}$/.test(req.params.episodeNo) || episodeNo < 1) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Episode number is not valid');
  }
  const { free_episodes: free, price_coins: price } = await catalogModel.pricing(pool);
  if (episodeNo <= free) throw new ApiError(409, 'CONFLICT', 'This episode is free');
  const balance = await wallet.getBalance(pool, req.user.id);
  if (req.user.role === 'admin') {
    return { access: 'owner', charged: 0, already_unlocked: false, balance };
  }
  // Reading the series checks it exists and has this episode.
  const { drama } = await readDrama(client, req, dramaId);
  if (episodeNo > Number(drama.episode_count)) throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
  const episodeId = await catalogModel.ensureEpisode(pool, {
    dramaId,
    title: drama.title,
    episodeNo,
    priceCoins: price,
  });
  return wallet.unlock(pool, req.user, episodeId);
});
