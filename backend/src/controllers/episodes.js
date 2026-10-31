const jwt = require('jsonwebtoken');
const ApiError = require('../utils/ApiError');
const { pathId, text, int, bool, bad } = require('../utils/validate');
const { withTransaction } = require('../utils/transaction');
const episodes = require('../models/episodes');
const films = require('../models/films');
const wallet = require('../models/wallet');
const { viewerContext, accessOf, canPlay } = require('../models/access');
const media = require('../services/media');
const { removeUnusedFiles } = require('./films');

const STREAM_TOKEN_TTL = '10m';

// A <video> element on the web cannot send an Authorization header, so the
// player gets a short link that carries who is asking. It only says who; the
// access rules are checked again on every request to /stream.
function streamUrl(req, episodeId, user) {
  const token = jwt.sign(
    { typ: 'stream', eid: episodeId, uid: user ? user.id : null },
    req.app.locals.jwtSecret,
    { expiresIn: STREAM_TOKEN_TTL, algorithm: 'HS256' },
  );
  return `/api/episodes/${episodeId}/stream?t=${encodeURIComponent(token)}`;
}

async function loadEpisode(pool, id) {
  const episode = await episodes.findWithFilm(pool, id);
  if (!episode) throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
  return episode;
}

// Anything but an approved film is invisible to everyone except its owner and the admin.
function hideUnlessVisible(episode, user) {
  const owner = user && (user.role === 'admin' || user.id === episode.creator_id);
  if (episode.film_status !== 'approved' && !owner) {
    throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
  }
}

exports.getOne = async (req, res) => {
  const pool = req.app.locals.pool;
  const episode = await loadEpisode(pool, pathId(req.params.id));
  hideUnlessVisible(episode, req.user);
  const ctx = await viewerContext(pool, req.user);
  const access = accessOf(ctx, { creator_id: episode.creator_id }, episode);
  res.json({
    episode: episodes.serialize(episode, access),
    film: { id: episode.film_id, title: episode.film_title },
    // Only handed out when the caller may actually watch.
    stream_url: canPlay(access) ? streamUrl(req, episode.id, req.user) : null,
  });
};

exports.stream = async (req, res) => {
  const pool = req.app.locals.pool;
  const id = pathId(req.params.id);
  let user = req.user;
  if (req.query.t !== undefined) {
    let payload;
    try {
      payload = jwt.verify(String(req.query.t), req.app.locals.jwtSecret, { algorithms: ['HS256'] });
    } catch {
      throw new ApiError(401, 'UNAUTHENTICATED', 'The playback link is invalid or expired');
    }
    if (payload.typ !== 'stream' || payload.eid !== id) {
      throw new ApiError(401, 'UNAUTHENTICATED', 'The playback link is invalid or expired');
    }
    if (payload.uid !== null) {
      const [rows] = await pool.query('SELECT id, role FROM users WHERE id = ?', [payload.uid]);
      user = rows[0];
    }
  }
  const episode = await loadEpisode(pool, id);
  hideUnlessVisible(episode, user);
  const ctx = await viewerContext(pool, user);
  const access = accessOf(ctx, { creator_id: episode.creator_id }, episode);
  if (!canPlay(access)) {
    throw user
      ? new ApiError(403, 'FORBIDDEN', 'Unlock this episode to watch it')
      : new ApiError(401, 'UNAUTHENTICATED', 'Log in to watch this episode');
  }
  const file = media.resolveInside(req.app.locals.uploadDir, episode.video_path);
  if (!file) throw new ApiError(404, 'NOT_FOUND', 'Video file not found');
  res.set('Cache-Control', 'private, no-store');
  res.sendFile(file, { headers: { 'Content-Type': 'video/mp4' }, acceptRanges: true }, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Video file not found' } });
    }
  });
};

async function loadOwnedEpisode(req) {
  const episode = await loadEpisode(req.app.locals.pool, pathId(req.params.id));
  hideUnlessVisible(episode, req.user);
  if (req.user.role !== 'admin' && req.user.id !== episode.creator_id) {
    throw new ApiError(403, 'FORBIDDEN', 'You can only change your own films');
  }
  if (episode.film_status === 'taken_down' && req.user.role !== 'admin') {
    throw new ApiError(409, 'CONFLICT', 'This film was taken down; contact the admin');
  }
  return episode;
}

exports.update = async (req, res) => {
  const pool = req.app.locals.pool;
  const episode = await loadOwnedEpisode(req);
  const title = text(req.body, 'title', { max: 100, optional: true }) ?? episode.title;
  const isFree = bool(req.body, 'is_free', { optional: true });
  const priceCoins = int(req.body, 'price_coins', { min: 0, max: 500, optional: true });
  let price = priceCoins ?? episode.price_coins;
  if (isFree === true) {
    if (priceCoins > 0) throw bad('A free episode cannot also have a price');
    price = 0;
  } else if (isFree === false && price === 0) {
    throw bad('A paid episode needs price_coins of at least 1');
  }
  // Coins already paid keep their unlock; the new price applies to later buyers.
  await episodes.update(pool, episode.id, { title, isFree: price === 0, priceCoins: price });
  const row = await episodes.findWithFilm(pool, episode.id);
  res.json({ episode: episodes.serialize(row, 'owner') });
};

exports.remove = async (req, res) => {
  const pool = req.app.locals.pool;
  const episode = await loadOwnedEpisode(req);
  await withTransaction(pool, async (conn) => {
    await conn.query('SELECT id FROM films WHERE id = ? FOR UPDATE', [episode.film_id]);
    if ((await episodes.unlockCount(conn, episode.id)) > 0) {
      throw new ApiError(409, 'CONFLICT', 'Viewers have already paid for this episode');
    }
    await episodes.remove(conn, episode.id);
    // A live film with no episodes left goes back to review.
    const [[left]] = await conn.query('SELECT COUNT(*) AS n FROM episodes WHERE film_id = ?', [episode.film_id]);
    if (left.n === 0) await films.sendBackToReview(conn, episode.film_id);
  });
  await removeUnusedFiles(req.app, [episode.video_path]);
  res.status(204).end();
};

exports.unlock = async (req, res) => {
  const result = await wallet.unlock(req.app.locals.pool, req.user, pathId(req.params.id));
  res.json(result);
};
