const ApiError = require('../utils/ApiError');
const { pathId, text, int, bool, bad } = require('../utils/validate');
const { withTransaction } = require('../utils/transaction');
const films = require('../models/films');
const episodes = require('../models/episodes');
const social = require('../models/social');
const { viewerContext, accessOf, canSeeFilm } = require('../models/access');
const media = require('../services/media');

const isOwnerOrAdmin = (film, user) => user.role === 'admin' || user.id === film.creator_id;

async function withViewerFlags(pool, user, rows, serialized) {
  if (!user) return serialized;
  const flags = await social.flags(pool, user.id, rows);
  return serialized.map((film) => ({
    ...film,
    liked: flags.liked.has(film.id),
    saved: flags.saved.has(film.id),
    following_creator: flags.following.has(film.creator_id),
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
  const creatorId = req.query.creator_id === undefined ? undefined : pathId(req.query.creator_id, 'creator_id');
  const rows = await films.search(req.app.locals.pool, {
    status: 'approved',
    creatorId,
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
  const priv = Boolean(req.user && isOwnerOrAdmin(film, req.user));
  const [body] = await withViewerFlags(pool, req.user, [film], [films.serialize(film, { includePrivate: priv })]);
  res.json({
    film: body,
    episodes: rows.map((e) => episodes.serialize(e, accessOf(ctx, film, e))),
  });
};

async function lookupIds(pool, body) {
  const genreName = text(body, 'genre', { max: 30 });
  const toolName = text(body, 'ai_tool', { max: 30 });
  const [genreId, aiToolId] = await Promise.all([
    films.lookupId(pool, 'genres', genreName),
    films.lookupId(pool, 'ai_tools', toolName),
  ]);
  if (!genreId) throw bad(`genre "${genreName}" is not known`);
  if (!aiToolId) throw bad(`ai_tool "${toolName}" is not known`);
  return { genreId, aiToolId };
}

function filmFields(body) {
  return {
    title: text(body, 'title', { max: 100 }),
    synopsis: text(body, 'synopsis', { max: 500, optional: true }),
    promptCredit: text(body, 'prompt_credit', { max: 500, optional: true }),
  };
}

exports.create = async (req, res) => {
  const pool = req.app.locals.pool;
  // The AI label is mandatory: the uploader must confirm the film is AI-made.
  if (bool(req.body, 'is_ai_generated') !== true) {
    throw bad('is_ai_generated must be true: every film on ShortReel carries the AI label');
  }
  const fields = filmFields(req.body);
  const ids = await lookupIds(pool, req.body);
  const id = await films.create(pool, { creatorId: req.user.id, ...fields, ...ids });
  const film = await films.findById(pool, id);
  res.status(201).json({ film: films.serialize(film, { includePrivate: true }) });
};

// Shared by every endpoint that changes a film or its files. A film the caller
// may not even see answers 404 so pending uploads are not leaked.
exports.loadOwnedFilm = async (req, res, next) => {
  const film = await films.findById(req.app.locals.pool, pathId(req.params.id));
  if (!film || !canSeeFilm(film, req.user)) throw new ApiError(404, 'NOT_FOUND', 'Film not found');
  if (!isOwnerOrAdmin(film, req.user)) {
    throw new ApiError(403, 'FORBIDDEN', 'You can only change your own films');
  }
  if (film.status === 'taken_down' && req.user.role !== 'admin') {
    throw new ApiError(409, 'CONFLICT', 'This film was taken down; contact the admin');
  }
  req.film = film;
  next();
};

// Optional `episode_prices: [{id, price_coins}]` changes several prices together
// with the film details: everything is validated first and written in one
// transaction, so a bad value leaves the film exactly as it was.
function priceChanges(body) {
  const raw = body?.episode_prices;
  if (raw === undefined) return [];
  if (!Array.isArray(raw) || raw.length > 255) throw bad('episode_prices must be a list');
  const seen = new Set();
  return raw.map((item) => {
    const id = pathId(item?.id, 'episode_prices.id');
    if (seen.has(id)) throw bad('episode_prices lists an episode twice');
    seen.add(id);
    return { id, price: int(item, 'price_coins', { min: 0, max: 500 }) };
  });
}

exports.update = async (req, res) => {
  const pool = req.app.locals.pool;
  const fields = filmFields(req.body);
  const ids = await lookupIds(pool, req.body);
  const changes = priceChanges(req.body);
  await withTransaction(pool, async (conn) => {
    await conn.query('SELECT id FROM films WHERE id = ? FOR UPDATE', [req.film.id]);
    const own = new Map((await episodes.listByFilm(conn, req.film.id)).map((e) => [e.id, e]));
    for (const { id, price } of changes) {
      const episode = own.get(id);
      if (!episode) throw bad(`episode ${id} does not belong to this film`);
      // Coins already paid keep their unlock; the new price applies to later buyers.
      await episodes.update(conn, id, { title: episode.title, isFree: price === 0, priceCoins: price });
    }
    await films.update(conn, req.film.id, { ...fields, ...ids });
    // An owner's edit puts an approved or rejected film back in the review queue.
    if (req.user.role !== 'admin') await films.sendBackToReview(conn, req.film.id);
  });
  const film = await films.findById(pool, req.film.id);
  res.json({ film: films.serialize(film, { includePrivate: true }) });
};

exports.remove = async (req, res) => {
  const pool = req.app.locals.pool;
  const paths = await withTransaction(pool, async (conn) => {
    // Lock the film so a purchase cannot slip in between the check and the delete.
    await conn.query('SELECT id FROM films WHERE id = ? FOR UPDATE', [req.film.id]);
    await conn.query('SELECT id FROM episodes WHERE film_id = ? FOR UPDATE', [req.film.id]);
    if ((await films.purchaseCount(conn, req.film.id)) > 0) {
      throw new ApiError(409, 'CONFLICT', 'Viewers have already paid to unlock this film; take it down instead');
    }
    const videoPaths = await episodes.videoPathsOfFilm(conn, req.film.id);
    await films.remove(conn, req.film.id);
    return videoPaths;
  });
  await removeUnusedFiles(req.app, paths);
  res.status(204).end();
};

async function removeUnusedFiles(app, paths) {
  for (const videoPath of new Set(paths)) {
    if (await episodes.pathInUse(app.locals.pool, videoPath)) continue;
    const file = media.resolveInside(app.locals.uploadDir, videoPath);
    if (file) await media.discard(file);
  }
}

exports.removeUnusedFiles = removeUnusedFiles;

exports.addEpisode = async (req, res) => {
  const pool = req.app.locals.pool;
  const file = req.file;
  let id;
  try {
    if (!file) throw bad('A video file is required in the "video" field');
    const probe = await media.inspectMp4(file.path);
    if (!probe.valid) throw bad(`The file is not a playable MP4 video: ${probe.reason}`);
    const episodeNo = int(req.body, 'episode_no', { min: 1, max: 255, optional: true });
    const title = text(req.body, 'title', { max: 100, optional: true });
    const isFree = bool(req.body, 'is_free', { optional: true });
    const priceCoins = int(req.body, 'price_coins', { min: 0, max: 500, optional: true }) ?? 0;
    if (isFree === true && priceCoins > 0) throw bad('A free episode cannot also have a price');
    if (isFree === false && priceCoins === 0) throw bad('A paid episode needs price_coins of at least 1');
    const durationSec =
      int(req.body, 'duration_sec', { min: 0, max: 65535, optional: true }) ??
      Math.min(await media.mp4DurationSec(file.path), 65535);

    id = await withTransaction(pool, async (conn) => {
      await conn.query('SELECT id FROM films WHERE id = ? FOR UPDATE', [req.film.id]);
      const newId = await episodes.create(conn, {
        filmId: req.film.id,
        episodeNo: episodeNo ?? (await episodes.nextNumber(conn, req.film.id)),
        title,
        videoPath: `uploads/${file.filename}`,
        durationSec,
        isFree: priceCoins === 0,
        priceCoins,
      });
      if (req.user.role !== 'admin') await films.sendBackToReview(conn, req.film.id);
      return newId;
    });
  } catch (err) {
    // The database never got the episode, so the saved file would be orphaned.
    await media.discard(file);
    if (err.code === 'ER_DUP_ENTRY') {
      throw new ApiError(409, 'CONFLICT', 'That episode number already exists in this film');
    }
    throw err;
  }
  // The episode is committed and now references the file: from here on the file
  // is never deleted, even if building the response fails.
  const row = await episodes.findWithFilm(pool, id);
  if (!row) return res.status(201).json({ episode: { id, film_id: req.film.id, access: 'owner' } });
  res.status(201).json({ episode: episodes.serialize(row, 'owner') });
};
