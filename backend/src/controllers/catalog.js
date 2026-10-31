const ApiError = require('../utils/ApiError');

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
  return value;
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
exports.episodes = relay((client, req) =>
  client.get(`/api/dramas/${id(req.params.dramaId)}/episodes`, { ep: episodeRange(req.query.ep) }),
);
