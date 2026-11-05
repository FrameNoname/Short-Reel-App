const ApiError = require('../utils/ApiError');
const { pathId, bad } = require('../utils/validate');
const films = require('../models/films');
const episodes = require('../models/episodes');
const social = require('../models/social');
const { viewerContext, accessOf, canSeeFilm } = require('../models/access');

async function withViewerFlags(pool, user, rows, serialized) {
  if (!user) return serialized;
  const flags = await social.flags(pool, user.id, rows);
  return serialized.map((film) => ({
    ...film,
    liked: flags.liked.has(film.id),
    saved: flags.saved.has(film.id),
  }));
}

exports.lookups = async (req, res) => res.json(await films.lookups(req.app.locals.pool));

// The public feed and search. Only approved films, whatever the caller asks for.
exports.list = async (req, res) => {
  const { q, sort } = req.query;
  if (q !== undefined && (typeof q !== 'string' || q.length > 100)) throw bad('q is not valid');
  if (sort !== undefined && !films.SORTS.includes(sort)) throw bad('sort is not valid');
  const pageSize = req.query.page_size === undefined ? 50 : pathId(req.query.page_size, 'page_size');
  const page = req.query.page === undefined ? 1 : pathId(req.query.page, 'page');
  if (pageSize < 1 || pageSize > 100 || page < 1) throw bad('page is not valid');
  const rows = await films.search(req.app.locals.pool, {
    status: 'approved',
    q: q?.trim() || undefined,
    sort,
    limit: pageSize + 1,
    offset: (page - 1) * pageSize,
  });
  // One extra row tells the client whether another page exists.
  const hasMore = rows.length > pageSize;
  const pageRows = rows.slice(0, pageSize);
  const body = pageRows.map((row) => films.serialize(row));
  res.json({
    films: await withViewerFlags(req.app.locals.pool, req.user, pageRows, body),
    page,
    page_size: pageSize,
    has_more: hasMore,
  });
};

exports.getOne = async (req, res) => {
  const pool = req.app.locals.pool;
  const film = await films.findById(pool, pathId(req.params.id));
  if (!film || !canSeeFilm(film, req.user)) throw new ApiError(404, 'NOT_FOUND', 'Film not found');
  const ctx = await viewerContext(pool, req.user);
  const rows = await episodes.listByFilm(pool, film.id);
  const [body] = await withViewerFlags(pool, req.user, [film], [
    films.serialize(film),
  ]);
  res.json({
    film: body,
    episodes: rows.map((e) => episodes.serialize(e, accessOf(ctx, e))),
  });
};
