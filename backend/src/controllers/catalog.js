const ApiError = require('../utils/ApiError');
const catalogModel = require('../models/catalog');
const wallet = require('../models/wallet');

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

exports.platforms = relay((client) => client.get('/api/platforms'));

exports.dramas = relay((client, req) => {
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
  return client.get(`/api/platforms/${id(req.params.platformId)}/dramas`, {
    q,
    genre,
    sort,
    page: intIn(req.query.page, 'page', 1, 100000),
    page_size: intIn(req.query.page_size, 'page_size', 1, 50),
  });
});

exports.drama = relay((client, req) => client.get(`/api/dramas/${id(req.params.dramaId)}`));

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
  return client.get(`/api/dramas/${dramaId}/episodes`, { ep: range.value });
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
  // Reading the series checks it exists and has this episode; it spends no quota.
  const drama = await client.get(`/api/dramas/${dramaId}`);
  if (episodeNo > Number(drama.episode_count)) throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
  const episodeId = await catalogModel.ensureEpisode(pool, {
    dramaId,
    title: drama.title,
    episodeNo,
    priceCoins: price,
  });
  return wallet.unlock(pool, req.user, episodeId);
});
