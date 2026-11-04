const jwt = require('jsonwebtoken');
const ApiError = require('../utils/ApiError');
const { pathId } = require('../utils/validate');
const episodes = require('../models/episodes');
const wallet = require('../models/wallet');
const { viewerContext, accessOf, canPlay, isAdmin } = require('../models/access');
const media = require('../services/media');

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

// Anything but an approved film is invisible to everyone except the admin.
function hideUnlessVisible(episode, user) {
  if (episode.film_status !== 'approved' && !isAdmin(user)) {
    throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
  }
}

exports.getOne = async (req, res) => {
  const pool = req.app.locals.pool;
  const episode = await loadEpisode(pool, pathId(req.params.id));
  hideUnlessVisible(episode, req.user);
  const ctx = await viewerContext(pool, req.user);
  const access = accessOf(ctx, episode);
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
  const access = accessOf(ctx, episode);
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

exports.unlock = async (req, res) => {
  const result = await wallet.unlock(req.app.locals.pool, req.user, pathId(req.params.id));
  res.json(result);
};
