const ApiError = require('../utils/ApiError');
const { pathId, text } = require('../utils/validate');
const films = require('../models/films');
const social = require('../models/social');
const { canSeeFilm } = require('../models/access');

async function visibleFilm(req) {
  const film = await films.findById(req.app.locals.pool, pathId(req.params.id));
  if (!film || !canSeeFilm(film, req.user)) throw new ApiError(404, 'NOT_FOUND', 'Film not found');
  return film;
}

exports.like = async (req, res) => {
  const film = await visibleFilm(req);
  res.json({ liked: true, like_count: await social.setLike(req.app.locals.pool, req.user.id, film.id, true) });
};

exports.unlike = async (req, res) => {
  const film = await visibleFilm(req);
  res.json({ liked: false, like_count: await social.setLike(req.app.locals.pool, req.user.id, film.id, false) });
};

exports.listWatchlist = async (req, res) => {
  res.json({ film_ids: await social.listWatchlist(req.app.locals.pool, req.user.id) });
};

exports.addToWatchlist = async (req, res) => {
  const film = await visibleFilm(req);
  await social.setWatchlist(req.app.locals.pool, req.user.id, film.id, true);
  res.json({ saved: true });
};

exports.removeFromWatchlist = async (req, res) => {
  await social.setWatchlist(req.app.locals.pool, req.user.id, pathId(req.params.id), false);
  res.json({ saved: false });
};

exports.listComments = async (req, res) => {
  const film = await visibleFilm(req);
  res.json({ comments: await social.listComments(req.app.locals.pool, film.id) });
};

exports.addComment = async (req, res) => {
  const film = await visibleFilm(req);
  const body = text(req.body, 'body', { max: 500 });
  const id = await social.addComment(req.app.locals.pool, req.user.id, film.id, body);
  res.status(201).json({ id });
};

exports.removeComment = async (req, res) => {
  await social.removeComment(req.app.locals.pool, req.user, pathId(req.params.id));
  res.status(204).end();
};
